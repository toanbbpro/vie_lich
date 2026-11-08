import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:vie_lich/main.dart';
import 'package:vie_lich/widgets/home_screen_widget_windows.dart';

/// Mô phỏng đúng hành vi của plugin `screen_retriever_windows`:
/// C++ chia `rcWork` và `rcMonitor` cho `scaleFactor` trước khi trả về Dart.
Display createMockWindowsDisplay({
  required String id,
  required Rect physicalWorkArea,
  required double scaleFactor,
  Size? physicalFullSize,
}) {
  final fullW = physicalFullSize?.width ?? physicalWorkArea.width;
  final fullH = physicalFullSize?.height ?? physicalWorkArea.height;
  return Display(
    id: id,
    name: id,
    size: Size(
      (fullW / scaleFactor).roundToDouble(),
      (fullH / scaleFactor).roundToDouble(),
    ),
    visiblePosition: Offset(
      (physicalWorkArea.left / scaleFactor).roundToDouble(),
      (physicalWorkArea.top / scaleFactor).roundToDouble(),
    ),
    visibleSize: Size(
      (physicalWorkArea.width / scaleFactor).roundToDouble(),
      (physicalWorkArea.height / scaleFactor).roundToDouble(),
    ),
    scaleFactor: scaleFactor,
  );
}

/// Mô phỏng đúng cách C++ `WindowManager::SetBounds` tính tọa độ pixel truyền vào `SetWindowPos`:
/// `int x = static_cast<int>(*null_or_x * devicePixelRatio);` (truncate về 0).
int simulateCppSetBoundsCast(double dartValue, double currentWindowDpr) {
  return (dartValue * currentWindowDpr).truncate();
}

void main() {
  group('WindowsWidgetGeometry - Đa màn hình khác độ phân giải & DPI (1080p + 4K)', () {
    test('Khôi phục đúng physical workArea từ dữ liệu đã chia scale của screen_retriever_windows', () {
      final display1080p = createMockWindowsDisplay(
        id: 'display_1080p',
        physicalWorkArea: const Rect.fromLTWH(0, 0, 1920, 1040),
        scaleFactor: 1.25,
      );
      final display4k = createMockWindowsDisplay(
        id: 'display_4k',
        physicalWorkArea: const Rect.fromLTWH(1920, 0, 3840, 2064),
        scaleFactor: 2.0,
      );

      expect(
        WindowsWidgetGeometry.getDisplayPhysicalWorkArea(display1080p),
        const Rect.fromLTWH(0, 0, 1920, 1040),
      );
      expect(
        WindowsWidgetGeometry.getDisplayPhysicalWorkArea(display4k),
        const Rect.fromLTWH(1920, 0, 3840, 2064),
      );
    });

    test('Kéo widget lên góc trên-phải màn 4K (bên phải màn 1080p) và khởi động lại giữ nguyên vị trí', () {
      // Màn 1 (Primary): 1920x1080 @ 100% (scale 1.0)
      final display1080p = createMockWindowsDisplay(
        id: '1080p',
        physicalWorkArea: const Rect.fromLTWH(0, 0, 1920, 1040),
        scaleFactor: 1.0,
      );
      // Màn 2: 3840x2160 (4K) @ 200% (scale 2.0), đặt bên phải màn 1080p (x: 1920..5760)
      final display4k = createMockWindowsDisplay(
        id: '4k',
        physicalWorkArea: const Rect.fromLTWH(1920, 0, 3840, 2064),
        scaleFactor: 2.0,
      );
      final displays = [display1080p, display4k];

      // Kích thước widget trên màn 4K (scale 2.0) là 840x380 physical px.
      // Người dùng kéo widget sát góc trên-phải của màn 4K (x ≈ 4910, y ≈ 15):
      final dragResult = WindowsWidgetGeometry.computeSnapPhysical(
        currentPhysPos: const Offset(4910, 15),
        currentPhysSize: const Size(840, 380),
        logicalWidgetSize: kWidgetSize,
        displays: displays,
        primaryDisplay: display1080p,
      );

      // Phải snap về góc trên-phải của màn 4K:
      // right = 1920 + 3840 = 5760 -> newX = 5760 - 840 - (20 * 2.0) = 4880
      // top = 0 -> newY = 0 + (20 * 2.0) = 40
      expect(dragResult.snapped, isTrue);
      expect(dragResult.physPos, const Offset(4880, 40));
      expect(dragResult.physSize, const Size(840, 380));

      // Lần khởi động tiếp theo: cửa sổ ban đầu được tạo ở (10, 10) trên màn 1080p (DPR = 1.0)
      // nhưng vị trí đã lưu là (4880, 40) trên màn 4K:
      final restoredRect = WindowsWidgetGeometry.resolveInitialPhysicalRect(
        savedPhysPos: dragResult.physPos,
        logicalWidgetSize: kWidgetSize,
        displays: displays,
        primaryDisplay: display1080p,
      );

      // Không được bị nhảy ra giữa màn 4K (x ≈ 2440 hoặc 1920), phải giữ đúng (4880, 40) và size (840, 380)
      expect(restoredRect, const Rect.fromLTWH(4880, 40, 840, 380));

      // Kiểm tra khi gọi qua windowManager lúc cửa sổ còn ở màn 1080p (DPR=1.0) hay đã sang màn 4K (DPR=2.0)
      for (final dpr in [1.0, 1.25, 1.5, 1.75, 2.0]) {
        final wmOffset = WindowsWidgetGeometry.physicalToWindowManagerOffset(
          restoredRect.topLeft,
          dpr,
        );
        expect(simulateCppSetBoundsCast(wmOffset.dx, dpr), 4880);
        expect(simulateCppSetBoundsCast(wmOffset.dy, dpr), 40);
      }
    });

    test('Màn 4K đặt bên trái màn 1080p (tọa độ âm) vẫn snap và nhớ đúng góc trên-phải màn 4K', () {
      final display1080p = createMockWindowsDisplay(
        id: '1080p',
        physicalWorkArea: const Rect.fromLTWH(0, 0, 1920, 1040),
        scaleFactor: 1.25,
      );
      // Màn 4K đặt bên trái màn 1080p: x từ -3840 đến 0, scale 150% (1.5)
      final display4kLeft = createMockWindowsDisplay(
        id: '4k_left',
        physicalWorkArea: const Rect.fromLTWH(-3840, 0, 3840, 2100),
        scaleFactor: 1.5,
      );
      final displays = [display1080p, display4kLeft];

      // Ở scale 1.5, kích thước physical của widget là 630 x 285, margin là 30
      // Kéo tới sát góc trên-phải màn 4K (sát mép x = 0):
      final snap = WindowsWidgetGeometry.computeSnapPhysical(
        currentPhysPos: const Offset(-650, 10),
        currentPhysSize: const Size(630, 285),
        logicalWidgetSize: kWidgetSize,
        displays: displays,
        primaryDisplay: display1080p,
      );

      // newX = 0 - 630 - 30 = -660, newY = 0 + 30 = 30
      expect(snap.snapped, isTrue);
      expect(snap.physPos, const Offset(-660, 30));

      final restored = WindowsWidgetGeometry.resolveInitialPhysicalRect(
        savedPhysPos: snap.physPos,
        logicalWidgetSize: kWidgetSize,
        displays: displays,
        primaryDisplay: display1080p,
      );
      expect(restored, const Rect.fromLTWH(-660, 30, 630, 285));

      // Kiểm tra tọa độ âm qua C++ truncate
      for (final dpr in [1.0, 1.25, 1.5, 2.0]) {
        final wmOffset = WindowsWidgetGeometry.physicalToWindowManagerOffset(
          restored.topLeft,
          dpr,
        );
        expect(simulateCppSetBoundsCast(wmOffset.dx, dpr), -660);
        expect(simulateCppSetBoundsCast(wmOffset.dy, dpr), 30);
      }
    });

    test('Khi rút màn hình phụ 4K ra, widget tự động kẹp về vùng hiển thị của màn 1080p còn lại', () {
      final display1080p = createMockWindowsDisplay(
        id: '1080p',
        physicalWorkArea: const Rect.fromLTWH(0, 0, 1920, 1040),
        scaleFactor: 1.0,
      );
      // Chỉ còn 1 màn 1080p nhưng tọa độ cũ lưu ở màn 4K (4880, 40)
      final restored = WindowsWidgetGeometry.resolveInitialPhysicalRect(
        savedPhysPos: const Offset(4880, 40),
        logicalWidgetSize: kWidgetSize,
        displays: [display1080p],
        primaryDisplay: display1080p,
      );

      // Phải được kéo về nằm gọn trong màn 1080p (maxX = 1920 - 420 = 1500)
      expect(restored.left, 1500);
      expect(restored.top, 40);
      expect(restored.width, 420);
      expect(restored.height, 190);
    });
  });

  group('HomeScreenWidgetWindows UI', () {
    testWidgets('Render đúng kích thước 420x190 không bị tràn (overflow) ở tháng 6 tuần', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              height: 190,
              child: HomeScreenWidgetWindows(
                thangDuyet: 8, // Tháng 8/2026 trải dài 6 hàng tuần
                namDuyet: 2026,
                tenSuKien: 'Giỗ Tổ Hùng Vương',
                thoiGianSuKien: 'Còn 3 ngày - 26/04/2026',
                loaiSuKien: 'holiday',
                ngayCoSuKien: [1, 15, 30],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Tháng 08/2026'), findsOneWidget);
      expect(find.text('Giỗ Tổ Hùng Vương'), findsOneWidget);
    });
  });
}
