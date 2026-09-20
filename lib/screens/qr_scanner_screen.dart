import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends StatelessWidget {
  const QrScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét mã nhận lịch'),
        centerTitle: true,
      ),
      body: MobileScanner(
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            final rawValue = barcode.rawValue;
            if (rawValue != null && rawValue.startsWith('VL_QR:')) {
              // Nếu đúng mã của Vie Lịch, trả kết quả về màn hình trước
              Navigator.pop(context, rawValue);
              return;
            }
          }
        },
      ),
    );
  }
}