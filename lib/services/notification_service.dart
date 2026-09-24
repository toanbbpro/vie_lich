import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io' show Platform;
import 'package:hive_ce/hive.dart';
import '../models/su_kien.dart';
import '../utils/am_lich_helper.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      // SỬA: Đổi thành tham số có tên `settings:`
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint("Người dùng đã chạm vào thông báo có ID: ${response.payload}");
      },
    );
  }

  static Future<void> lenLichSuKien(SuKien sk) async {
    final now = DateTime.now();
    
    final amHienTai = AmLichHelper.duongSangAm(now);
    final namAmHienTai = amHienTai != null ? amHienTai.getYear() : now.year;
    final todayOnly = DateTime(now.year, now.month, now.day);

    int namAmTinhToan = sk.namAm ?? namAmHienTai;
    DateTime? ngayDuong = AmLichHelper.amSangDuong(namAmTinhToan, sk.thangAm, sk.ngayAm);

    if (sk.namAm == null && ngayDuong != null) {
      DateTime dateOnly = DateTime(ngayDuong.year, ngayDuong.month, ngayDuong.day);
      if (dateOnly.isBefore(todayOnly)) {
        ngayDuong = AmLichHelper.amSangDuong(namAmHienTai + 1, sk.thangAm, sk.ngayAm);
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

    if (thoiGianBaoThuc.isAfter(now)) {
      final tzTime = tz.TZDateTime.from(thoiGianBaoThuc, tz.local);

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'vie_lich_channel',
        'Nhắc Lịch Sự Kiện',
        channelDescription: 'Thông báo ngày giỗ, lễ tết, nhắc việc',
        importance: Importance.max,
        priority: Priority.high,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        // SỬA: Thêm tên cho toàn bộ các tham số & xóa uiLocalNotificationDateInterpretation
        id: sk.id.hashCode,
        title: 'Sắp đến: ${sk.ten}',
        body: 'Sự kiện diễn ra vào ${ngayDuong.day}/${ngayDuong.month}/${ngayDuong.year}',
        scheduledDate: tzTime,
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: sk.id,
      );
      
      debugPrint("Đã hẹn giờ báo: ${sk.ten} lúc $thoiGianBaoThuc");
    }
  }

  static Future<void> huyLichSuKien(String id) async {
    // SỬA: Đổi thành tham số có tên `id:`
    await _notificationsPlugin.cancel(id: id.hashCode);
  }

  static Future<void> khoiPhucLich(List<SuKien> dsSuKien) async {
    await _notificationsPlugin.cancelAll(); 
    for (var sk in dsSuKien) {
      await lenLichSuKien(sk); 
    }
  }

  static Future<void> khoiPhucSauDoiAm([dynamic argument]) async {
    try {
      final box = Hive.box<SuKien>('suKienBox');
      final dsSuKien = box.values.toList();
      await khoiPhucLich(dsSuKien);
    } catch (e) {
      debugPrint('Lỗi khôi phục lịch sau khi đổi âm: $e');
    }
  }

  static Future<void> recreateCustomChannel([String? soundFileName]) async {
    if (Platform.isIOS) return; 

    final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      // SỬA: Đổi thành tham số có tên `channelId:`
      await androidPlugin.deleteNotificationChannel(channelId: 'vie_lich_channel');
      debugPrint('Đã xóa channel cũ để cập nhật âm thanh: $soundFileName');
    }
  }
}