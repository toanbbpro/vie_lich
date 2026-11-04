import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Service tự động cập nhật app trên Linux từ GitHub Release.
///
/// Hỗ trợ:
/// - Gói `.deb` (ưu tiên): cài đặt qua `pkexec dpkg -i` (nếu app cài ở `/opt` hoặc `/usr`)
///   hoặc giải nén bằng `dpkg-deb -x` (nếu chạy bản portable trong thư mục user).
/// - Gói `.tar.gz` / `.tgz` / `.zip`: giải nén và ghi đè thư mục cài đặt (có hỗ trợ `pkexec`).
class LinuxUpdateService {
  /// Download gói cập nhật, cài đặt/thay thế app hiện tại, rồi tự relaunch.
  static Future<void> downloadAndInstall({
    required String archiveUrl,
    required Function(double) onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final lowerUrl = archiveUrl.toLowerCase();
    final isDeb = lowerUrl.endsWith('.deb');
    final isTarGz = lowerUrl.endsWith('.tar.gz') || lowerUrl.endsWith('.tgz');
    final ext = isDeb
        ? 'deb'
        : isTarGz
            ? 'tar.gz'
            : 'zip';
    final archivePath = '${tempDir.path}/vie_lich_update.$ext';
    final extractDir = '${tempDir.path}/vie_lich_extract';

    // Xóa thư mục extract cũ nếu có
    final extractDirObj = Directory(extractDir);
    if (await extractDirObj.exists()) {
      await extractDirObj.delete(recursive: true);
    }
    await extractDirObj.create(recursive: true);

    // 1. Download gói cập nhật
    debugPrint('⬇️ Download Linux update: $archiveUrl');
    final dio = Dio();
    await dio.download(
      archiveUrl,
      archivePath,
      onReceiveProgress: (received, total) {
        if (total != -1) onProgress(received / total);
      },
    );

    final currentExe = Platform.resolvedExecutable;
    final currentBundleDir = File(currentExe).parent.path;
    final isSystemInstall = currentBundleDir.startsWith('/opt') ||
        currentBundleDir.startsWith('/usr');

    // 2. Nếu là file .deb và app đang được cài ở hệ thống (/opt hoặc /usr):
    // Dùng pkexec dpkg -i ngay khi app đang mở để hiện khung nhập mật khẩu Polkit chuẩn,
    // sau đó khởi động lại app.
    if (isDeb && isSystemInstall) {
      debugPrint('📦 Cài đặt gói .deb hệ thống qua pkexec...');
      final result = await Process.run('pkexec', [
        'bash',
        '-c',
        'dpkg -i "$archivePath" || (apt-get install -f -y && dpkg -i "$archivePath")',
      ]);

      if (result.exitCode != 0) {
        throw Exception(
          'Không thể cài đặt bản cập nhật (mã ${result.exitCode}): ${result.stderr}',
        );
      }

      try {
        await File(archivePath).delete();
      } catch (_) {}

      final targetExe =
          await File('/opt/vie_lich/vie_lich').exists() ? '/opt/vie_lich/vie_lich' : currentExe;

      await Process.start(
        '/bin/bash',
        ['-c', 'sleep 1 && nohup "$targetExe" >/dev/null 2>&1 &'],
        mode: ProcessStartMode.detached,
      );
      await Future.delayed(const Duration(milliseconds: 300));
      exit(0);
    }

    // 3. Giải nén (.deb portable, .tar.gz, hoặc .zip)
    debugPrint('📦 Extracting...');
    ProcessResult extractResult;
    if (isDeb) {
      extractResult = await Process.run('dpkg-deb', [
        '-x',
        archivePath,
        extractDir,
      ]);
    } else if (isTarGz) {
      extractResult = await Process.run('tar', [
        '-xzf',
        archivePath,
        '-C',
        extractDir,
      ]);
    } else {
      extractResult = await Process.run('unzip', [
        '-q',
        '-o',
        archivePath,
        '-d',
        extractDir,
      ]);
    }

    if (extractResult.exitCode != 0) {
      throw Exception('Giải nén thất bại: ${extractResult.stderr}');
    }

    // 4. Tìm thư mục bundle trong thư mục extract
    final newBundleDir = await _findBundleDir(extractDir);
    if (newBundleDir == null) {
      throw Exception('Không tìm thấy bộ cài VIE Lịch hợp lệ trong gói tải về');
    }
    debugPrint('✅ Tìm thấy bundle mới: $newBundleDir');
    debugPrint('📍 Thư mục app hiện tại: $currentBundleDir');

    // 5. Tạo shell script cập nhật và khởi chạy lại
    final scriptPath = '${tempDir.path}/vie_lich_update.sh';
    final script = _buildUpdateScript(
      currentDir: currentBundleDir,
      currentExe: currentExe,
      newDir: newBundleDir,
      archivePath: archivePath,
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

  /// Tìm thư mục chứa executable `vie_lich` và thư mục `lib` / `data` (tối đa 3 cấp, bao gồm `opt/vie_lich`)
  static Future<String?> _findBundleDir(String dir, {int depth = 0}) async {
    if (depth > 3) return null;
    final dirObj = Directory(dir);
    if (await _isValidBundle(dirObj)) {
      return dirObj.path;
    }

    final entries = await dirObj.list().toList();
    for (final e in entries) {
      if (e is Directory) {
        final found = await _findBundleDir(e.path, depth: depth + 1);
        if (found != null) return found;
      }
    }
    return null;
  }

  static Future<bool> _isValidBundle(Directory dir) async {
    final exe = File('${dir.path}/vie_lich');
    final dataDir = Directory('${dir.path}/data');
    return await exe.exists() && await dataDir.exists();
  }

  static String _buildUpdateScript({
    required String currentDir,
    required String currentExe,
    required String newDir,
    required String archivePath,
    required String extractDir,
    required String scriptPath,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('#!/bin/bash');
    buffer.writeln('# Auto-update script cho VIE Lịch (Linux)');
    buffer.writeln('');
    buffer.writeln('sleep 2');
    buffer.writeln('');
    buffer.writeln('CURRENT_DIR="$currentDir"');
    buffer.writeln('CURRENT_EXE="$currentExe"');
    buffer.writeln('NEW_DIR="$newDir"');
    buffer.writeln('ARCHIVE="$archivePath"');
    buffer.writeln('EXTRACT="$extractDir"');
    buffer.writeln('SCRIPT="$scriptPath"');
    buffer.writeln('');
    buffer.writeln('chmod +x "\$NEW_DIR/vie_lich" 2>/dev/null');
    buffer.writeln('');
    buffer.writeln('# Thử copy trực tiếp nếu user có quyền ghi');
    buffer.writeln('if [ -w "\$CURRENT_DIR" ] && cp -rf "\$NEW_DIR"/* "\$CURRENT_DIR"/ 2>/dev/null; then');
    buffer.writeln('    chmod +x "\$CURRENT_EXE" 2>/dev/null');
    buffer.writeln('    echo "✅ Update thành công (không cần root)"');
    buffer.writeln('else');
    buffer.writeln('    echo "🔐 Cần quyền root để cập nhật ứng dụng..."');
    buffer.writeln('    if command -v pkexec >/dev/null 2>&1; then');
    buffer.writeln('        pkexec bash -c "cp -rf \'\$NEW_DIR\'/* \'\$CURRENT_DIR\'/ && chmod +x \'\$CURRENT_EXE\'"');
    buffer.writeln('    fi');
    buffer.writeln('fi');
    buffer.writeln('');
    buffer.writeln('# Mở lại ứng dụng');
    buffer.writeln('nohup "\$CURRENT_EXE" >/dev/null 2>&1 &');
    buffer.writeln('');
    buffer.writeln('# Cleanup');
    buffer.writeln('rm -rf "\$ARCHIVE" 2>/dev/null');
    buffer.writeln('rm -rf "\$EXTRACT" 2>/dev/null');
    buffer.writeln('rm -f "\$SCRIPT" 2>/dev/null');
    buffer.writeln('');
    return buffer.toString();
  }
}
