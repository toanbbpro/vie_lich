import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Service tự động cập nhật app trên macOS từ GitHub Release.
///
/// Bảo mật:
/// - Stage vào thư mục riêng trong Application Support (`updates/run_...`).
/// - Kiểm tra SHA-256 qua `shasum -a 256` trước khi giải nén/cài đặt.
/// - Dùng `on run argv` + `quoted form of` trong `osascript` để tránh shell/AppleScript injection.
class MacOSUpdateService {
  static Future<void> _verifySha256IfPresent(
    String filePath,
    String? expectedDigest,
  ) async {
    if (expectedDigest == null || !expectedDigest.startsWith('sha256:')) return;
    final expectedHex = expectedDigest.substring(7).trim().toLowerCase();
    final res = await Process.run('shasum', ['-a', '256', filePath]);
    if (res.exitCode != 0) {
      throw Exception('Không thể kiểm tra SHA-256: ${res.stderr}');
    }
    final actualHex =
        res.stdout.toString().trim().split(RegExp(r'\s+')).first.toLowerCase();
    if (actualHex != expectedHex) {
      throw Exception('Tệp cập nhật không khớp chữ ký SHA-256!');
    }
  }

  /// Download zip, kiểm tra hash, giải nén, thay thế app hiện tại, rồi tự relaunch.
  static Future<void> downloadAndInstall({
    required String zipUrl,
    required Function(double) onProgress,
    String? expectedDigest,
  }) async {
    final appSupport = await getApplicationSupportDirectory();
    final updatesRoot = Directory('${appSupport.path}/updates');
    if (!await updatesRoot.exists()) {
      await updatesRoot.create(recursive: true);
    }
    for (final entity in updatesRoot.listSync()) {
      try {
        await entity.delete(recursive: true);
      } catch (_) {}
    }

    final workDir = await updatesRoot.createTemp('run_');
    final zipPath = '${workDir.path}/vie_lich_update.zip';
    final extractDir = '${workDir.path}/extract';
    await Directory(extractDir).create(recursive: true);

    try {
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

      // 2. Đối chiếu SHA-256 nếu có từ GitHub API
      await _verifySha256IfPresent(zipPath, expectedDigest);

      // 3. Unzip
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

      // 4. Tìm .app trong thư mục extract
      final newAppPath = await _findAppBundle(extractDir);
      if (newAppPath == null) {
        throw Exception('Không tìm thấy .app trong file zip');
      }
      debugPrint('✅ Tìm thấy app mới: $newAppPath');

      // 5. Xác định vị trí app hiện tại
      final currentAppPath = _getCurrentAppPath();
      debugPrint('📍 App hiện tại: $currentAppPath');

      // 6. Tạo shell script an toàn (không nội suy đường dẫn trực tiếp vào osascript)
      final scriptPath = '${workDir.path}/vie_lich_update.sh';
      final script = _buildUpdateScript(
        currentApp: currentAppPath,
        newApp: newAppPath,
        workDirPath: workDir.path,
      );

      await File(scriptPath).writeAsString(script);
      await Process.run('chmod', ['700', scriptPath]);

      // 7. Spawn script detached
      debugPrint('🚀 Chạy update script và thoát app...');
      await Process.start(
        '/bin/bash',
        [scriptPath],
        mode: ProcessStartMode.detached,
      );

      // 8. Thoát app ngay
      await Future.delayed(const Duration(milliseconds: 300));
      exit(0);
    } catch (e) {
      try {
        await workDir.delete(recursive: true);
      } catch (_) {}
      rethrow;
    }
  }

  /// Tìm file .app trong thư mục extract (đệ quy 2 cấp)
  static Future<String?> _findAppBundle(String dir) async {
    final dirObj = Directory(dir);
    final entries = await dirObj.list().toList();

    for (final e in entries) {
      if (e is Directory && e.path.endsWith('.app')) {
        return e.path;
      }
    }

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
    final idx = exe.indexOf('.app/Contents/MacOS/');
    if (idx < 0) {
      throw Exception('Không xác định được vị trí app: $exe');
    }
    return exe.substring(0, idx + 4);
  }

  static String _shQuote(String s) => "'${s.replaceAll("'", "'\\''")}'";

  static String _buildUpdateScript({
    required String currentApp,
    required String newApp,
    required String workDirPath,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('#!/bin/bash');
    buffer.writeln('sleep 2');
    buffer.writeln('CURRENT=${_shQuote(currentApp)}');
    buffer.writeln('NEW=${_shQuote(newApp)}');
    buffer.writeln('WORK_DIR=${_shQuote(workDirPath)}');
    buffer.writeln('');
    buffer.writeln(
        'if rm -rf "\$CURRENT" 2>/dev/null && mv "\$NEW" "\$CURRENT" 2>/dev/null; then');
    buffer.writeln('    echo "✅ Update thành công (không cần admin)"');
    buffer.writeln('else');
    buffer.writeln('    osascript - "\$CURRENT" "\$NEW" <<\'EOF\'');
    buffer.writeln('on run argv');
    buffer.writeln('  set curApp to item 1 of argv');
    buffer.writeln('  set newApp to item 2 of argv');
    buffer.writeln(
        '  do shell script "rm -rf " & quoted form of curApp & " && mv " & quoted form of newApp & " " & quoted form of curApp with administrator privileges');
    buffer.writeln('end run');
    buffer.writeln('EOF');
    buffer.writeln('fi');
    buffer.writeln('');
    buffer.writeln('xattr -cr "\$CURRENT" 2>/dev/null');
    buffer.writeln('open "\$CURRENT"');
    buffer.writeln('rm -rf "\$WORK_DIR" 2>/dev/null');
    return buffer.toString();
  }
}
