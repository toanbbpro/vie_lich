import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

class WindowsUpdateService {
  static const String _githubApiUrl =
      'https://api.github.com/repos/toanbbpro/vie_lich/releases/latest';

  static const String _exeName = 'vie_lich.exe';

  /// Format version để hiển thị — ẩn `+0` khi không có build
  static String _formatVersion(String version, int build) {
    return version;
  }

  /// Entry point — gọi từ UI button
  static Future<void> checkUpdate(
    BuildContext context, {
    bool showNoUpdate = false,
    bool respectSkip = true,
  }) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version; // "2.0.0"
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;

      debugPrint('🔍 [WinUpd] Current: $currentVersion+$currentBuild');

      final dio = Dio();
      final res = await dio.get(_githubApiUrl);
      if (res.statusCode != 200) {
        throw Exception('GitHub API trả về ${res.statusCode}');
      }

      final data = res.data as Map<String, dynamic>;
      final tagName = data['tag_name'] as String? ?? '';
      final changelog = data['body'] as String? ?? '';

      final parsed = _parseTag(tagName);
      if (parsed == null) {
        throw Exception('Tag không hợp lệ: $tagName');
      }
      final (remoteVersion, remoteBuild) = parsed;

      final hasUpdate = _isNewer(
        remoteVersion, remoteBuild, currentVersion, currentBuild,
      );

      // Xoá skip nếu đã update lên bản mới
      await _clearSkipIfOutdated(currentVersion);

      // Kiểm tra skip — CHỈ khi respectSkip = true (auto-check)
      if (respectSkip) {
        final skipVersion = await _getSkipVersion();
        if (skipVersion != null) {
          final parsedSkip = _parseTag(skipVersion);
          if (parsedSkip != null) {
            final (skipVer, skipBuild) = parsedSkip;
            if (!_isNewer(remoteVersion, remoteBuild, skipVer, skipBuild)) {
              debugPrint(
                  '⏭️ [WinUpd] Skip version $skipVersion (user đã chọn bỏ qua)');
              return;   // Không hiện dialog, không cần showNoUpdate
            }
          }
        }
      } else {
        debugPrint('🔔 [WinUpd] Manual check — bỏ qua skip setting');
      }

      if (!hasUpdate) {
        if (showNoUpdate && context.mounted) {
          _simpleDialog(
            context,
            'Bạn đang dùng bản mới nhất',
            'Phiên bản hiện tại: $currentVersion+$currentBuild',
          );
        }
        return;
      }

      // Tìm asset windows .zip
      final assets = data['assets'] as List? ?? [];
      Map<String, dynamic>? asset;
      for (final a in assets) {
        final name = (a['name'] as String? ?? '').toLowerCase();
        if (name.contains('windows') && name.endsWith('.zip')) {
          asset = a as Map<String, dynamic>;
          break;
        }
      }
      if (asset == null) {
        throw Exception('Không có file .zip Windows trong release');
      }

      final downloadUrl = asset['browser_download_url'] as String;
      final fileSize = asset['size'] as int? ?? 0;

      if (!context.mounted) return;
      final ok = await _confirmDialog(
        context,
        currentVersion: currentVersion,
        currentBuild: currentBuild,
        remoteVersion: remoteVersion,
        remoteBuild: remoteBuild,
        changelog: changelog,
        fileSizeBytes: fileSize,
      );

      if (ok != true) return;
      if (!context.mounted) return;

      await _downloadAndInstall(context, downloadUrl);
    } catch (e) {
      debugPrint('❌ [WinUpd] Lỗi: $e');
      if (showNoUpdate && context.mounted) {
        _simpleDialog(context, 'Lỗi kiểm tra cập nhật', '$e');
      }
    }
  }

  // ============================================================
  // PARSING + VERSION
  // ============================================================

  static (String, int)? _parseTag(String tag) {
    var t = tag.trim();
    if (t.startsWith('v') || t.startsWith('V')) t = t.substring(1);
    if (t.isEmpty) return null;
    if (t.contains('+')) {
      final p = t.split('+');
      return (p[0], int.tryParse(p[1]) ?? 0);
    }
    return (t, 0);
  }

  static bool _isNewer(
    String remoteVer,
    int remoteBuild,
    String currentVer,
    int currentBuild,
  ) {
    final r = remoteVer.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final c = currentVer.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    while (r.length < c.length) {
      r.add(0);
    }
    while (c.length < r.length) {
      c.add(0);
    }
    for (var i = 0; i < r.length; i++) {
      if (r[i] > c[i]) return true;
      if (r[i] < c[i]) return false;
    }
    return remoteBuild > currentBuild;
  }

  // ============================================================
  // DIALOGS
  // ============================================================

    static Future<bool?> _confirmDialog(
    BuildContext context, {
    required String currentVersion,
    required int currentBuild,
    required String remoteVersion,
    required int remoteBuild,
    required String changelog,
    required int fileSizeBytes,
      }) async {
        final sizeMB = (fileSizeBytes / 1024 / 1024).toStringAsFixed(1);
        final shortLog = changelog.length > 600
            ? '${changelog.substring(0, 600)}...'
            : changelog;

        // State cho checkbox
        bool dontRemind = false;

        final result = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => StatefulBuilder(
            builder: (builderCtx, setState) => AlertDialog(
              title: const Text('Có bản cập nhật mới'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                   Text(
                    'Hiện tại: ${_formatVersion(currentVersion, currentBuild)}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  Text(
                    'Bản mới: ${_formatVersion(remoteVersion, remoteBuild)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                    Text(
                      'Kích thước: ~$sizeMB MB',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (shortLog.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'Có gì mới:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(shortLog, style: const TextStyle(fontSize: 12)),
                    ],
                    const SizedBox(height: 12),
                    const Divider(),
                    // 👇 Checkbox "Không nhắc lại"
                    InkWell(
                      onTap: () => setState(() => dontRemind = !dontRemind),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Checkbox(
                              value: dontRemind,
                              onChanged: (v) =>
                                  setState(() => dontRemind = v ?? false),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Không nhắc cập nhật bản này',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'App sẽ tự tải, khởi động lại và cập nhật.',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Để sau'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  child: const Text('Cập nhật ngay'),
                ),
              ],
            ),
          ),
        );

        if (result == false && dontRemind) {
          final skipVer = _formatVersion(remoteVersion, remoteBuild);
          await _setSkipVersion(skipVer);
          debugPrint('⏭️ [WinUpd] Đã lưu skip version: $skipVer');
        }

        return result;
      }

  static void _simpleDialog(
    BuildContext context,
    String title,
    String content,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DOWNLOAD + INSTALL
  // ============================================================

  static Future<void> _downloadAndInstall(
    BuildContext context,
    String downloadUrl,
  ) async {
    final progress = ValueNotifier<double>(0);

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProgressDialog(progress: progress),
    );

    try {
      // Chuẩn bị thư mục temp
      final tempRoot = Directory.systemTemp.path;
      final workDir = Directory('$tempRoot\\vie_lich_update');
      if (await workDir.exists()) {
        await workDir.delete(recursive: true);
      }
      await workDir.create(recursive: true);

      final zipPath = '${workDir.path}\\update.zip';
      final extractPath = '${workDir.path}\\extracted';

      // Download
      debugPrint('⬇️ [WinUpd] Download: $downloadUrl');
      final dio = Dio();
      await dio.download(
        downloadUrl,
        zipPath,
        onReceiveProgress: (recv, total) {
          if (total > 0) progress.value = (recv / total) * 0.7;
        },
      );
      debugPrint('✅ [WinUpd] Downloaded');

      // Extract
      debugPrint('📦 [WinUpd] Extracting...');
      final extractDir = Directory(extractPath);
      await extractDir.create(recursive: true);

      // 👇 SỬA: dùng extractFileToDisk thay vì extractZip
      await extractFileToDisk(zipPath, extractPath);

      progress.value = 0.9;
      debugPrint('✅ [WinUpd] Extracted');

      // Tìm thư mục thật chứa .exe (phòng khi zip có subfolder)
      final realSrc = await _findExeDir(extractPath);
      if (realSrc == null) {
        throw Exception('Không tìm thấy $_exeName trong file zip');
      }

      // Tạo batch script
      final appDir = File(Platform.resolvedExecutable).parent.path;
      final batchPath = '$tempRoot\\vie_lich_update.bat';
      await File(batchPath).writeAsString(_batchTemplate);

      progress.value = 1.0;
      await Future.delayed(const Duration(milliseconds: 600));

      // Spawn batch (detached) với args
      debugPrint('🚀 [WinUpd] Spawning batch...');
      await Process.start(
        'cmd',
        [
          '/c',
          batchPath,
          realSrc,
          appDir,
          _exeName,
        ],
        mode: ProcessStartMode.detached,
        runInShell: true,
      );

      // Cho batch 800ms để start, rồi exit app
      await Future.delayed(const Duration(milliseconds: 800));
      debugPrint('👋 [WinUpd] Exiting app for update');
      exit(0);
    } catch (e) {
      debugPrint('❌ [WinUpd] Lỗi update: $e');
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _simpleDialog(context, 'Cập nhật thất bại', '$e');
      }
    }
  }

  /// Tìm thư mục chứa .exe trong extract path
  static Future<String?> _findExeDir(String extractPath) async {
    final dir = Directory(extractPath);

    // Case 1: .exe ngay trong extractPath
    await for (final e in dir.list()) {
      if (e is File && e.path.toLowerCase().endsWith(_exeName)) {
        return extractPath;
      }
    }

    // Case 2: .exe trong subfolder (1 cấp)
    await for (final e in dir.list()) {
      if (e is Directory) {
        await for (final s in e.list()) {
          if (s is File && s.path.toLowerCase().endsWith(_exeName)) {
            return e.path;
          }
        }
      }
    }

    return null;
  }

   // ============================================================
  // SKIP VERSION — không nhắc lại bản này
  // ============================================================
  static const String _prefSkipVersion = 'skip_update_version';

  static Future<String?> _getSkipVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefSkipVersion);
  }

  static Future<void> _setSkipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefSkipVersion, version);
  }

  /// Xoá skip nếu user đã update lên bản mới hơn
  static Future<void> _clearSkipIfOutdated(String currentVersion) async {
    final skip = await _getSkipVersion();
    if (skip == null) return;
    // Nếu version hiện tại >= skip version → đã update → xoá
    final parsed = _parseTag(skip);
    if (parsed == null) return;
    final (skipVer, skipBuild) = parsed;
    final info = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(info.buildNumber) ?? 0;

    if (!_isNewer(skipVer, skipBuild, currentVersion, currentBuild)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefSkipVersion);
    }
  }

  // ============================================================
  // BATCH TEMPLATE
  // Args: %1 = source dir, %2 = dest dir, %3 = exe name
  // ============================================================
  static const String _batchTemplate = r'''
@echo off
chcp 65001 >nul
title VIE Lich Update

set "SRC=%~1"
set "DST=%~2"
set "EXE=%~3"

timeout /t 2 /nobreak >nul

:waitloop
tasklist /FI "IMAGENAME eq %EXE%" 2>NUL | find /I "%EXE%" >NUL
if not errorlevel 1 (
    timeout /t 1 /nobreak >nul
    goto waitloop
)

xcopy /Y /E /I /Q "%SRC%\*" "%DST%\"

if errorlevel 1 (
    echo.
    echo LOI: Khong the ghi de file.
    echo Vui long chay app voi quyen Admin.
    pause
    exit /b 1
)

:: Detach app hoan toan khoi cmd
powershell -NoProfile -WindowStyle Hidden -Command "Start-Process -FilePath '%DST%\%EXE%' -WorkingDirectory '%DST%'"

timeout /t 3 /nobreak >nul

:: Xoa thu muc temp (SRC\.. = parent cua extracted)
rmdir /S /Q "%SRC%\.." 2>nul

:: Tu xoa batch
(goto) 2>nul & del "%~f0"
''';
}

// ============================================================
// PROGRESS DIALOG
// ============================================================
class _ProgressDialog extends StatelessWidget {
  final ValueNotifier<double> progress;
  const _ProgressDialog({required this.progress});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đang tải bản cập nhật'),
      content: ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (_, v, __) {
          final pct = (v * 100).toStringAsFixed(0);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: v),
              const SizedBox(height: 12),
              Text('$pct%'),
            ],
          );
        },
      ),
    );
  }
}