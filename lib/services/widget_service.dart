import 'dart:convert';
import 'dart:io' show Platform, File;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tyme/tyme.dart';
import 'package:home_widget/home_widget.dart';
import '../widgets/home_screen_widget_ui.dart';
import '../widgets/home_screen_widget_ui_4x2.dart';
import '../models/su_kien.dart';
import '../utils/am_lich_helper.dart';

class WidgetService {
  static const String appGroupId = 'group.com.toanbb.vie_Lich';
  static const String macOSWidgetName = 'VIELichWidget';
  static const platform = MethodChannel('vie_lich_mac_widget');
  static const String androidWidgetProvider =
      'com.toanbb.vie_lich.HomeScreenWidgetProvider';

  static const List<String> _thuNames = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];

  static const int _macOSMultiDayCount = 7;

  static Future<void> capNhatWidget() async {
    final now = DateTime.now();

    List<SuKien> danhSachSuKien = [];
    try {
      var box = Hive.isBoxOpen('suKienBox')
          ? Hive.box<SuKien>('suKienBox')
          : await Hive.openBox<SuKien>('suKienBox');
      danhSachSuKien = box.values.toList();
    } catch (e) {
      debugPrint("❌ Lỗi đọc sự kiện Hive cho Widget: $e");
    }

    final todayData = _tinhDuLieuMotNgay(now, danhSachSuKien);

    String nextEventText = todayData['thoiGianSuKien'].isEmpty
        ? todayData['tenSuKien']
        : "${todayData['tenSuKien']}\n(${todayData['thoiGianSuKien']})";

    if (Platform.isAndroid) {
      // ==========================================
      // WIDGET 1: 4x3 (CŨ)
      // ==========================================
      try {
        debugPrint('🔄 [Widget 4x3] Bắt đầu render...');
        final success43 = await HomeWidget.renderFlutterWidget(
          MediaQuery(
            data: const MediaQueryData(
                size: Size(500, 375), devicePixelRatio: 1.0),
            child: HomeScreenWidgetUI(
              thangDuyet: now.month,
              namDuyet: now.year,
              tenSuKien: todayData['tenSuKien'],
              thoiGianSuKien: todayData['thoiGianSuKien'],
              loaiSuKien: todayData['loaiSuKien'],
              ngayCoSuKien: (todayData['ngayCoSuKien'] as List).cast<int>(),
            ),
          ),
          key: 'widget_image',
          logicalSize: const Size(500, 375),
        );
        debugPrint('✅ [Widget 4x3] Render kết quả: $success43');

        await HomeWidget.updateWidget(
          name: 'HomeScreenWidgetProvider',
          qualifiedAndroidName: androidWidgetProvider,
        );
        debugPrint('✅ [Widget 4x3] Đã gửi lệnh cập nhật');
      } catch (e, st) {
        debugPrint('❌ [Widget 4x3] LỖI: $e\n$st');
      }

      await Future.delayed(const Duration(milliseconds: 200));

      // ==========================================
      // WIDGET 2: 4x2 (MỚI - VẠN NIÊN)
      // ==========================================
      try {
        debugPrint('🔄 [Widget 4x2] Bắt đầu render...');
        final success42 = await HomeWidget.renderFlutterWidget(
          MediaQuery(
            data: const MediaQueryData(
                size: Size(800, 360), devicePixelRatio: 1.0),
            child: HomeScreenWidgetUI4x2(
              thangDuyet: now.month,
              namDuyet: now.year,
              tenSuKien: todayData['tenSuKien'],
              thoiGianSuKien: todayData['thoiGianSuKien'],
              loaiSuKien: todayData['loaiSuKien'],
              ngayCoSuKien: (todayData['ngayCoSuKien'] as List).cast<int>(),
            ),
          ),
          key: 'widget_image_4x2',
          logicalSize: const Size(800, 360),
        );
        debugPrint('✅ [Widget 4x2] Render kết quả: $success42');

        final appDir = await getApplicationSupportDirectory();
        final imageFile4x2 =
            File('${appDir.path}/home_widget/widget_image_4x2.png');
        if (await imageFile4x2.exists()) {
          debugPrint(
              '✅ [Widget 4x2] File ảnh: ${await imageFile4x2.length()} bytes');
        } else {
          debugPrint('❌ [Widget 4x2] File ảnh KHÔNG ĐƯỢC TẠO!');
        }

        await HomeWidget.updateWidget(
          name: 'HomeScreenWidgetProvider4x2',
          qualifiedAndroidName:
              'com.toanbb.vie_lich.HomeScreenWidgetProvider4x2',
        );
        debugPrint('✅ [Widget 4x2] Đã gửi lệnh cập nhật');
      } catch (e, st) {
        debugPrint('❌ [Widget 4x2] LỖI: $e\n$st');
      }
    } else if (Platform.isIOS) {
      try {
        await HomeWidget.setAppGroupId(appGroupId);
        await HomeWidget.saveWidgetData<String>('next_event', nextEventText);
        await HomeWidget.updateWidget(iOSName: macOSWidgetName);
      } catch (e) {
        debugPrint('❌ [Widget iOS] Lỗi cập nhật widget: $e');
      }
    } else if (Platform.isMacOS) {
      try {
        final List<String> dayJsonList = [];
        for (int i = 0; i < _macOSMultiDayCount; i++) {
          final targetDay = now.add(Duration(days: i));
          final dayJson = _buildDayJson(targetDay, danhSachSuKien);
          dayJsonList.add(dayJson);
        }
        await platform.invokeMethod('updateWidget', {
          'data': dayJsonList,
          'groupId': appGroupId,
          'isMulti': true,
        });
        debugPrint('✅ Gửi $_macOSMultiDayCount ngày cho widget macOS');
      } catch (e) {
        debugPrint("❌ Lỗi gửi dữ liệu Widget macOS: $e");
      }
    }
  }

  static Map<String, dynamic> _tinhDuLieuMotNgay(
    DateTime targetDay,
    List<SuKien> danhSachSuKien,
  ) {
    final now = targetDay;
    final todayOnly = DateTime(now.year, now.month, now.day);

    List<int> ngayCoSuKienHienTai = [];
    String tenSuKienGanNhat = "Không có sự kiện sắp tới";
    String thoiGianSuKienGanNhat = "";
    String loaiSuKienGanNhat = "event";

    LunarDay? amHienTai = AmLichHelper.duongSangAm(now);
    int namAmHienTai = amHienTai != null ? amHienTai.getYear() : now.year;

    List<Map<String, dynamic>> dsDaChuyenDoi = [];
    for (var sk in danhSachSuKien) {
      int namAmTinhToan = sk.namAm ?? namAmHienTai;
      DateTime? ngayDuong =
          AmLichHelper.amSangDuong(namAmTinhToan, sk.thangAm, sk.ngayAm);

      if (sk.namAm == null && ngayDuong != null) {
        DateTime dateOnly =
            DateTime(ngayDuong.year, ngayDuong.month, ngayDuong.day);
        if (dateOnly.isBefore(todayOnly)) {
          ngayDuong =
              AmLichHelper.amSangDuong(namAmHienTai + 1, sk.thangAm, sk.ngayAm);
        }
      }

      if (ngayDuong != null) {
        dsDaChuyenDoi.add(
            {'ten': sk.ten, 'ngayDuong': ngayDuong, 'tag': sk.tag ?? 'event'});
        if (ngayDuong.month == now.month && ngayDuong.year == now.year) {
          ngayCoSuKienHienTai.add(ngayDuong.day);
        }
      }
    }

    List<Map<String, dynamic>> suKienSapToi = dsDaChuyenDoi.where((sk) {
      DateTime dateOnly = DateTime(
          sk['ngayDuong'].year, sk['ngayDuong'].month, sk['ngayDuong'].day);
      return dateOnly.isAfter(todayOnly) ||
          dateOnly.isAtSameMomentAs(todayOnly);
    }).toList();

    if (suKienSapToi.isNotEmpty) {
      suKienSapToi.sort((a, b) =>
          (a['ngayDuong'] as DateTime).compareTo(b['ngayDuong'] as DateTime));
      var skGanNhat = suKienSapToi.first;
      DateTime dateSK = skGanNhat['ngayDuong'];

      tenSuKienGanNhat = skGanNhat['ten'];
      loaiSuKienGanNhat = skGanNhat['tag'];

      int soNgayConLai = DateTime(dateSK.year, dateSK.month, dateSK.day)
          .difference(todayOnly)
          .inDays;

      if (soNgayConLai == 0) {
        thoiGianSuKienGanNhat = 'Hôm nay';
      } else if (soNgayConLai == 1) {
        thoiGianSuKienGanNhat = 'Ngày mai';
      } else {
        thoiGianSuKienGanNhat = 'Còn $soNgayConLai ngày';
      }
    }

    return {
      'tenSuKien': tenSuKienGanNhat,
      'thoiGianSuKien': thoiGianSuKienGanNhat,
      'loaiSuKien': loaiSuKienGanNhat,
      'ngayCoSuKien': ngayCoSuKienHienTai,
    };
  }

  static String _buildDayJson(DateTime targetDay, List<SuKien> danhSachSuKien) {
    final dayInfo = _tinhDuLieuMotNgay(targetDay, danhSachSuKien);
    final ngayCoSuKien = (dayInfo['ngayCoSuKien'] as List).cast<int>();
    final amHienTai = AmLichHelper.duongSangAm(targetDay);

    final ngayDauThang = DateTime(targetDay.year, targetDay.month, 1);
    final offset = ngayDauThang.weekday - 1;
    final ngayBatDau = ngayDauThang.subtract(Duration(days: offset));
    final soNgayTrongThang =
        DateTime(targetDay.year, targetDay.month + 1, 0).day;
    final tongO = offset + soNgayTrongThang;
    final soTuan = (tongO / 7).ceil();

    final List<Map<String, dynamic>> dsO = [];
    for (int i = 0; i < soTuan * 7; i++) {
      final ngay = ngayBatDau.add(Duration(days: i));
      final lunar = AmLichHelper.duongSangAm(ngay);
      final laTrongThang =
          ngay.month == targetDay.month && ngay.year == targetDay.year;

      dsO.add({
        'ngayDuong': ngay.day,
        'ngayAm': lunar?.getDay() ?? 0,
        'thangAm': lunar?.getMonth() ?? 0,
        'laChuNhat': ngay.weekday == 7,
        'laHomNay': ngay.year == targetDay.year &&
            ngay.month == targetDay.month &&
            ngay.day == targetDay.day,
        'coSuKien': laTrongThang && ngayCoSuKien.contains(ngay.day),
        'laDauThangAm': lunar?.getDay() == 1,
        'laTrongThang': laTrongThang,
      });
    }

    return jsonEncode({
      'thangDuong': targetDay.month,
      'namDuong': targetDay.year,
      'ngayDuong': targetDay.day,
      'thu': _thuNames[targetDay.weekday - 1],
      'ngayAm': amHienTai?.getDay() ?? 0,
      'thangAm': amHienTai?.getMonth() ?? 0,
      'namAm': amHienTai?.getYear() ?? targetDay.year,
      'canChiNam':
          amHienTai != null ? AmLichHelper.layCanChiNam(amHienTai) : '',
      'dsO': dsO,
      'tenSuKien': dayInfo['tenSuKien'],
      'thoiGianSuKien': dayInfo['thoiGianSuKien'],
      'loaiSuKien': dayInfo['loaiSuKien'],
    });
  }
}
