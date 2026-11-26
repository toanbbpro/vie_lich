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
import 'ics_service.dart';
import 'ram_mung1_settings.dart';
import 'sound_settings.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static final Map<int, Timer> _linuxTimers = {};
  static AudioPlayer? _linuxAudioPlayer;

  static const int _ramMung1BaseId = 2000000;
  static const int _ramMung1MaxSlots = 60;

  static Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
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
  }

  /// Tránh xung đột với dải ID dành riêng cho Mùng 1 / Rằm (_ramMung1BaseId.._ramMung1BaseId+99)
  static int _generateNotificationId(String id) {
    final raw = id.hashCode.abs() % 1900000;
    return raw + 1000;
  }

  static Future<void> _datMotThongBao({
    required int id,
    required String title,
    required String body,
    required DateTime thoiGianBaoThuc,
    required DateTime now,
    String? payload,
  }) async {
    if (!thoiGianBaoThuc.isAfter(now)) return;

    if (Platform.isLinux) {
      _linuxTimers[id]?.cancel();
      final delay = thoiGianBaoThuc.difference(now);
      _linuxTimers[id] = Timer(delay, () async {
        _linuxTimers.remove(id);
        await _showLinuxNotification(
          id: id,
          title: title,
          body: body,
          payload: payload,
        );
      });
      return;
    }

    final tzTime = tz.TZDateTime.from(thoiGianBaoThuc, tz.local);

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'vie_lich_channel',
      'Nhắc Lịch Sự Kiện',
      channelDescription: 'Thông báo ngày giỗ, lễ tết, Mùng 1 & Rằm, nhắc việc',
      importance: Importance.max,
      priority: Priority.high,
    );

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

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzTime,
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  static Future<void> lenLichSuKien(SuKien sk) async {
    final now = DateTime.now();
    final amHienTai = AmLichHelper.duongSangAm(now);
    final namAmHienTai = amHienTai != null ? amHienTai.year : now.year;
    final todayOnly = DateTime(now.year, now.month, now.day);

    final int namAmTinhToan = sk.namAm ?? namAmHienTai;
    DateTime? ngayDuong =
        IcsService.tinhNgayDuongTheoNamAm(namAmTinhToan, sk.thangAm, sk.ngayAm);

    if (sk.namAm == null && ngayDuong != null) {
      final dateOnly =
          DateTime(ngayDuong.year, ngayDuong.month, ngayDuong.day);
      if (dateOnly.isBefore(todayOnly)) {
        ngayDuong = IcsService.tinhNgayDuongTheoNamAm(
            namAmHienTai + 1, sk.thangAm, sk.ngayAm);
      }
    }

    if (ngayDuong == null) return;

    final thoiGianBaoThuc = DateTime(
      ngayDuong.year,
      ngayDuong.month,
      ngayDuong.day,
      sk.gioNhac,
      sk.phutNhac,
    ).subtract(Duration(days: sk.baoTruoc));

    await _datMotThongBao(
      id: _generateNotificationId(sk.id),
      title: 'Sắp đến: ${sk.ten}',
      body:
          'Sự kiện diễn ra vào ${ngayDuong.day}/${ngayDuong.month}/${ngayDuong.year}',
      thoiGianBaoThuc: thoiGianBaoThuc,
      now: now,
      payload: sk.id,
    );
  }

  /// Hủy toàn bộ các mốc thông báo Mùng 1 & Rằm đã đặt trước đó.
  static Future<void> huyLichRamMung1() async {
    for (int i = 0; i < _ramMung1MaxSlots; i++) {
      final id = _ramMung1BaseId + i;
      if (Platform.isLinux) {
        _linuxTimers.remove(id)?.cancel();
      }
      await _notificationsPlugin.cancel(id: id);
    }
  }

  /// Đặt lại thông báo cho 12 kỳ Mùng 1 & Rằm tiếp theo dựa trên cấu hình hiện tại.
  static Future<void> lenLichRamMung1([RamMung1Config? customConfig]) async {
    await huyLichRamMung1();
    final config = customConfig ?? await RamMung1Settings.load();
    if (!config.enabled) return;

    final now = DateTime.now();
    final dsMoc = RamMung1Settings.tinhCacMocNhacTiepTheo(config, now, soKy: 12);
    for (int i = 0; i < dsMoc.length && i < _ramMung1MaxSlots; i++) {
      final moc = dsMoc[i];
      await _datMotThongBao(
        id: _ramMung1BaseId + i,
        title: moc.title,
        body: moc.body,
        thoiGianBaoThuc: moc.thoiGianBao,
        now: now,
        payload: 'ram_mung1_${moc.ngayAm}_${moc.thangAm}',
      );
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
    final notificationId = _generateNotificationId(id);
    if (Platform.isLinux) {
      _linuxTimers.remove(notificationId)?.cancel();
    }
    await _notificationsPlugin.cancel(id: notificationId);
  }

  static Future<void> khoiPhucLich(List<SuKien> dsSuKien) async {
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
    await lenLichRamMung1();
  }

  static Future<void> khoiPhucSauDoiAm([dynamic argument]) async {
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
    if (Platform.isIOS || Platform.isMacOS || Platform.isLinux) return;
    final androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.deleteNotificationChannel(
          channelId: 'vie_lich_channel');
    }
  }
}
