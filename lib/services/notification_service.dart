import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/su_kien.dart';
import '../utils/lunar_vn.dart';
import 'sound_settings.dart';

// ============================================================
// HẰNG SỐ TOP-LEVEL
// ============================================================
const String _channelDesc = 'Thông báo nhắc trước ngày giỗ, lễ theo âm lịch';

// ============================================================
// CALLBACK CHẠY TRONG ISOLATE
// ============================================================
@pragma('vm:entry-point')
Future<void> _showScheduledNotification(
  int id,
  Map<String, dynamic> params,
) async {
  final plugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    ),
  );

  final channelId = params['channelId'] as String;
  final channelName = params['channelName'] as String;
  final soundUriStr = params['soundUri'] as String?;

  await plugin.show(
    id: id,
    title: params['title'] as String?,
    body: params['body'] as String?,
    notificationDetails: _buildNotificationDetails(
      channelId: channelId,
      channelName: channelName,
      soundUri: soundUriStr != null ? Uri.parse(soundUriStr) : null,
    ),
    payload: params['payload'] as String?,
  );
}

// ============================================================
// HELPER BUILD NOTIFICATION DETAILS
// ============================================================
NotificationDetails _buildNotificationDetails({
  required String channelId,
  required String channelName,
  Uri? soundUri,
}) {
  final androidDetails = AndroidNotificationDetails(
    channelId,
    channelName,
    channelDescription: _channelDesc,
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    category: AndroidNotificationCategory.reminder,
    visibility: NotificationVisibility.public,
    styleInformation: const BigTextStyleInformation(''),
    ticker: 'Nhắc nhở sự kiện',
    sound: soundUri != null
        ? UriAndroidNotificationSound(soundUri.toString())
        : null,
  );
  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );
  return NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );
}

// ============================================================
// CLASS CHÍNH
// ============================================================
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _gioNhac = 13;
  static const int _phutNhac = 45;

  static const int _gioNhacLai = 19;
  static const int _phutNhacLai = 0;

  /// ===== KHỞI TẠO =====
  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Đã nhấn thông báo: ${response.payload}');
      },
    );

    // Xóa kênh cũ để đảm bảo cài đặt mới được áp dụng
    await _xoaTatCaKenhCu();
    await _taoTatCaKenh();
    await _xinQuyen();
  }

  /// Xóa cả 2 kênh cũ để luôn tạo mới với cài đặt đúng
  static Future<void> _xoaTatCaKenhCu() async {
    if (!Platform.isAndroid) return;
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.deleteNotificationChannel(
          channelId: SoundSettings.channelIdSystem);
      await androidImpl?.deleteNotificationChannel(
          channelId: SoundSettings.channelIdCustom);
      debugPrint('🗑️ Đã xóa kênh cũ (nếu có)');
    } catch (e) {
      debugPrint('Lỗi xóa kênh cũ: $e');
    }
  }

  /// Tạo 2 kênh: một cho âm hệ thống, một cho âm tùy chỉnh
  static Future<void> _taoTatCaKenh() async {
    if (!Platform.isAndroid) return;

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return;

    // Kênh âm hệ thống
    const channelSystem = AndroidNotificationChannel(
      SoundSettings.channelIdSystem,
      SoundSettings.channelNameSystem,
      description: _channelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      showBadge: true,
    );
    await androidImpl.createNotificationChannel(channelSystem);

    // Kênh âm tùy chỉnh (URI sẽ được gắn khi user chọn file, tạm thời null)
    final packageInfo = await PackageInfo.fromPlatform();
    final customUri =
        await SoundSettings.getCustomSoundUri(packageInfo.packageName);

    final channelCustom = AndroidNotificationChannel(
      SoundSettings.channelIdCustom,
      SoundSettings.channelNameCustom,
      description: _channelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      showBadge: true,
      sound: customUri != null
          ? UriAndroidNotificationSound(customUri.toString())
          : null,
    );
    await androidImpl.createNotificationChannel(channelCustom);

    debugPrint('✅ Đã tạo 2 kênh: system + custom');
  }

  /// Xóa và tạo lại kênh custom với âm thanh mới
  static Future<void> recreateCustomChannel() async {
    if (!Platform.isAndroid) return;
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return;

    await androidImpl.deleteNotificationChannel(
        channelId: SoundSettings.channelIdCustom);

    final packageInfo = await PackageInfo.fromPlatform();
    final customUri =
        await SoundSettings.getCustomSoundUri(packageInfo.packageName);

    final channelCustom = AndroidNotificationChannel(
      SoundSettings.channelIdCustom,
      SoundSettings.channelNameCustom,
      description: _channelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      showBadge: true,
      sound: customUri != null
          ? UriAndroidNotificationSound(customUri.toString())
          : null,
    );
    await androidImpl.createNotificationChannel(channelCustom);
    debugPrint('✅ Đã tạo lại kênh custom');
  }

  static Future<void> _xinQuyen() async {
    if (!Platform.isAndroid) return;
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    // Chỉ xin quyền notification. Với alarmClock: true, không cần
    // SCHEDULE_EXACT_ALARM nữa.
    await androidImpl?.requestNotificationsPermission();
  }

  /// ===== TẠO ID THÔNG BÁO =====
  static int _idChinh(String suKienId) => suKienId.hashCode & 0x7FFFFFFF;
  static int _idNhacLai(String suKienId) =>
      (_idChinh(suKienId) + 1000000) & 0x7FFFFFFF;

  /// ===== LÊN LỊCH CHO 1 SỰ KIỆN =====
  static Future<void> lenLichSuKien(SuKien suKien) async {
    try {
      await huyLichSuKien(suKien.id);

      // Đọc setting âm thanh
      final soundType = await SoundSettings.getType();
      final packageInfo = await PackageInfo.fromPlatform();
      final customUri =
          await SoundSettings.getCustomSoundUri(packageInfo.packageName);

      // Chọn channel tương ứng
      final String channelId;
      final String channelName;
      final String? soundUriStr;

      if (soundType == SoundType.custom && customUri != null) {
        channelId = SoundSettings.channelIdCustom;
        channelName = SoundSettings.channelNameCustom;
        soundUriStr = customUri.toString();
      } else {
        channelId = SoundSettings.channelIdSystem;
        channelName = SoundSettings.channelNameSystem;
        soundUriStr = null;
      }

      final now = DateTime.now();
      final namHienTai = now.year;

      final ngaySuKienNamNay = _tinhNgaySuKien(suKien, namHienTai);
      if (ngaySuKienNamNay == null) return;
      final ngaySuKienNamSau = _tinhNgaySuKien(suKien, namHienTai + 1);
      if (ngaySuKienNamSau == null) return;

      final ngayBaoNamNay =
          ngaySuKienNamNay.subtract(Duration(days: suKien.baoTruoc));
      final thoiDiemChinhNamNay = DateTime(
        ngayBaoNamNay.year,
        ngayBaoNamNay.month,
        ngayBaoNamNay.day,
        _gioNhac,
        _phutNhac,
      );

      DateTime ngaySuKien;
      DateTime thoiDiemChinh;
      DateTime thoiDiemNhacLai;

      if (thoiDiemChinhNamNay.isBefore(now)) {
        ngaySuKien = ngaySuKienNamSau;
        final ngayBaoNamSau =
            ngaySuKienNamSau.subtract(Duration(days: suKien.baoTruoc));
        thoiDiemChinh = DateTime(
          ngayBaoNamSau.year,
          ngayBaoNamSau.month,
          ngayBaoNamSau.day,
          _gioNhac,
          _phutNhac,
        );
        thoiDiemNhacLai = DateTime(
          ngayBaoNamSau.year,
          ngayBaoNamSau.month,
          ngayBaoNamSau.day,
          _gioNhacLai,
          _phutNhacLai,
        );
      } else {
        ngaySuKien = ngaySuKienNamNay;
        thoiDiemChinh = thoiDiemChinhNamNay;
        thoiDiemNhacLai = DateTime(
          ngayBaoNamNay.year,
          ngayBaoNamNay.month,
          ngayBaoNamNay.day,
          _gioNhacLai,
          _phutNhacLai,
        );
      }

      // === LÊN LỊCH CHÍNH ===
      if (thoiDiemChinh.isAfter(now)) {
        await AndroidAlarmManager.oneShotAt(
          thoiDiemChinh,
          _idChinh(suKien.id),
          _showScheduledNotification,
          params: {
            'title': '📅 Sắp đến: ${suKien.ten}',
            'body': _taoNoiDung(suKien, ngaySuKien),
            'payload': suKien.id,
            'channelId': channelId,
            'channelName': channelName,
            'soundUri': soundUriStr,
          },
          exact: true,
          wakeup: true,
          alarmClock: true,
          rescheduleOnReboot: false,
        );
        debugPrint('✅ ĐÃ LÊN LỊCH CHÍNH: ${suKien.ten} → $thoiDiemChinh '
            '(âm: ${soundType.name})');
      }

      // === LÊN LỊCH NHẮC LẠI ===
      if (thoiDiemNhacLai.isAfter(now)) {
        await AndroidAlarmManager.oneShotAt(
          thoiDiemNhacLai,
          _idNhacLai(suKien.id),
          _showScheduledNotification,
          params: {
            'title': '🔔 Nhắc lại: ${suKien.ten}',
            'body': _taoNoiDungNhacLai(suKien, ngaySuKien),
            'payload': suKien.id,
            'channelId': channelId,
            'channelName': channelName,
            'soundUri': soundUriStr,
          },
          exact: true,
          wakeup: true,
          alarmClock: true,
          rescheduleOnReboot: false,
        );
        debugPrint('✅ ĐÃ LÊN LỊCH NHẮC LẠI: ${suKien.ten} → $thoiDiemNhacLai');
      }
    } catch (e) {
      debugPrint('❌ LỖI lên lịch thông báo: $e');
    }
  }

  static Future<void> huyLichSuKien(String suKienId) async {
    try {
      await AndroidAlarmManager.cancel(_idChinh(suKienId));
      await AndroidAlarmManager.cancel(_idNhacLai(suKienId));
    } catch (e) {
      debugPrint('Lỗi hủy lịch: $e');
    }
  }

  static Future<void> khoiPhucLich(List<SuKien> danhSach) async {
    for (final sk in danhSach) {
      await lenLichSuKien(sk);
    }
    debugPrint('Đã khôi phục ${danhSach.length} lịch thông báo');
  }

  /// Khôi phục lại tất cả lịch sau khi đổi âm thanh
  static Future<void> khoiPhucSauDoiAm(List<SuKien> danhSach) async {
    for (final sk in danhSach) {
      await AndroidAlarmManager.cancel(_idChinh(sk.id));
      await AndroidAlarmManager.cancel(_idNhacLai(sk.id));
    }
    await khoiPhucLich(danhSach);
  }

  // ============================================================
  // HÀM PHỤ
  // ============================================================

  static DateTime? _tinhNgaySuKien(SuKien sk, int nam) {
    try {
      return LunarSolarConverter.lunarToSolar(sk.ngayAm, sk.thangAm, nam);
    } catch (_) {
      return null;
    }
  }

  static String _taoNoiDung(SuKien sk, DateTime ngaySuKien) {
    final ngayText = '${ngaySuKien.day}/${ngaySuKien.month}/${ngaySuKien.year}';
    final ghiChu =
        sk.ghiChu != null && sk.ghiChu!.isNotEmpty ? ' — ${sk.ghiChu}' : '';
    if (sk.baoTruoc == 0) {
      return 'Hôm nay là "${sk.ten}" ($ngayText).$ghiChu';
    }
    return 'Còn ${sk.baoTruoc} ngày nữa là đến "${sk.ten}" '
        '(ngày $ngayText).$ghiChu';
  }

  static String _taoNoiDungNhacLai(SuKien sk, DateTime ngaySuKien) {
    final ngayText = '${ngaySuKien.day}/${ngaySuKien.month}/${ngaySuKien.year}';
    final ghiChu =
        sk.ghiChu != null && sk.ghiChu!.isNotEmpty ? ' — ${sk.ghiChu}' : '';
    if (sk.baoTruoc == 0) {
      return 'Hôm nay là "${sk.ten}" ($ngayText).$ghiChu';
    }
    return 'Ngày mai là "${sk.ten}" ($ngayText).$ghiChu';
  }
}
