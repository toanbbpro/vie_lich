import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

import 'media_store_service.dart';

enum SoundType { system, custom }

class SoundSettings {
  static const String _keyType = 'sound_type';
  static const String _keyCustomUri = 'custom_sound_uri';
  static const String _keyCustomLocalPath = 'custom_sound_local_path';
  static const String _keyCustomOriginalName = 'custom_sound_original_name';

  static const String channelIdSystem = 'nhac_su_kien_system_v2';
  static const String channelIdCustom = 'nhac_su_kien_custom_v2';
  static const String channelNameSystem = 'Nhắc sự kiện - Âm hệ thống';
  static const String channelNameCustom = 'Nhắc sự kiện - Âm tùy chỉnh';

  // Tự động sinh Channel ID động dựa trên URI để ép Android làm mới cấu hình âm thanh
  static Future<String> getCustomChannelId() async {
    final uri = await getCustomSoundUri();
    if (uri == null || uri.isEmpty) return channelIdCustom;
    return '${channelIdCustom}_${uri.hashCode}';
  }

  static Future<SoundType> getType() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_keyType) ?? 'system';
    return s == 'custom' ? SoundType.custom : SoundType.system;
  }

  static Future<void> setType(SoundType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyType, type == SoundType.custom ? 'custom' : 'system');
  }

  /// URI trong MediaStore — dùng cho notification channel
  static Future<String?> getCustomSoundUri() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCustomUri);
  }

  /// Đường dẫn file trong app — dùng cho preview playback
  static Future<String?> getCustomSoundLocalPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCustomLocalPath);
  }

  static Future<String?> getCustomFileName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCustomOriginalName);
  }

  static Future<bool> saveCustomSound(
    String sourcePath,
    String originalName,
  ) async {
    try {
      final ext = sourcePath.split('.').last.toLowerCase();

      // === 1. Lưu bản copy trong app (cho preview) ===
      final appDir = await getApplicationSupportDirectory();
      final soundsDir = Directory('${appDir.path}/sounds');
      if (!soundsDir.existsSync()) {
        await soundsDir.create(recursive: true);
      }
      final localFile = File('${soundsDir.path}/preview.$ext');
      if (localFile.existsSync()) {
        await localFile.delete();
      }
      await File(sourcePath).copy(localFile.path);

      // === 2. Lưu vào MediaStore (cho notification) ===
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/vie_lich_temp.mp3');
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }
      await File(sourcePath).copy(tempFile.path);

      final uri = await MediaStoreService.saveSound(tempFile.path);

      try {
        if (tempFile.existsSync()) await tempFile.delete();
      } catch (_) {}

      if (uri == null) return false;

      // === 3. Lưu metadata ===
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCustomUri, uri);
      await prefs.setString(_keyCustomLocalPath, localFile.path);
      await prefs.setString(_keyCustomOriginalName, originalName);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('❌ Lỗi saveCustomSound: $e');
      return false;
    }
  }

  static Future<void> deleteCustomSound() async {
    try {
      await MediaStoreService.deleteSound();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final localPath = prefs.getString(_keyCustomLocalPath);
    if (localPath != null) {
      try {
        final f = File(localPath);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
    }

    await prefs.remove(_keyCustomUri);
    await prefs.remove(_keyCustomLocalPath);
    await prefs.remove(_keyCustomOriginalName);
  }
}
