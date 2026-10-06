import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io' show Platform;
import 'package:hive_ce/hive.dart';
import '../models/su_kien.dart';
import '../utils/am_lich_helper.dart';

/// Notification service cho Android, iOS, macOS.
///
/// Windows KHÔNG dùng service này — đã chuyển sang Go helper
/// (`vie_lich_helper.exe`) đọc `schedule.json` và bắn toast native.
/// Các method dưới đây đều có guard `if (Platform.isWindows) return;`
/// để tránh crash khi bị gọi nhầm trên Windows.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

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
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint("Người dùng đã chạm vào thông báo có ID: ${response.payload}");
      },
    );

    // macOS: request permission thủ công
    if (Platform.isMacOS) {
      final macOSPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>();
      await macOSPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    debugPrint('✅ NotificationService đã init trên ${Platform.operatingSystem}');
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
        ngayDuong = AmLichHelper.amSangDuong(
            namAmHienTai + 1, sk.thangAm, sk.ngayAm);
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
        id: sk.id.hashCode,
        title: 'Sắp đến: ${sk.ten}',
        body:
            'Sự kiện diễn ra vào ${ngayDuong.day}/${ngayDuong.month}/${ngayDuong.year}',
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

  static Future<void> huyLichSuKien(String id) async {
    if (Platform.isWindows) return;
    await _notificationsPlugin.cancel(id: id.hashCode);
  }

  static Future<void> khoiPhucLich(List<SuKien> dsSuKien) async {
    if (Platform.isWindows) return;
    await _notificationsPlugin.cancelAll();
    for (var sk in dsSuKien) {
      await lenLichSuKien(sk);
    }
  }

  static Future<void> khoiPhucSauDoiAm([dynamic argument]) async {
    if (Platform.isWindows) return;
    try {
      final box = Hive.box<SuKien>('suKienBox');
      final dsSuKien = box.values.toList();
      await khoiPhucLich(dsSuKien);
    } catch (e) {
      debugPrint('Lỗi khôi phục lịch: $e');
    }
  }

  static Future<void> recreateCustomChannel([String? soundFileName]) async {
    if (Platform.isIOS || Platform.isMacOS || Platform.isWindows) return;
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.deleteNotificationChannel(
          channelId: 'vie_lich_channel');
    }
  }
}