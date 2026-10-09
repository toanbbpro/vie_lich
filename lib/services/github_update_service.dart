import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';

import 'macos_update_service.dart';

class GithubUpdateService {
  static const String _owner = 'toanbbpro';
  static const String _repo = 'vie_lich';

  static Future<void> checkUpdate(BuildContext context,
      {bool showNoUpdate = false}) async {
    const isPlayStore = bool.fromEnvironment('PLAY_STORE', defaultValue: false);
    if (isPlayStore) return;

    try {
      final dio = Dio();
      final response = await dio
          .get('https://api.github.com/repos/$_owner/$_repo/releases/latest');
      final data = response.data;

      final String tag = data['tag_name'];
      final String releaseNotes = data['body'] ?? 'Không có ghi chú phát hành.';
      final String releaseUrl = data['html_url'];

      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      if (_isNewer(currentVersion, tag)) {
        String? apkUrl;
        String? macOSZipUrl;

        if (Platform.isAndroid) {
          final assets = data['assets'] as List;
          for (var asset in assets) {
            if (asset['name'].toString().toLowerCase().endsWith('.apk')) {
              apkUrl = asset['browser_download_url'];
              break;
            }
          }
        } else if (Platform.isMacOS) {
          // Tìm file .zip trên GitHub release (chứa .app đã sign + notarize)
          final assets = data['assets'] as List;
          for (var asset in assets) {
            final name = asset['name'].toString().toLowerCase();
            if (name.endsWith('.zip') && name.contains('app')) {
              macOSZipUrl = asset['browser_download_url'];
              break;
            }
          }
        }

        if (!context.mounted) return;
        _hienThiDialogCapNhat(
          context,
          tag,
          releaseNotes,
          releaseUrl,
          apkUrl,
          macOSZipUrl,
          info.packageName,
        );
      } else if (showNoUpdate) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn đang dùng phiên bản mới nhất!')),
        );
      }
    } catch (e) {
      if (showNoUpdate && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi kiểm tra cập nhật: $e')),
        );
      }
    }
  }

  static bool _isNewer(String current, String tag) {
    try {
      final v1 = current.replaceAll(RegExp(r'[a-zA-Z]'), '').split('.');
      final v2 = tag.replaceAll(RegExp(r'[a-zA-Z]'), '').split('.');
      for (int i = 0; i < 3; i++) {
        final num1 = i < v1.length ? int.parse(v1[i]) : 0;
        final num2 = i < v2.length ? int.parse(v2[i]) : 0;
        if (num2 > num1) return true;
        if (num2 < num1) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static void _hienThiDialogCapNhat(
    BuildContext context,
    String version,
    String notes,
    String releaseUrl,
    String? apkUrl,
    String? macOSZipUrl,
    String packageName,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isDownloading = false;
        double progress = 0.0;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Có phiên bản mới: $version'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ghi chú phát hành:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: SingleChildScrollView(
                      child: Text(notes, style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                  if (isDownloading) ...[
                    const SizedBox(height: 24),
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 8),
                    Text('Đang tải: ${(progress * 100).toStringAsFixed(1)}%',
                        textAlign: TextAlign.center),
                  ],
                ],
              ),
              actions: [
                if (!isDownloading)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Để sau',
                        style: TextStyle(color: Colors.grey)),
                  ),
                if (!isDownloading)
                  FilledButton(
                    onPressed: () async {
                      // === Android: tải APK ===
                      if (Platform.isAndroid && apkUrl != null) {
                        setState(() => isDownloading = true);
                        await _taiVaCaiDatApk(apkUrl, packageName, (p) {
                          setState(() => progress = p);
                        });
                        if (context.mounted) Navigator.pop(context);
                      }
                      // === macOS: tải + tự cài ===
                      else if (Platform.isMacOS && macOSZipUrl != null) {
                        setState(() => isDownloading = true);
                        try {
                          await MacOSUpdateService.downloadAndInstall(
                            zipUrl: macOSZipUrl,
                            onProgress: (p) {
                              setState(() => progress = p);
                            },
                          );
                          // Không tới đây vì đã exit
                        } catch (e) {
                          if (context.mounted) {
                            setState(() => isDownloading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Lỗi cập nhật: $e')),
                            );
                          }
                        }
                      }
                      // === Fallback: mở trang release ===
                      else {
                        final uri = Uri.parse(releaseUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    child: Text(
                      Platform.isAndroid && apkUrl != null
                          ? 'Cập nhật ngay'
                          : Platform.isMacOS && macOSZipUrl != null
                              ? 'Cập nhật và khởi động lại'
                              : 'Tải bản cập nhật',
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  static Future<void> _taiVaCaiDatApk(
      String url, String appId, Function(double) onProgress) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/update.apk';

      final dio = Dio();
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );

      final result = await OpenFilex.open(savePath);
      debugPrint('Trạng thái mở file cài đặt: ${result.message}');
    } catch (e) {
      debugPrint('Lỗi tải APK: $e');
    }
  }
}