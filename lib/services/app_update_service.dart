import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

class AppUpdateService {
  /// Kiểm tra xem có bản cập nhật không.
  /// Trả về null nếu không có update hoặc không phải Android.
  static Future<AppUpdateInfo?> checkForUpdate() async {
    if (!Platform.isAndroid) return null;

    try {
      final info = await InAppUpdate.checkForUpdate();
      debugPrint('📦 [Update] Trạng thái: ${info.updateAvailability}');
      debugPrint('📦 [Update] Flexible allowed: ${info.flexibleUpdateAllowed}');
      debugPrint(
          '📦 [Update] Immediate allowed: ${info.immediateUpdateAllowed}');
      return info;
    } catch (e) {
      debugPrint('❌ [Update] Lỗi kiểm tra: $e');
      return null;
    }
  }

  /// Bắt đầu flexible update (tải ngầm).
  /// Trả về true nếu bắt đầu thành công.
  static Future<bool> startFlexibleUpdate() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await InAppUpdate.startFlexibleUpdate();
      debugPrint('✅ [Update] Flexible bắt đầu: $result');
      return true;
    } catch (e) {
      debugPrint('❌ [Update] Lỗi flexible: $e');
      return false;
    }
  }

  /// Hoàn tất flexible update (cài đặt và khởi động lại app).
  static Future<bool> completeFlexibleUpdate() async {
    if (!Platform.isAndroid) return false;

    try {
      await InAppUpdate.completeFlexibleUpdate();
      debugPrint('✅ [Update] Đã hoàn tất, app sẽ khởi động lại');
      return true;
    } catch (e) {
      debugPrint('❌ [Update] Lỗi complete: $e');
      return false;
    }
  }

  /// Bắt đầu immediate update (chặn app, buộc cập nhật).
  static Future<bool> startImmediateUpdate() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await InAppUpdate.performImmediateUpdate();
      debugPrint('✅ [Update] Immediate kết quả: $result');
      return true;
    } catch (e) {
      debugPrint('❌ [Update] Lỗi immediate: $e');
      return false;
    }
  }

  /// Kiểm tra và tự động chạy update flow phù hợp.
  /// [uuTienImmediate]: nếu true, ưu tiên immediate khi được phép.
  static Future<void> autoUpdateFlow({
    bool uuTienImmediate = false,
  }) async {
    final info = await checkForUpdate();
    if (info == null) return;

    // Nếu chưa có update → không làm gì
    if (info.updateAvailability != UpdateAvailability.updateAvailable) {
      debugPrint('ℹ️ [Update] Không có bản cập nhật');
      return;
    }

    // Ưu tiên immediate nếu được phép và user muốn
    if (uuTienImmediate && info.immediateUpdateAllowed) {
      await startImmediateUpdate();
      return;
    }

    // Fallback sang flexible
    if (info.flexibleUpdateAllowed) {
      await startFlexibleUpdate();
    } else if (info.immediateUpdateAllowed) {
      await startImmediateUpdate();
    }
  }
}
