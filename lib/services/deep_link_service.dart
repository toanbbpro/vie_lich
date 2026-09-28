import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // ĐÃ THÊM: Import Provider
import 'package:uuid/uuid.dart';

import '../models/su_kien.dart';
import '../providers/su_kien_provider.dart'; // ĐÃ THÊM: Import SuKienProvider
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
      String normalizedBase64 = base64Data;
      while (normalizedBase64.length % 4 != 0) {
        normalizedBase64 += '=';
      }

      final jsonString = utf8.decode(base64Url.decode(normalizedBase64));
      final map = jsonDecode(jsonString);

      final skDuocShare = SuKien(
        id: const Uuid().v4(),
        ten: map['ten'],
        ngayAm: map['ngayAm'],
        thangAm: map['thangAm'],
        namAm: map['namAm'],
        gioNhac: map['gioNhac'],
        phutNhac: map['phutNhac'],
        baoTruoc: map['baoTruoc'],
        tag: map['tag'],
      );

      debugPrint("✅ [DeepLink] Đã dịch mã sự kiện: ${skDuocShare.ten}");
      _hienThiDialogXacNhan(skDuocShare);
    } catch (e) {
      debugPrint("❌ [DeepLink] Lỗi giải mã Base64/JSON: $e");
      _hienThiThongBaoLoi();
    }
  }

  static void _hienThiDialogXacNhan(SuKien sk) async {
    BuildContext? context;
    
    for (int i = 0; i < 6; i++) {
      context = navigatorKey.currentContext;
      if (context != null && context.mounted) break;
      debugPrint("⏳ [DeepLink] UI chưa sẵn sàng, đang đợi 0.5s...");
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (context == null || !context.mounted) {
      debugPrint("❌ [DeepLink] Quá giờ (Timeout), không tìm thấy giao diện để hiện Popup!");
      return;
    }

    if (Navigator.canPop(context)) {
      Navigator.pop(context); 
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Có người chia sẻ lịch cho bạn!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sự kiện: ${sk.ten}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text('Ngày âm: ${sk.ngayAm}/${sk.thangAm}${sk.namAm != null ? '/${sk.namAm}' : ' (Hàng năm)'}'),
              Text('Nhắc lúc: ${sk.gioNhac.toString().padLeft(2, '0')}:${sk.phutNhac.toString().padLeft(2, '0')}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Bỏ qua', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (ctx.mounted) {
                  // ĐÃ SỬA: Thay thế logic cũ bằng lệnh gọi SuKienProvider
                  // Provider sẽ tự động lo việc lưu Hive, lên lịch thông báo và cập nhật UI ngay lập tức
                  await Provider.of<SuKienProvider>(ctx, listen: false).themSuKien(sk);
                  
                  // Chỉ cần cập nhật thêm Widget ngoài Desktop/Màn hình chính
                  await WidgetService.capNhatWidget();
                  
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Đã thêm sự kiện thành công!')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Lưu vào lịch của tôi', style: TextStyle(color: Colors.white)),
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
        const SnackBar(content: Text('Mã liên kết sự kiện không hợp lệ hoặc bị hỏng!')),
      );
    }
  }
}