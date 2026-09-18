import 'package:flutter/services.dart';

class MediaStoreService {
  static const MethodChannel _channel =
      MethodChannel('com.toanbb.vie_lich/media_store');

  /// Lưu file âm thanh vào MediaStore.
  /// Trả về content:// URI hoặc null nếu thất bại.
  static Future<String?> saveSound(String sourcePath) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'saveSound',
        {'sourcePath': sourcePath},
      );
      return result;
    } catch (e) {
      // ignore: avoid_print
      print('❌ Lỗi saveSound: $e');
      return null;
    }
  }

  /// Xóa file âm thanh khỏi MediaStore.
  /// Trả về true nếu xóa thành công.
  static Future<bool> deleteSound() async {
    try {
      final result = await _channel.invokeMethod<bool>('deleteSound');
      return result ?? false;
    } catch (e) {
      // ignore: avoid_print
      print('❌ Lỗi deleteSound: $e');
      return false;
    }
  }

  /// Kiểm tra file âm thanh có tồn tại trong MediaStore không.
  static Future<bool> existsSound() async {
    try {
      final result = await _channel.invokeMethod<bool>('existsSound');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
}
