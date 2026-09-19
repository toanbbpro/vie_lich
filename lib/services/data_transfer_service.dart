import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import '../models/su_kien.dart';

class DataTransferService {
  /// Đóng gói sự kiện thành file JSON và kích hoạt bảng Chia sẻ của hệ thống
  static Future<bool> exportAndShare(List<SuKien> dsSuKien) async {
    try {
      final List<Map<String, dynamic>> jsonList =
          dsSuKien.map((e) => e.toJson()).toList();
      final String jsonString = jsonEncode(jsonList);

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/vie_lich_backup.json');
      await file.writeAsString(jsonString);

      // Dùng lại API quen thuộc và tắt cảnh báo vàng (cách an toàn nhất)
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Sao lưu nhắc sự kiện - Âm lịch Việt Nam',
      );
      return true;
    } catch (e) {
      debugPrint('Lỗi export: $e');
      return false;
    }
  }

  /// Mở hộp thoại chọn file JSON và parse dữ liệu
  static Future<List<SuKien>?> importFromJson() async {
    try {
      // Ở bản mới, result trả về trực tiếp List<PlatformFile> và không bao giờ null
      final result = await FilePicker.pickFiles(type: FileType.any);

      // Kiểm tra danh sách rỗng hoặc file lỗi
      if (result.isEmpty || result.first.path == null) return null;

      final file = File(result.first.path!);
      final String jsonString = await file.readAsString();

      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded
          .map((e) => SuKien.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Lỗi import: $e');
      return null;
    }
  }
}
