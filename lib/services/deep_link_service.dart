import 'dart:async';
import 'dart:convert';
import 'dart:io' show gzip;
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/su_kien.dart';
import '../providers/su_kien_provider.dart';
import 'widget_service.dart';
import '../main.dart';

class DeepLinkService {
  static final _appLinks = AppLinks();
  static bool _isInitialized = false;

  static void init() {
    if (_isInitialized) return;
    _isInitialized = true;

    debugPrint("📱 [DeepLink] Bắt đầu lắng nghe ngầm...");

    _appLinks.uriLinkStream.listen((Uri? uri) {
      debugPrint("🔗 [DeepLink] App được đánh thức, nhận Stream Link: $uri");
      if (uri != null) _xuLyUri(uri);
    }, onError: (err) {
      debugPrint("❌ [DeepLink] Lỗi Stream Link: $err");
    });

    _appLinks.getInitialLink().then((Uri? uri) {
      if (uri != null) {
        debugPrint("🔗 [DeepLink] App mở mới hoàn toàn bằng Link: $uri");
        _xuLyUri(uri);
      }
    });
  }

  static void _xuLyUri(Uri uri) {
    debugPrint("🔍 [DeepLink] Scheme: ${uri.scheme} | Host: ${uri.host}");
    if (uri.scheme == 'vielich' && uri.host == 'share') {
      final data = uri.queryParameters['data'];
      if (data != null) {
        _xuLyDuLieuShare(data);
      } else {
        debugPrint("⚠️ [DeepLink] Thiếu tham số data trong link!");
      }
    }
  }

  static String taoLinkChiaSe(SuKien sk) {
    final map = {
      'ten': sk.ten,
      'ngayAm': sk.ngayAm,
      'thangAm': sk.thangAm,
      'namAm': sk.namAm,
      'gioNhac': sk.gioNhac,
      'phutNhac': sk.phutNhac,
      'baoTruoc': sk.baoTruoc,
      'tag': sk.tag ?? 'event',
    };
    final jsonString = jsonEncode(map);
    final base64Data = base64UrlEncode(utf8.encode(jsonString));
    return 'vielich://share?data=$base64Data';
  }

  static void _xuLyDuLieuShare(String base64Data) {
    try {
      // 1. Chuẩn hóa base64 (thêm padding nếu thiếu)
      String normalized = base64Data;
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }

      // 2. Decode base64 — thử URL-safe trước, fallback base64 thường
      List<int> bytes;
      try {
        bytes = base64Url.decode(normalized);
      } catch (_) {
        bytes = base64.decode(normalized);
      }

      // 3. Thử gzip decode, fallback về bytes gốc
      String jsonString;
      try {
        final decompressed = gzip.decode(bytes);
        jsonString = utf8.decode(decompressed);
      } catch (_) {
        jsonString = utf8.decode(bytes);
      }

      // 4. Parse JSON — hỗ trợ cả array (multi) và object (single)
      final decoded = jsonDecode(jsonString);

      List<SuKien> dsSuKien;
      if (decoded is List) {
        dsSuKien = decoded
            .map((e) => SuKien.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (decoded is Map<String, dynamic>) {
        dsSuKien = [SuKien.fromJson(decoded)];
      } else {
        throw Exception('Định dạng JSON không hợp lệ');
      }

      if (dsSuKien.isEmpty) return;

      debugPrint("✅ [DeepLink] Giải mã thành công ${dsSuKien.length} sự kiện");
      _hienThiDialogXacNhan(dsSuKien);
    } catch (e) {
      debugPrint("❌ [DeepLink] Lỗi giải mã Base64/JSON: $e");
      _hienThiThongBaoLoi();
    }
  }

  static void _hienThiDialogXacNhan(List<SuKien> dsSuKien) async {
    BuildContext? context;

    for (int i = 0; i < 6; i++) {
      context = navigatorKey.currentContext;
      if (context != null && context.mounted) break;
      debugPrint("⏳ [DeepLink] UI chưa sẵn sàng, đang đợi 0.5s...");
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (context == null || !context.mounted) {
      debugPrint("❌ [DeepLink] Quá giờ, không tìm thấy UI!");
      return;
    }

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    final bool isMulti = dsSuKien.length > 1;
    final SuKien skDau = dsSuKien.first;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            isMulti
                ? 'Có người chia sẻ ${dsSuKien.length} lịch cho bạn!'
                : 'Có người chia sẻ lịch cho bạn!',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMulti) ...[
                  Text(
                    'Sự kiện: ${skDau.ten}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ngày âm: ${skDau.ngayAm}/${skDau.thangAm}'
                    '${skDau.namAm != null ? '/${skDau.namAm}' : ' (Hàng năm)'}',
                  ),
                  Text(
                    'Nhắc lúc: ${skDau.gioNhac.toString().padLeft(2, '0')}:'
                    '${skDau.phutNhac.toString().padLeft(2, '0')}',
                  ),
                ] else ...[
                  Text(
                    'Danh sách ${dsSuKien.length} sự kiện:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...dsSuKien.take(5).map(
                        (sk) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• ${sk.ten} (${sk.ngayAm}/${sk.thangAm} âm)',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                  if (dsSuKien.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '... và ${dsSuKien.length - 5} sự kiện khác',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Bỏ qua', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (ctx.mounted) {
                  final provider =
                      Provider.of<SuKienProvider>(ctx, listen: false);

                  // Tạo sự kiện MỚI với id mới để tránh ghi đè
                  for (final sk in dsSuKien) {
                    final skMoi = SuKien(
                      id: const Uuid().v4(),
                      ten: sk.ten,
                      ngayAm: sk.ngayAm,
                      thangAm: sk.thangAm,
                      namAm: sk.namAm,
                      ghiChu: sk.ghiChu,
                      duongDanAnh: null,
                      baoTruoc: sk.baoTruoc,
                      daXuatLich: false,
                      gioNhac: sk.gioNhac,
                      phutNhac: sk.phutNhac,
                      tag: sk.tag,
                    );
                    await provider.themSuKien(skMoi);
                  }

                  await WidgetService.capNhatWidget();

                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Đã thêm ${dsSuKien.length} sự kiện thành công!',
                        ),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(
                isMulti
                    ? 'Lưu tất cả ${dsSuKien.length} sự kiện'
                    : 'Lưu vào lịch của tôi',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  static void _hienThiThongBaoLoi() async {
    BuildContext? context;
    for (int i = 0; i < 6; i++) {
      context = navigatorKey.currentContext;
      if (context != null && context.mounted) break;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Mã liên kết sự kiện không hợp lệ hoặc bị hỏng!')),
      );
    }
  }
}
