import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/su_kien.dart';

class BackupService {
  /// Xuất toàn bộ Sự kiện + Cấu hình Cài đặt thành file Backup hoàn chỉnh
  static Future<bool> taoBanSaoLuu(List<SuKien> dsSuKien) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Đóng gói danh sách sự kiện
      final List<Map<String, dynamic>> jsonSuKien = dsSuKien.map((e) => e.toJson()).toList();

      // Đóng gói cài đặt ứng dụng
      final Map<String, dynamic> settings = {};
      final keys = prefs.getKeys();
      for (String k in keys) {
        settings[k] = prefs.get(k);
      }

      final Map<String, dynamic> backupPayload = {
        'version': 1,
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

  /// Khôi phục toàn bộ từ file backup
  static Future<Map<String, dynamic>?> khoiPhucSaoLuu() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (result.isEmpty || result.first.path == null) {
        return null;
      }

      final file = File(result.first.path!);
      final String jsonString = await file.readAsString();
      final Map<String, dynamic> payload = jsonDecode(jsonString);

      // Khôi phục cài đặt SharedPreferences nếu có
      if (payload.containsKey('settings')) {
        final prefs = await SharedPreferences.getInstance();
        final Map<String, dynamic> settings = payload['settings'] as Map<String, dynamic>;
        for (var entry in settings.entries) {
          if (entry.value is bool) {
            await prefs.setBool(entry.key, entry.value as bool);
          } else if (entry.value is int) {
            await prefs.setInt(entry.key, entry.value as int);
          } else if (entry.value is double) {
            await prefs.setDouble(entry.key, entry.value as double);
          } else if (entry.value is String) {
            await prefs.setString(entry.key, entry.value as String);
          }
        }
      }

      return payload;
    } catch (e) {
      debugPrint('Lỗi đọc backup: $e');
      return null;
    }
  }
}