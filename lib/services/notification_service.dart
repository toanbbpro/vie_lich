import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import '../models/su_kien.dart';
import '../utils/lunar_vn.dart';
import 'sound_settings.dart';

const String _channelDesc = 'Thông báo nhắc trước ngày giỗ, lễ theo âm lịch';

// ============================================================
// CALLBACK CHẠY TRONG ISOLATE TỪ BACKGROUND
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

  // Gọi trực tiếp plugin show. Việc phát âm thanh OS đã tự lo qua thiết lập Channel.
  await plugin.show(
    id: id,
    title: params['title'] as String?,
    body: params['body'] as String?,
    notificationDetails: _buildNotificationDetails(
      channelId: channelId,
      channelName: channelName,
    ),
    payload: params['payload'] as String?,
  );
}

NotificationDetails _buildNotificationDetails({
  required String channelId,
  required String channelName,
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

    await _xoaTatCaKenhCu();
    await _taoTatCaKenh();
    await _xinQuyen();
  }

  static Future<void> _xoaTatCaKenhCu() async {
    if (!Platform.isAndroid) return;
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      // Xóa kênh cũ mặc định
      await androidImpl?.deleteNotificationChannel(
          channelId: SoundSettings.channelIdSystem);
      await androidImpl?.deleteNotificationChannel(
          channelId: SoundSettings.channelIdCustom);

      // Xóa tất cả các kênh custom được tạo tự động (tránh rác OS)
      final channels = await androidImpl?.getNotificationChannels();
      if (channels != null) {
        for (final c in channels) {
          if (c.id.startsWith(SoundSettings.channelIdCustom)) {
            await androidImpl?.deleteNotificationChannel(channelId: c.id);
          }
        }
      }
      debugPrint('🗑️ Đã xóa dọn dẹp các kênh thông báo cũ');
    } catch (e) {
      debugPrint('Lỗi xóa kênh cũ: $e');
    }
  }

  static Future<void> _taoTatCaKenh() async {
    if (!Platform.isAndroid) return;

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return;

    // Kênh system — dùng âm hệ thống
    const channelSystem = AndroidNotificationChannel(
      SoundSettings.channelIdSystem,
      SoundSettings.channelNameSystem,
      description: _channelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      showBadge: true,
      sound: null,
    );
    await androidImpl.createNotificationChannel(channelSystem);

    // Kênh custom — Giao phó hoàn toàn âm thanh cho Android OS xử lý
    final dynamicCustomId = await SoundSettings.getCustomChannelId();
    final customUri = await SoundSettings.getCustomSoundUri();

    AndroidNotificationSound? customSound;
    if (customUri != null && customUri.isNotEmpty) {
      customSound = UriAndroidNotificationSound(customUri);
    }

    final channelCustom = AndroidNotificationChannel(
      dynamicCustomId,
      SoundSettings.channelNameCustom,
      description: _channelDesc,
      importance: Importance.max,
      playSound: true, // OS sẽ TỰ PHÁT NHẠC, không cần code ngoài
      sound: customSound, // Truyền trực tiếp content:// URI vào đây
      enableVibration: true,
      enableLights: true,
      showBadge: true,
    );
    await androidImpl.createNotificationChannel(channelCustom);

    debugPrint('✅ Đã tạo kênh: system + custom ($dynamicCustomId)');
  }

  static Future<void> _xinQuyen() async {
    if (!Platform.isAndroid) return;
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
  }

  /// Tái tạo kênh (khi user đổi nhạc)
  static Future<void> recreateCustomChannel() async {
    await _xoaTatCaKenhCu();
    await _taoTatCaKenh();
  }

  static int _idChinh(String suKienId) => suKienId.hashCode & 0x7FFFFFFF;

  static Future<void> lenLichSuKien(SuKien suKien) async {
    try {
      await huyLichSuKien(suKien.id);

      final soundType = await SoundSettings.getType();
      final bool dungCustom = soundType == SoundType.custom;

      // Lấy channel ID tương ứng (động cho custom, tĩnh cho system)
      final String channelId;
      final String channelName;
      if (dungCustom) {
        channelId = await SoundSettings.getCustomChannelId();
        channelName = SoundSettings.channelNameCustom;
      } else {
        channelId = SoundSettings.channelIdSystem;
        channelName = SoundSettings.channelNameSystem;
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
        suKien.gioNhac,
        suKien.phutNhac,
      );

      DateTime ngaySuKien;
      DateTime thoiDiemChinh;

      if (thoiDiemChinhNamNay.isBefore(now)) {
        ngaySuKien = ngaySuKienNamSau;
        final ngayBaoNamSau =
            ngaySuKienNamSau.subtract(Duration(days: suKien.baoTruoc));
        thoiDiemChinh = DateTime(
          ngayBaoNamSau.year,
          ngayBaoNamSau.month,
          ngayBaoNamSau.day,
          suKien.gioNhac,
          suKien.phutNhac,
        );
      } else {
        ngaySuKien = ngaySuKienNamNay;
        thoiDiemChinh = thoiDiemChinhNamNay;
      }

      if (thoiDiemChinh.isAfter(now)) {
        await AndroidAlarmManager.oneShotAt(
          thoiDiemChinh,
          _idChinh(suKien.id),
          _showScheduledNotification,
          params: {
            'title': '📅 Sắp đến: ${suKien.ten}',
            'body': _taoNoiDung(suKien, ngaySuKien),
            'payload': suKien.id,
            'channelId': channelId, // Gửi đúng channelId tới Isolate
            'channelName': channelName,
          },
          exact: true,
          wakeup: true,
          alarmClock: true,
          rescheduleOnReboot:
              true, // Sửa thành true để hệ thống tự cấp lại Alarm sau khi restart
        );
        debugPrint(
            '✅ ĐÃ LÊN LỊCH: ${suKien.ten} → $thoiDiemChinh (Kênh: $channelId)');
      }
    } catch (e) {
      debugPrint('❌ LỖI lên lịch thông báo: $e');
    }
  }

  static Future<void> huyLichSuKien(String suKienId) async {
    try {
      await AndroidAlarmManager.cancel(_idChinh(suKienId));
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

  static Future<void> khoiPhucSauDoiAm(List<SuKien> danhSach) async {
    for (final sk in danhSach) {
      await AndroidAlarmManager.cancel(_idChinh(sk.id));
    }
    await khoiPhucLich(danhSach);
  }

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
}
