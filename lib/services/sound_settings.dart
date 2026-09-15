import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

/// Loại âm thanh thông báo
enum SoundType { system, custom }

class SoundSettings {
  static const String _keyType = 'sound_type';
  static const String _keyCustomPath = 'custom_sound_path';

  /// Tên file âm thanh custom (không có phần mở rộng)
  static const String customFileName = 'custom_sound';

  /// Channel ID cho âm hệ thống
  static const String channelIdSystem = 'nhac_su_kien_system';

  /// Channel ID cho âm tùy chỉnh
  static const String channelIdCustom = 'nhac_su_kien_custom';

  static const String channelNameSystem = 'Nhắc sự kiện - Âm hệ thống';
  static const String channelNameCustom = 'Nhắc sự kiện - Âm tùy chỉnh';

  /// Lấy loại âm thanh hiện tại
  static Future<SoundType> getType() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_keyType) ?? 'system';
    return s == 'custom' ? SoundType.custom : SoundType.system;
  }

  /// Đặt loại âm thanh
  static Future<void> setType(SoundType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyType, type == SoundType.custom ? 'custom' : 'system');
  }

  /// Lấy đường dẫn file âm thanh custom (null nếu chưa có)
  static Future<String?> getCustomPath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_keyCustomPath);
    if (path == null) return null;
    if (!File(path).existsSync()) return null;
    return path;
  }

  /// Lấy tên file custom (để hiển thị)
  static Future<String?> getCustomFileName() async {
    final path = await getCustomPath();
    if (path == null) return null;
    return path.split('/').last;
  }

  /// Copy file âm thanh từ đường dẫn bất kỳ vào thư mục app.
  /// Trả về đường dẫn mới trong app.
  static Future<String> copySoundFile(String sourcePath) async {
    final dir = await _getSoundsDir();

    // Xóa file cũ (nếu có) để giải phóng tên
    for (final f in dir.listSync()) {
      if (f is File) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }

    final ext = sourcePath.split('.').last.toLowerCase();
    final destPath = '${dir.path}/$customFileName.$ext';
    await File(sourcePath).copy(destPath);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomPath, destPath);

    return destPath;
  }

  /// Xóa file custom
  static Future<void> deleteCustomSound() async {
    final dir = await _getSoundsDir();
    for (final f in dir.listSync()) {
      if (f is File) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCustomPath);
  }

  /// Lấy content URI của file custom để dùng cho notification channel.
  /// Trả về null nếu chưa có file.
  static Future<Uri?> getCustomSoundUri(String packageName) async {
    final path = await getCustomPath();
    if (path == null) return null;
    final fileName = path.split('/').last;
    // FileProvider authority: <packageName>.fileprovider
    // File nằm trong <filesDir>/sounds/<fileName> → content://<authority>/sounds/<fileName>
    return Uri.parse('content://$packageName.fileprovider/sounds/$fileName');
  }

  /// Thư mục chứa file âm thanh trong app
  static Future<Directory> _getSoundsDir() async {
    // getApplicationSupportDirectory() trên Android trả về context.getFilesDir()
    // tức là /data/user/0/<package>/files
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/sounds');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
