import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Service tự động cập nhật app trên macOS từ GitHub Release.
///
/// Yêu cầu:
/// - GitHub release có file `VIE_Lich_vX.Y.Z.zip` chứa `VIE Lich.app` đã sign + notarize
/// - App cài ở /Applications (hoặc user có quyền ghi thư mục chứa app)
///
/// Flow:
/// 1. Download .zip từ GitHub
/// 2. Unzip ra thư mục tạm
/// 3. Tạo shell script: đợi app thoát → xóa app cũ → move app mới → open
/// 4. Spawn script detached → app thoát
/// 5. Script chạy → mở app mới
class MacOSUpdateService {
  /// Download zip, giải nén, thay thế app hiện tại, rồi tự relaunch.
  static Future<void> downloadAndInstall({
    required String zipUrl,
    required Function(double) onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final zipPath = '${tempDir.path}/vie_lich_update.zip';
    final extractDir = '${tempDir.path}/vie_lich_extract';

    // Xóa thư mục extract cũ nếu có
    final extractDirObj = Directory(extractDir);
    if (await extractDirObj.exists()) {
      await extractDirObj.delete(recursive: true);
    }
    await extractDirObj.create(recursive: true);

    // 1. Download zip
    debugPrint('⬇️ Download update: $zipUrl');
    final dio = Dio();
    await dio.download(
      zipUrl,
      zipPath,
      onReceiveProgress: (received, total) {
        if (total != -1) onProgress(received / total);
      },
    );

    // 2. Unzip
    debugPrint('📦 Unzip...');
    final unzipResult = await Process.run('unzip', [
      '-q',
      '-o',
      zipPath,
      '-d',
      extractDir,
    ]);
    if (unzipResult.exitCode != 0) {
      throw Exception('Unzip failed: ${unzipResult.stderr}');
    }

    // 3. Tìm .app trong thư mục extract
    final newAppPath = await _findAppBundle(extractDir);
    if (newAppPath == null) {
      throw Exception('Không tìm thấy .app trong file zip');
    }
    debugPrint('✅ Tìm thấy app mới: $newAppPath');

    // 4. Xác định vị trí app hiện tại
    final currentAppPath = _getCurrentAppPath();
    debugPrint('📍 App hiện tại: $currentAppPath');

    // 5. Tạo shell script
    final scriptPath = '${tempDir.path}/vie_lich_update.sh';
    final script = _buildUpdateScript(
      currentApp: currentAppPath,
      newApp: newAppPath,
      zipPath: zipPath,
      extractDir: extractDir,
      scriptPath: scriptPath,
    );

    final scriptFile = File(scriptPath);
    await scriptFile.writeAsString(script);
    await Process.run('chmod', ['+x', scriptPath]);

    // 6. Spawn script detached
    debugPrint('🚀 Chạy update script và thoát app...');
    await Process.start(
      '/bin/bash',
      [scriptPath],
      mode: ProcessStartMode.detached,
    );

    // 7. Thoát app ngay
    await Future.delayed(const Duration(milliseconds: 300));
    exit(0);
  }

  /// Tìm file .app trong thư mục extract (đệ quy 2 cấp)
  static Future<String?> _findAppBundle(String dir) async {
    final dirObj = Directory(dir);
    final entries = await dirObj.list().toList();

    // Ưu tiên .app ở cấp 1
    for (final e in entries) {
      if (e is Directory && e.path.endsWith('.app')) {
        return e.path;
      }
    }

    // Đệ quy vào thư mục con 1 cấp
    for (final e in entries) {
      if (e is Directory) {
        final subEntries = await e.list().toList();
        for (final se in subEntries) {
          if (se is Directory && se.path.endsWith('.app')) {
            return se.path;
          }
        }
      }
    }
    return null;
  }

  /// Lấy path của .app hiện tại
  static String _getCurrentAppPath() {
    final exe = Platform.resolvedExecutable;
    // /Applications/VIE Lich.app/Contents/MacOS/VIE Lich
    final idx = exe.indexOf('.app/Contents/MacOS/');
    if (idx < 0) {
      throw Exception('Không xác định được vị trí app: $exe');
    }
    return exe.substring(0, idx + 4); // +4 để bao gồm ".app"
  }

  static String _buildUpdateScript({
    required String currentApp,
    required String newApp,
    required String zipPath,
    required String extractDir,
    required String scriptPath,
  }) {
    // Dùng string nối để tránh escape phức tạp với Dart
    final buffer = StringBuffer();
    buffer.writeln('#!/bin/bash');
    buffer.writeln('# Auto-update script cho VIE Lịch');
    buffer.writeln('');
    buffer.writeln('sleep 2');
    buffer.writeln('');
    buffer.writeln('CURRENT="$currentApp"');
    buffer.writeln('NEW="$newApp"');
    buffer.writeln('ZIP="$zipPath"');
    buffer.writeln('EXTRACT="$extractDir"');
    buffer.writeln('SCRIPT="$scriptPath"');
    buffer.writeln('');
    buffer.writeln('# Thử xóa + move trực tiếp (không cần admin nếu user sở hữu /Applications)');
    buffer.writeln('if rm -rf "\$CURRENT" 2>/dev/null && mv "\$NEW" "\$CURRENT" 2>/dev/null; then');
    buffer.writeln('    echo "✅ Update thành công (không cần admin)"');
    buffer.writeln('else');
    buffer.writeln('    echo "🔐 Cần quyền admin để thay thế app..."');
    buffer.writeln('    osascript <<EOF');
    buffer.writeln('do shell script "rm -rf \'$currentApp\' && mv \'$newApp\' \'$currentApp\'" with administrator privileges');
    buffer.writeln('EOF');
    buffer.writeln('fi');
    buffer.writeln('');
    buffer.writeln('# Xóa quarantine attribute (nếu có)');
    buffer.writeln('xattr -cr "\$CURRENT" 2>/dev/null');
    buffer.writeln('');
    buffer.writeln('# Mở app mới');
    buffer.writeln('open "\$CURRENT"');
    buffer.writeln('');
    buffer.writeln('# Cleanup');
    buffer.writeln('rm -rf "\$ZIP" 2>/dev/null');
    buffer.writeln('rm -rf "\$EXTRACT" 2>/dev/null');
    buffer.writeln('rm -f "\$SCRIPT" 2>/dev/null');
    buffer.writeln('');
    return buffer.toString();
  }
}