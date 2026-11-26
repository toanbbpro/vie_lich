import 'dart:convert';
import 'dart:io' show File;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/su_kien.dart';

class BackupService {
  /// Chỉ xuất/nhập các key cài đặt an toàn (tránh ghi đè đường dẫn file nội bộ)
  static const Set<String> _allowedSettingsKeys = {
    'sound_type',
    'custom_sound_original_name',
    'linux_widget_visible',
    'linux_widget_locked',
    'linux_widget_size_mode',
    'linux_widget_pos_x',
    'linux_widget_pos_y',
    'ram_mung1_enabled',
    'ram_mung1_before_1day',
    'ram_mung1_before_hour',
    'ram_mung1_before_minute',
    'ram_mung1_on_day',
    'ram_mung1_on_day_hour',
    'ram_mung1_on_day_minute',
  };

  static const Set<String> _allowedSizeModes = {
    'small',
    'medium',
    'large',
    'extraLarge',
  };

  static const int _maxBackupBytes = 10 * 1024 * 1024; // 10 MB

  /// Xuất toàn bộ Sự kiện + Cấu hình Cài đặt an toàn thành file Backup hoàn chỉnh
  static Future<bool> taoBanSaoLuu(List<SuKien> dsSuKien) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Đóng gói danh sách sự kiện
      final List<Map<String, dynamic>> jsonSuKien = dsSuKien.map((e) => e.toJson()).toList();

      // Đóng gói cài đặt ứng dụng theo allowlist
      final Map<String, dynamic> settings = {};
      for (final k in _allowedSettingsKeys) {
        if (prefs.containsKey(k)) {
          settings[k] = prefs.get(k);
        }
      }

      final Map<String, dynamic> backupPayload = {
        'version': 2,
        'timestamp': DateTime.now().toIso8601String(),
        'events': jsonSuKien,
        'settings': settings,
      };

      final String jsonString = jsonEncode(backupPayload);
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/vie_lich_full_backup.json');
      await file.writeAsString(jsonString);

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Bản sao lưu toàn diện - Ứng dụng Âm lịch Việt Nam',
      );
      return true;
    } catch (e) {
      debugPrint('Lỗi tạo backup: $e');
      return false;
    }
  }

  /// Khôi phục toàn bộ từ file backup (chỉ nhận key và kiểu hợp lệ)
  static Future<Map<String, dynamic>?> khoiPhucSaoLuu() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (result.isEmpty || result.first.path == null) {
        return null;
      }

      final file = File(result.first.path!);
      if (await file.length() > _maxBackupBytes) {
        debugPrint('File backup vượt quá 10 MB');
        return null;
      }

      final String jsonString = await file.readAsString();
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) return null;

      // Khôi phục cài đặt SharedPreferences theo allowlist
      final rawSettings = decoded['settings'];
      if (rawSettings is Map<String, dynamic>) {
        final prefs = await SharedPreferences.getInstance();
        for (final entry in rawSettings.entries) {
          if (!_allowedSettingsKeys.contains(entry.key)) continue;
          if (entry.key == 'linux_widget_size_mode' &&
              !_allowedSizeModes.contains(entry.value)) {
            continue;
          }
          if (entry.key == 'sound_type' &&
              entry.value != 'system' &&
              entry.value != 'custom') {
            continue;
          }

          if (entry.value is bool) {
            await prefs.setBool(entry.key, entry.value as bool);
          } else if (entry.value is int) {
            await prefs.setInt(entry.key, entry.value as int);
          } else if (entry.value is double) {
            await prefs.setDouble(entry.key, entry.value as double);
          } else if (entry.value is String &&
              (entry.value as String).length <= 255) {
            await prefs.setString(entry.key, entry.value as String);
          }
        }
      }

      return decoded;
    } catch (e) {
      debugPrint('Lỗi đọc backup: $e');
      return null;
    }
  }
}
