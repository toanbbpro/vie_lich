import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/su_kien.dart';

class QrShareScreen extends StatelessWidget {
  final String qrData;
  final String shareLink;
  final List<SuKien> dsSuKien;

  const QrShareScreen({
    super.key,
    required this.qrData,
    required this.shareLink,
    required this.dsSuKien,
  });

  Future<void> _shareLink(BuildContext context) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              'Tham gia ${dsSuKien.length} nhắc lịch âm lịch trên VIE Lịch:\n\n$shareLink',
          subject: 'Chia sẻ nhắc lịch âm lịch',
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không mở được chia sẻ: $e')),
      );
    }
  }

  void _copyLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: shareLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã copy link'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chia sẻ nhắc lịch'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Chia sẻ',
            onPressed: () => _shareLink(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Đưa máy khác vào quét mã này để nhận:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),

            // === QR CODE ===
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: 250,
                  height: 250,
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    errorCorrectionLevel: QrErrorCorrectLevel.L,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            Center(
              child: Text(
                'Gồm ${dsSuKien.length} sự kiện',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // === LINK + NÚT COPY ===
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.link, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'LINK CHIA SẺ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    shareLink,
                    style: const TextStyle(fontSize: 12, height: 1.4),
                    maxLines: 6,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _copyLink(context),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy link'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Lưu ý: Người nhận cần cài VIE Lịch để mở link này. '
              'Hoặc dùng chức năng "Quét mã QR" trong app để nhận nhanh hơn.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
