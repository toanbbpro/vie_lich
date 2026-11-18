import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Service tự động cập nhật app trên Linux từ GitHub Release.
///
/// Yêu cầu / Bảo mật:
/// - Tải và giải nén trong thư mục riêng của user (`ApplicationSupport/updates`, quyền 0700),
///   tránh dùng `/tmp` dùng chung trên hệ thống multi-user.
/// - Kiểm tra SHA-256 (nếu Release có `digest`) trước khi chạy `pkexec` hoặc giải nén.
/// - Truyền đường dẫn qua positional args thay vì nội suy chuỗi shell.
class LinuxUpdateService {
  static Future<void> _verifySha256IfPresent(
    String filePath,
    String? expectedDigest,
  ) async {
    if (expectedDigest == null || !expectedDigest.startsWith('sha256:')) return;
    final expectedHex = expectedDigest.substring(7).trim().toLowerCase();
    final res = await Process.run('sha256sum', [filePath]);
    if (res.exitCode != 0) {
      throw Exception('Không thể kiểm tra SHA-256: ${res.stderr}');
    }
    final actualHex =
        res.stdout.toString().trim().split(RegExp(r'\s+')).first.toLowerCase();
    if (actualHex != expectedHex) {
      throw Exception('Tệp cập nhật không khớp chữ ký SHA-256!');
    }
  }

  /// Tạo thư mục staging riêng tư (0700) thuộc user hiện tại thay cho /tmp
  static Future<Directory> _preparePrivateWorkDir() async {
    final appSupport = await getApplicationSupportDirectory();
    final updatesRoot = Directory('${appSupport.path}/updates');
    if (!await updatesRoot.exists()) {
      await updatesRoot.create(recursive: true);
    }
    await Process.run('chmod', ['700', updatesRoot.path]);

    for (final entity in updatesRoot.listSync()) {
      try {
        await entity.delete(recursive: true);
      } catch (_) {}
    }
    final workDir = await updatesRoot.createTemp('run_');
    await Process.run('chmod', ['700', workDir.path]);
    return workDir;
  }

  /// Download gói cập nhật, kiểm tra hash, cài đặt/thay thế app hiện tại, rồi tự relaunch.
  static Future<void> downloadAndInstall({
    required String archiveUrl,
    required Function(double) onProgress,
    String? expectedDigest,
  }) async {
    final workDir = await _preparePrivateWorkDir();
    final lowerUrl = archiveUrl.toLowerCase();
    final isDeb = lowerUrl.endsWith('.deb');
    final isTarGz = lowerUrl.endsWith('.tar.gz') || lowerUrl.endsWith('.tgz');
    final ext = isDeb
        ? 'deb'
        : isTarGz
            ? 'tar.gz'
            : 'zip';
    final archivePath = '${workDir.path}/vie_lich_update.$ext';
    final extractDir = '${workDir.path}/extract';
    await Directory(extractDir).create(recursive: true);

    try {
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

      // 2. Đối chiếu SHA-256 trước khi giải nén hoặc cấp quyền root
      await _verifySha256IfPresent(archivePath, expectedDigest);

      final currentExe = Platform.resolvedExecutable;
      final currentBundleDir = File(currentExe).parent.path;
      final isSystemInstall = currentBundleDir.startsWith('/opt') ||
          currentBundleDir.startsWith('/usr');

      // 3. Gói .deb ở hệ thống (/opt hoặc /usr): dùng pkexec + positional arg ($1)
      if (isDeb && isSystemInstall) {
        debugPrint('📦 Cài đặt gói .deb hệ thống qua pkexec...');
        final result = await Process.run('pkexec', [
          'bash',
          '-c',
          'dpkg -i "\$1" || (apt-get install -f -y && dpkg -i "\$1")',
          '_',
          archivePath,
        ]);

        if (result.exitCode != 0) {
          throw Exception(
            'Không thể cài đặt bản cập nhật (mã ${result.exitCode}): ${result.stderr}',
          );
        }

        try {
          await workDir.delete(recursive: true);
        } catch (_) {}

        final targetExe = await File('/opt/vie_lich/vie_lich').exists()
            ? '/opt/vie_lich/vie_lich'
            : currentExe;

        await Process.start(
          '/bin/bash',
          ['-c', 'sleep 1 && nohup "\$1" >/dev/null 2>&1 &', '_', targetExe],
          mode: ProcessStartMode.detached,
        );
        await Future.delayed(const Duration(milliseconds: 300));
        exit(0);
      }

      // 4. Giải nén (.deb portable, .tar.gz, hoặc .zip)
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

      // 5. Tìm thư mục bundle trong thư mục extract
      final newBundleDir = await _findBundleDir(extractDir);
      if (newBundleDir == null) {
        throw Exception(
            'Không tìm thấy bộ cài VIE Lịch hợp lệ trong gói tải về');
      }
      debugPrint('✅ Tìm thấy bundle mới: $newBundleDir');

      // 6. Tạo shell script với tham số thoát chuỗi an toàn (không nội suy trực tiếp)
      final scriptPath = '${workDir.path}/vie_lich_update.sh';
      final script = _buildUpdateScript(
        currentDir: currentBundleDir,
        currentExe: currentExe,
        newDir: newBundleDir,
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

      await Future.delayed(const Duration(milliseconds: 300));
      exit(0);
    } catch (e) {
      try {
        await workDir.delete(recursive: true);
      } catch (_) {}
      rethrow;
    }
  }

  /// Tìm thư mục chứa executable `vie_lich` và thư mục `data` (tối đa 3 cấp)
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

  static String _shQuote(String s) => "'${s.replaceAll("'", "'\\''")}'";

  static String _buildUpdateScript({
    required String currentDir,
    required String currentExe,
    required String newDir,
    required String workDirPath,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('#!/bin/bash');
    buffer.writeln('sleep 2');
    buffer.writeln('CURRENT_DIR=${_shQuote(currentDir)}');
    buffer.writeln('CURRENT_EXE=${_shQuote(currentExe)}');
    buffer.writeln('NEW_DIR=${_shQuote(newDir)}');
    buffer.writeln('WORK_DIR=${_shQuote(workDirPath)}');
    buffer.writeln('');
    buffer.writeln('chmod +x "\$NEW_DIR/vie_lich" 2>/dev/null');
    buffer.writeln(
        'if [ -w "\$CURRENT_DIR" ] && cp -rf "\$NEW_DIR"/* "\$CURRENT_DIR"/ 2>/dev/null; then');
    buffer.writeln('    chmod +x "\$CURRENT_EXE" 2>/dev/null');
    buffer.writeln('else');
    buffer.writeln('    if command -v pkexec >/dev/null 2>&1; then');
    buffer.writeln(
        '        pkexec bash -c \'cp -rf "\$1"/* "\$2"/ && chmod +x "\$3"\' _ "\$NEW_DIR" "\$CURRENT_DIR" "\$CURRENT_EXE"');
    buffer.writeln('    fi');
    buffer.writeln('fi');
    buffer.writeln('nohup "\$CURRENT_EXE" >/dev/null 2>&1 &');
    buffer.writeln('rm -rf "\$WORK_DIR" 2>/dev/null');
    return buffer.toString();
  }
}
