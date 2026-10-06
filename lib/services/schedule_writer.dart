import 'dart:convert';
import 'dart:io' show File, Directory, Platform;
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

import '../models/su_kien.dart';
import '../utils/am_lich_helper.dart';

/// Ghi schedule 7 ngày tới ra file JSON cho Go helper đọc.
/// Helper sẽ tự bắn toast khi đến giờ — không cần app Flutter chạy.
class ScheduleWriter {
  static const int _horizonDays = 7;

  static String? _getAppDir() {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null) return '$appData\\vie_lich';
    }
    return null;
  }

  /// Ghi schedule mới — gọi mỗi khi:
  ///   - App khởi động
  ///   - User thêm/sửa/xóa sự kiện
  static Future<void> writeAll() async {
    if (!Platform.isWindows) return;

    final dir = _getAppDir();
    if (dir == null) return;

    try {
      final box = Hive.box<SuKien>('suKienBox');
      final events = <Map<String, dynamic>>[];
      final now = DateTime.now();
      final horizon = now.add(const Duration(days: _horizonDays));

      for (final sk in box.values) {
        // Tính ngày dương của sự kiện
        final fireAt = _computeFireTime(sk, now);
        if (fireAt == null) continue;

        // Chỉ giữ event trong 7 ngày tới
        if (fireAt.isBefore(now)) continue;
        if (fireAt.isAfter(horizon)) continue;

        events.add({
          'id': sk.id,
          'title': 'Sắp đến: ${sk.ten}',
          'body': _buildBody(sk, fireAt),
          'fireAt': _toRfc3339(fireAt),
        });
      }

      // Sort theo fireAt
      events.sort((a, b) =>
          (a['fireAt'] as String).compareTo(b['fireAt'] as String));

      final schedule = {
        'version': 1,
        'generatedAt': _toRfc3339(now),
        'expiresAt': _toRfc3339(horizon),
        'timezone': 'Asia/Ho_Chi_Minh',
        'events': events,
      };

      // Atomic write: tmp → rename
      final dirObj = Directory(dir);
      if (!await dirObj.exists()) await dirObj.create(recursive: true);

      final mainFile = File('$dir\\schedule.json');
      final tmpFile = File('$dir\\schedule.json.tmp');

      await tmpFile.writeAsString(jsonEncode(schedule));
      await tmpFile.rename(mainFile.path);

      debugPrint('📝 Đã ghi schedule: ${events.length} events');
    } catch (e) {
      debugPrint('⚠️ Ghi schedule lỗi: $e');
    }
  }

  /// Xóa schedule khi user thoát hoàn toàn (không cần thiết, chỉ dùng khi uninstall)
  static Future<void> clear() async {
    final dir = _getAppDir();
    if (dir == null) return;
    try {
      final f = File('$dir\\schedule.json');
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  // ============================================================
  // HELPERS
  // ============================================================

  /// Tính thời điểm báo thức (đã trừ baoTruoc) — giống logic trong NotificationService
  static DateTime? _computeFireTime(SuKien sk, DateTime now) {
    final amHienTai = AmLichHelper.duongSangAm(now);
    final namAmHienTai = amHienTai?.getYear() ?? now.year;
    final todayOnly = DateTime(now.year, now.month, now.day);

    int namAmTinhToan = sk.namAm ?? namAmHienTai;
    DateTime? ngayDuong =
        AmLichHelper.amSangDuong(namAmTinhToan, sk.thangAm, sk.ngayAm);

    if (sk.namAm == null && ngayDuong != null) {
      final dateOnly = DateTime(ngayDuong.year, ngayDuong.month, ngayDuong.day);
      if (dateOnly.isBefore(todayOnly)) {
        ngayDuong = AmLichHelper.amSangDuong(
            namAmHienTai + 1, sk.thangAm, sk.ngayAm);
      }
    }

    if (ngayDuong == null) return null;

    return DateTime(
      ngayDuong.year,
      ngayDuong.month,
      ngayDuong.day,
      sk.gioNhac,
      sk.phutNhac,
    ).subtract(Duration(days: sk.baoTruoc));
  }

  static String _buildBody(SuKien sk, DateTime fireAt) {
    // fireAt = giờ báo, cần suy ra ngày sự kiện = fireAt + baoTruoc
    final eventDate = fireAt.add(Duration(days: sk.baoTruoc));
    return 'Sự kiện diễn ra vào '
        '${eventDate.day}/${eventDate.month}/${eventDate.year}';
  }

  /// Convert DateTime → RFC3339 với timezone +07:00
  static String _toRfc3339(DateTime dt) {
    final offset = dt.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final absOff = offset.abs();
    final hh = absOff.inHours.toString().padLeft(2, '0');
    final mm = (absOff.inMinutes % 60).toString().padLeft(2, '0');

    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}T'
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}'
        '$sign$hh:$mm';
  }
}