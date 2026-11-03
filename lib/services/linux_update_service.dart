import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Service tự động cập nhật app trên Linux từ GitHub Release.
///
/// Yêu cầu:
/// - GitHub release có file `.zip` hoặc `.tar.gz` dành cho Linux chứa thư mục bundle hoặc file thực thi `vie_lich`
/// - Hoặc người dùng có quyền ghi vào thư mục cài đặt (hoặc cấp quyền qua pkexec)
///
/// Flow:
/// 1. Download file nén từ GitHub
/// 2. Giải nén ra thư mục tạm
/// 3. Tìm thư mục bundle mới (chứa binary `vie_lich` và thư mục `data`, `lib`)
/// 4. Tạo shell script: đợi app thoát → ghi đè thư mục cài đặt → khởi chạy lại app
/// 5. Spawn script detached → app thoát
class LinuxUpdateService {
  /// Download gói cập nhật, giải nén, thay thế app hiện tại, rồi tự relaunch.
  static Future<void> downloadAndInstall({
    required String archiveUrl,
    required Function(double) onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final isTarGz = archiveUrl.toLowerCase().endsWith('.tar.gz') ||
        archiveUrl.toLowerCase().endsWith('.tgz');
    final ext = isTarGz ? 'tar.gz' : 'zip';
    final archivePath = '${tempDir.path}/vie_lich_update.$ext';
    final extractDir = '${tempDir.path}/vie_lich_extract';

    // Xóa thư mục extract cũ nếu có
    final extractDirObj = Directory(extractDir);
    if (await extractDirObj.exists()) {
      await extractDirObj.delete(recursive: true);
    }
    await extractDirObj.create(recursive: true);

    // 1. Download archive
    debugPrint('⬇️ Download Linux update: $archiveUrl');
    final dio = Dio();
    await dio.download(
      archiveUrl,
      archivePath,
      onReceiveProgress: (received, total) {
        if (total != -1) onProgress(received / total);
      },
    );

    // 2. Giải nén
    debugPrint('📦 Extracting...');
    ProcessResult extractResult;
    if (isTarGz) {
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

    // 3. Tìm thư mục bundle trong thư mục extract
    final newBundleDir = await _findBundleDir(extractDir);
    if (newBundleDir == null) {
      throw Exception('Không tìm thấy bộ cài VIE Lịch hợp lệ trong file nén');
    }
    debugPrint('✅ Tìm thấy bundle mới: $newBundleDir');

    // 4. Xác định vị trí app hiện tại
    final currentExe = Platform.resolvedExecutable;
    final currentBundleDir = File(currentExe).parent.path;
    debugPrint('📍 Thư mục app hiện tại: $currentBundleDir');

    // 5. Tạo shell script
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

  /// Tìm thư mục chứa executable `vie_lich` và thư mục `lib` / `data`
  static Future<String?> _findBundleDir(String dir) async {
    final dirObj = Directory(dir);
    if (await _isValidBundle(dirObj)) {
      return dirObj.path;
    }

    final entries = await dirObj.list().toList();
    for (final e in entries) {
      if (e is Directory) {
        if (await _isValidBundle(e)) {
          return e.path;
        }
        final subEntries = await e.list().toList();
        for (final se in subEntries) {
          if (se is Directory && await _isValidBundle(se)) {
            return se.path;
          }
        }
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
    buffer.writeln('if cp -rf "\$NEW_DIR"/* "\$CURRENT_DIR"/ 2>/dev/null; then');
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

