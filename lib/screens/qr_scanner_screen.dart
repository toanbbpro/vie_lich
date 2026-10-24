import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final MobileScannerController _cameraController = MobileScannerController();
  bool _isProcessing = false; // Cờ chặn quét liên tục

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  void _handleDetection(BarcodeCapture capture) async {
    if (_isProcessing) return; // Nếu đang xử lý thì bỏ qua

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null) continue;

      if (rawValue.startsWith('VL_QR:')) {
        // 1. Mã QR hợp lệ
        _isProcessing = true;
        // Rung nhẹ (tùy chọn, cần import 'package:flutter/services.dart';)
        // HapticFeedback.mediumImpact();
        if (mounted) Navigator.pop(context, rawValue);
        return;
      } else {
        // 2. Mã QR lạ
        _isProcessing = true;
        _cameraController.stop(); // Tạm dừng camera
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mã QR không hợp lệ. Vui lòng quét mã của VIE Lịch.'),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Đợi 2 giây rồi cho phép quét lại
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          _cameraController.start();
          _isProcessing = false;
        }
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Quét mã nhận lịch',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent, // Trong suốt để thấy camera
        elevation: 0,
        // Ép icon và text sang màu trắng
        iconTheme: const IconThemeData(color: Colors.white),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _cameraController.toggleTorch(),
          ),
        ],
      ),
      extendBodyBehindAppBar: true, // Cho phép camera tràn lên dưới AppBar
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Tính toán kích thước ô quét dựa trên vùng hiển thị thực tế (body)
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final scanAreaSize = size.width * 0.65;
          
          // Căn giữa ô quét
          final scanRect = Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: scanAreaSize,
            height: scanAreaSize,
          );

          return Stack(
            children: [
              // 1. Camera
              MobileScanner(
                controller: _cameraController,
                onDetect: _handleDetection,
              ),

              // 2. Lớp Overlay làm mờ
              _ScannerOverlay(scanRect: scanRect),

              // 3. Tia Laser quét
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Positioned(
                    top: scanRect.top + (scanRect.height * _animationController.value),
                    left: scanRect.left + 10,
                    width: scanRect.width - 20,
                    height: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Colors.transparent,
                            Color(0xFF00FF00),
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00FF00).withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // 4. Text hướng dẫn
              Positioned(
                top: scanRect.bottom + 30,
                left: 0,
                right: 0,
                child: const Text(
                  'Căn chỉnh mã QR vào giữa khung',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  final Rect scanRect;
  const _ScannerOverlay({required this.scanRect});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _ScannerOverlayPainter(scanRect: scanRect),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Rect scanRect;
  _ScannerOverlayPainter({required this.scanRect});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = Colors.black.withValues(alpha: 0.6);

    // Vẽ lớp nền đen mờ, khoét lỗ vuông
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(scanRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(backgroundPath, backgroundPaint);

    // Vẽ 4 góc
    final borderPaint = Paint()
      ..color = const Color(0xFF00FF00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const double cornerLength = 24.0;
    final double radius = 16.0;

    // Góc trên trái
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.left, scanRect.top + cornerLength)
        ..lineTo(scanRect.left, scanRect.top + radius)
        ..quadraticBezierTo(scanRect.left, scanRect.top, scanRect.left + radius, scanRect.top)
        ..lineTo(scanRect.left + cornerLength, scanRect.top),
      borderPaint,
    );

    // Góc trên phải
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.right - cornerLength, scanRect.top)
        ..lineTo(scanRect.right - radius, scanRect.top)
        ..quadraticBezierTo(scanRect.right, scanRect.top, scanRect.right, scanRect.top + radius)
        ..lineTo(scanRect.right, scanRect.top + cornerLength),
      borderPaint,
    );

    // Góc dưới trái
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.left, scanRect.bottom - cornerLength)
        ..lineTo(scanRect.left, scanRect.bottom - radius)
        ..quadraticBezierTo(scanRect.left, scanRect.bottom, scanRect.left + radius, scanRect.bottom)
        ..lineTo(scanRect.left + cornerLength, scanRect.bottom),
      borderPaint,
    );

    // Góc dưới phải
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.right - cornerLength, scanRect.bottom)
        ..lineTo(scanRect.right - radius, scanRect.bottom)
        ..quadraticBezierTo(scanRect.right, scanRect.bottom, scanRect.right, scanRect.bottom - radius)
        ..lineTo(scanRect.right, scanRect.bottom - cornerLength),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanRect != scanRect;
  }
}