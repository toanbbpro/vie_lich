import 'dart:async';
import 'dart:io' show Platform, File;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:hive_ce/hive.dart';
import '../models/su_kien.dart';
import '../utils/am_lich_helper.dart';
import '../utils/app_constants.dart';
import 'sound_settings.dart';

/// Notification service cho Android, iOS, macOS.
///
/// Windows KHÔNG dùng service này — đã chuyển sang Go helper
/// (`vie_lich_helper.exe`) đọc `schedule.json` và bắn toast native.
/// Các method dưới đây đều có guard `if (Platform.isWindows) return;`
/// để tránh crash khi bị gọi nhầm trên Windows.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static final Map<int, Timer> _linuxTimers = {};
  static AudioPlayer? _linuxAudioPlayer;

  static Future<void> init() async {
    if (Platform.isWindows) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    // ---------- Android ----------
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // ---------- iOS / macOS ----------
    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      // ĐÃ THÊM: Ép buộc macOS phải hiện Popup kể cả khi app đang mở
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );

    final LinuxInitializationSettings linuxSettings =
        LinuxInitializationSettings(
      defaultActionName: 'Mở ứng dụng',
      defaultIcon: AssetsLinuxIcon('assets/icon/vie_lich_logo.png'),
    );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint(
            "Người dùng đã chạm vào thông báo có ID: ${response.payload}");
      },
    );

    // macOS: request permission thủ công
    if (Platform.isMacOS) {
      final macOSPlugin =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>();
      await macOSPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    debugPrint('✅ NotificationService đã init trên ${Platform.operatingSystem}');
  }

  /// Tránh xung đột bằng cách dùng một hàm tạo ID duy nhất từ UUID hoặc string
  static int _generateNotificationId(String id) {
    return id.hashCode.abs() % 2147483647;
  }

  // ============================================================
  // SCHEDULE
  // ============================================================
  static Future<void> lenLichSuKien(SuKien sk) async {
    if (Platform.isWindows) return;

    final now = DateTime.now();
    final amHienTai = AmLichHelper.duongSangAm(now);
    final namAmHienTai = amHienTai != null ? amHienTai.getYear() : now.year;
    final todayOnly = DateTime(now.year, now.month, now.day);

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

    if (ngayDuong == null) return;

    DateTime thoiGianBaoThuc = DateTime(
      ngayDuong.year,
      ngayDuong.month,
      ngayDuong.day,
      sk.gioNhac,
      sk.phutNhac,
    ).subtract(Duration(days: sk.baoTruoc));

    if (!thoiGianBaoThuc.isAfter(now)) return;

    final notificationId = _generateNotificationId(sk.id);
    final title = 'Sắp đến: ${sk.ten}';
    final body =
        'Sự kiện diễn ra vào ${ngayDuong.day}/${ngayDuong.month}/${ngayDuong.year}';

    if (Platform.isLinux) {
      _linuxTimers[notificationId]?.cancel();
      final delay = thoiGianBaoThuc.difference(now);
      // Timer tối đa khoảng ~24 ngày nếu quá lớn trên 32-bit, nhưng trên 64-bit thoải mái;
      // tuy nhiên vẫn đảm bảo an toàn khi đặt timer trong phiên chạy.
      _linuxTimers[notificationId] = Timer(delay, () async {
        _linuxTimers.remove(notificationId);
        await _showLinuxNotification(
          id: notificationId,
          title: title,
          body: body,
          payload: sk.id,
        );
      });
      return;
    }

    final tzTime = tz.TZDateTime.from(thoiGianBaoThuc, tz.local);

    // ---------- Android ----------
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'vie_lich_channel',
      'Nhắc Lịch Sự Kiện',
      channelDescription: 'Thông báo ngày giỗ, lễ tết, nhắc việc',
      importance: Importance.max,
      priority: Priority.high,
    );

    // ---------- iOS / macOS ----------
    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        id: notificationId,
        title: title,
        body: body,
        scheduledDate: tzTime,
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: sk.id,
      );
      debugPrint('📅 Đã lên lịch cho "${sk.ten}" lúc $thoiGianBaoThuc');
    } catch (e) {
      debugPrint('⚠️ Lên lịch lỗi cho "${sk.ten}": $e');
    }
  }

  static Future<void> _showLinuxNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final soundType = await SoundSettings.getType();
      final customPath = await SoundSettings.getCustomSoundLocalPath();
      final bool useCustomSound = soundType == SoundType.custom &&
          customPath != null &&
          File(customPath).existsSync();

      final linuxDetails = LinuxNotificationDetails(
        urgency: LinuxNotificationUrgency.critical,
        suppressSound: useCustomSound,
        sound: useCustomSound ? null : ThemeLinuxSound('message-new-instant'),
      );

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(linux: linuxDetails),
        payload: payload,
      );

      if (useCustomSound) {
        _linuxAudioPlayer ??= AudioPlayer();
        await _linuxAudioPlayer!.stop();
        await _linuxAudioPlayer!.play(DeviceFileSource(customPath));
      }
    } catch (e) {
      debugPrint('❌ [Linux Notification] Lỗi hiển thị thông báo: $e');
    }
  }

  static Future<void> huyLichSuKien(String id) async {
    if (Platform.isWindows) return;
    final notificationId = _generateNotificationId(id);
    if (Platform.isLinux) {
      _linuxTimers.remove(notificationId)?.cancel();
    }
    await _notificationsPlugin.cancel(id: notificationId);
  }

  static Future<void> khoiPhucLich(List<SuKien> dsSuKien) async {
    if (Platform.isWindows) return;
    if (Platform.isLinux) {
      for (final timer in _linuxTimers.values) {
        timer.cancel();
      }
      _linuxTimers.clear();
    }
    await _notificationsPlugin.cancelAll();
    for (var sk in dsSuKien) {
      await lenLichSuKien(sk);
    }
  }

  static Future<void> khoiPhucSauDoiAm([dynamic argument]) async {
    if (Platform.isWindows) return;
    try {
      final box = Hive.isBoxOpen(AppConstants.boxSuKien)
          ? Hive.box<SuKien>(AppConstants.boxSuKien)
          : await Hive.openBox<SuKien>(AppConstants.boxSuKien);
      final dsSuKien = box.values.toList();
      await khoiPhucLich(dsSuKien);
    } catch (e) {
      debugPrint('Lỗi khôi phục lịch: $e');
    }
  }

  static Future<void> recreateCustomChannel([String? soundFileName]) async {
    if (Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isLinux ||
        Platform.isWindows) {
      return;
    }
    final androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.deleteNotificationChannel(
          channelId: 'vie_lich_channel');
    }
  }
}
