import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/lich_provider.dart';
import '../utils/am_lich_helper.dart';

// ============================================================
// CONSTANTS — TINH CHỈNH RIÊNG CHO TỪNG PLATFORM
// ============================================================

/// === MOBILE (Android + iOS) ===
const Alignment kButtonAlignmentMobile = Alignment(-0.02, -0.115);
const double kButtonSizeMobile = 200;

/// === macOS ===
/// Sau khi chạy `flutter run -d macos`, tinh chỉnh 2 giá trị này cho khớp
/// trống đồng trong `vie_lich_bg_desktop.png`
const Alignment kButtonAlignmentMacOS = Alignment(-0.01, -0.02);
const double kButtonSizeMacOS = 270;

/// === Windows ===
/// Sau khi chạy `flutter run -d windows`, tinh chỉnh 2 giá trị này
const Alignment kButtonAlignmentWindows = Alignment(0, -0.25);
const double kButtonSizeWindows = 240;

/// Gradient vàng gold dùng cho viền
const LinearGradient kGoldGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFF9E79F), // vàng rất nhạt
    Color(0xFFD4AF37), // vàng gold
    Color(0xFFB8860B), // vàng đậm
    Color(0xFFD4AF37), // vàng gold
    Color(0xFFF9E79F), // vàng rất nhạt
  ],
  stops: [0.0, 0.25, 0.5, 0.75, 1.0],
);

/// Gradient dọc cho vạch ngăn
const LinearGradient kGoldVerticalGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFFB8860B),
    Color(0xFFD4AF37),
    Color(0xFFB8860B),
  ],
  stops: [0.0, 0.5, 1.0],
);

// ============================================================
// HELPER
// ============================================================
String _tenThangAmChu(int thang) {
  const names = [
    '',
    'giêng',
    'hai',
    'ba',
    'tư',
    'năm',
    'sáu',
    'bảy',
    'tám',
    'chín',
    'mười',
    'mười một',
    'chạp'
  ];
  if (thang >= 1 && thang <= 12) return names[thang];
  return '$thang';
}

// ============================================================
// WIDGET: VIỀN GOLD GRADIENT
// ============================================================
class _GoldGradientBorder extends StatelessWidget {
  final Widget child;
  final double borderWidth;
  final double radius;
  final Color? innerColor;

  const _GoldGradientBorder({
    required this.child,
    this.borderWidth = 1.5,
    this.radius = 16.0,
    this.innerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        gradient: kGoldGradient,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: innerColor ?? Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(radius - borderWidth),
        ),
        child: child,
      ),
    );
  }
}

// ============================================================
// MÀN CHÍNH
// ============================================================
class LichNgayScreen extends StatefulWidget {
  const LichNgayScreen({super.key});

  @override
  State<LichNgayScreen> createState() => _LichNgayScreenState();
}

class _LichNgayScreenState extends State<LichNgayScreen>
    with SingleTickerProviderStateMixin {
  double _dragDistance = 0;
  late AnimationController _rippleCtrl;

  @override
  void initState() {
    super.initState();
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _rippleCtrl.dispose();
    super.dispose();
  }

  void _onStarTap() {
    final provider = context.read<LichProvider>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel = provider.selectedDate;
    final selDate = DateTime(sel.year, sel.month, sel.day);

    _rippleCtrl.forward(from: 0);

    if (selDate != today) {
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) {
          context.read<LichProvider>().chonNgay(today);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // === Chọn config theo platform ===
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final isMacOS = Platform.isMacOS;

    final bgAsset = isMobile
        ? 'assets/backgrounds/vie_lich_bg_mobile.png'
        : 'assets/backgrounds/vie_lich_bg_desktop.png';

    final Alignment buttonAlignment;
    final double buttonSize;
    if (isMobile) {
      buttonAlignment = kButtonAlignmentMobile;
      buttonSize = kButtonSizeMobile;
    } else if (isMacOS) {
      buttonAlignment = kButtonAlignmentMacOS;
      buttonSize = kButtonSizeMacOS;
    } else {
      buttonAlignment = kButtonAlignmentWindows;
      buttonSize = kButtonSizeWindows;
    }

    const buttonAsset = 'assets/backgrounds/vie_lich_button.png';

    return Consumer<LichProvider>(
      builder: (context, provider, _) {
        final ngay = provider.selectedDate;
        final lunar = AmLichHelper.duongSangAm(ngay);

        return Scaffold(
          backgroundColor: const Color(0xFFFAF3E8),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              final buttonCenter = Offset(
                (buttonAlignment.x + 1) / 2 * size.width,
                (buttonAlignment.y + 1) / 2 * size.height,
              );

              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (_) {
                  _dragDistance = 0;
                },
                onHorizontalDragUpdate: (details) {
                  _dragDistance += details.delta.dx;
                },
                onHorizontalDragEnd: (details) {
                  final v = details.primaryVelocity ?? 0;
                  final sangPhai = v > 250 || _dragDistance > 60;
                  final sangTrai = v < -250 || _dragDistance < -60;

                  if (sangTrai) {
                    provider.chonNgay(ngay.add(const Duration(days: 1)));
                  } else if (sangPhai) {
                    provider.chonNgay(ngay.subtract(const Duration(days: 1)));
                  }
                  _dragDistance = 0;
                },
                onTapUp: (details) {
                  final d = (details.localPosition - buttonCenter).distance;
                  if (d < buttonSize * 0.5) {
                    _onStarTap();
                  }
                },
                child: Stack(
                  children: [
                    // 1. BACKGROUND
                    Positioned.fill(
                      child: Image.asset(
                        bgAsset,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFFAF3E8),
                        ),
                      ),
                    ),

                    // 2. RIPPLE
                    Positioned.fill(
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _rippleCtrl,
                            builder: (context, _) {
                              return CustomPaint(
                                painter: _RipplePainter(
                                  progress: _rippleCtrl.value,
                                  color: const Color(0xFFFFC107),
                                  center: buttonCenter,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    // 3. NÚT TRỐNG ĐỒNG
                    Positioned(
                      left: buttonCenter.dx - buttonSize / 2,
                      top: buttonCenter.dy - buttonSize / 2,
                      width: buttonSize,
                      height: buttonSize,
                      child: IgnorePointer(
                        child: Image.asset(
                          buttonAsset,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),

                    // 4. CONTENT
                    SafeArea(
                      child: LayoutBuilder(
                        builder: (context, c2) {
                          final isWide = c2.maxWidth > 700;
                          final maxContentWidth =
                              isWide ? 560.0 : double.infinity;
                          final horizontalPadding = isWide ? 48.0 : 20.0;

                          return Center(
                            child: ConstrainedBox(
                              constraints:
                                  BoxConstraints(maxWidth: maxContentWidth),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: horizontalPadding,
                                  vertical: 12,
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  switchInCurve: Curves.easeOut,
                                  switchOutCurve: Curves.easeIn,
                                  layoutBuilder:
                                      (currentChild, previousChildren) {
                                    return Stack(
                                      alignment: Alignment.topLeft,
                                      children: [
                                        ...previousChildren,
                                        if (currentChild != null) currentChild,
                                      ],
                                    );
                                  },
                                  child: KeyedSubtree(
                                    key: ValueKey(
                                        '${ngay.year}-${ngay.month}-${ngay.day}'),
                                    child: _NgayContent(
                                      ngay: ngay,
                                      lunar: lunar,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ============================================================
// NỘI DUNG 1 NGÀY
// ============================================================
class _NgayContent extends StatelessWidget {
  final DateTime ngay;
  final dynamic lunar;

  const _NgayContent({required this.ngay, required this.lunar});

  @override
  Widget build(BuildContext context) {
    final ngayAm = lunar?.getDay() as int? ?? 0;
    final thangAm = lunar?.getMonth() as int? ?? 0;
    final canChiNam = lunar != null ? AmLichHelper.layCanChiNam(lunar) : '';
    final thu = DateFormat('EEEE', 'vi').format(ngay);
    final dsLe =
        lunar != null ? AmLichHelper.layNgayLe(ngay, lunar) : <String>[];

    const double kLeHeight = 52.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _LichDoiBlock(
            ngay: ngay,
            ngayAm: ngayAm,
            thangAm: thangAm,
            canChiNam: canChiNam,
            thu: thu,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: kLeHeight,
          child: dsLe.isEmpty
              ? const SizedBox.shrink()
              : _NgayLeCompact(dsLe: dsLe),
        ),
        const SizedBox(height: 12),
        _NutXemTietKhiSao(ngay: ngay, lunar: lunar),
      ],
    );
  }
}

// ============================================================
// KHỐI LỊCH ĐÔI
// ============================================================
class _LichDoiBlock extends StatelessWidget {
  final DateTime ngay;
  final int ngayAm;
  final int thangAm;
  final String canChiNam;
  final String thu;

  const _LichDoiBlock({
    required this.ngay,
    required this.ngayAm,
    required this.thangAm,
    required this.canChiNam,
    required this.thu,
  });

  @override
  Widget build(BuildContext context) {
    final red = Colors.red.shade600;
    final blue = const Color(0xFF1565C0);

    final thuWords = thu.split(' ');
    final thuDisplay = thuWords.length >= 2
        ? '${thuWords[0]}\n${thuWords.sublist(1).join(' ')}'
        : thu;

    final tenThangAm = _tenThangAmChu(thangAm);
    final tenThangAmHoa =
        '${tenThangAm[0].toUpperCase()}${tenThangAm.substring(1)}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final solarFontSize = (h * 0.26).clamp(70.0, 150.0);
        final lunarFontSize = (h * 0.20).clamp(55.0, 120.0);
        final labelFontSize = (h * 0.028).clamp(10.0, 13.0);
        final monthFontSize = (h * 0.032).clamp(12.0, 15.0);
        final metaFontSize = (h * 0.032).clamp(11.0, 14.0);
        final thuFontSize = (h * 0.042).clamp(14.0, 19.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  // ================= SỐ DƯƠNG =================
                  Align(
                    alignment: const Alignment(-0.7, -0.75),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dương lịch',
                          style: TextStyle(
                            fontSize: labelFontSize,
                            color: blue.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${ngay.day}',
                          style: TextStyle(
                            fontSize: solarFontSize,
                            fontWeight: FontWeight.w800,
                            height: 0.85,
                            letterSpacing: -4,
                            color: blue,
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, -6),
                          child: Text(
                            'Tháng ${ngay.month}',
                            style: TextStyle(
                              fontSize: monthFontSize,
                              color: blue.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ================= SỐ ÂM =================
                  Align(
                    alignment: const Alignment(0.9, 1),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _TextWithGoldStroke(
                          text: '$ngayAm',
                          fontSize: lunarFontSize,
                          fillColor: red,
                          strokeWidth: 4.0,
                          letterSpacing: -2,
                        ),
                        Transform.translate(
                          offset: const Offset(0, -1),
                          child: Text(
                            'Tháng $tenThangAmHoa',
                            style: TextStyle(
                              fontSize: monthFontSize,
                              color: red.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Âm lịch',
                          style: TextStyle(
                            fontSize: labelFontSize,
                            color: red.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ================================================
            // BẢNG DƯỚI — bọc viền gold gradient
            // ================================================
            _GoldGradientBorder(
              borderWidth: 1.5,
              radius: 16,
              innerColor: Colors.white.withValues(alpha: 0.55),
              child: SizedBox(
                height: (h * 0.18).clamp(70.0, 110.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Cột "Thứ Năm"
                      Container(
                        padding: const EdgeInsets.only(right: 14),
                        alignment: Alignment.centerRight,
                        child: Text(
                          thuDisplay,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: thuFontSize,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF7B3F00),
                            height: 1.15,
                          ),
                        ),
                      ),

                      // Vạch dọc — gradient gold
                      Container(
                        width: 1.5,
                        decoration: const BoxDecoration(
                          gradient: kGoldVerticalGradient,
                        ),
                      ),

                      // 2 dòng: dương / âm
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Ngày ${ngay.day} tháng ${ngay.month} năm ${ngay.year}',
                                    style: TextStyle(
                                      fontSize: metaFontSize,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF7B3F00),
                                      height: 1.15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              Container(
                                height: 1,
                                decoration: const BoxDecoration(
                                  gradient: kGoldVerticalGradient,
                                ),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Ngày $ngayAm tháng $tenThangAm năm $canChiNam',
                                    style: TextStyle(
                                      fontSize: metaFontSize,
                                      color: const Color(0xFF9B2C2C),
                                      height: 1.15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================
// TEXT VỚI VIỀN GOLD + FLARE
// ============================================================
class _TextWithGoldStroke extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color fillColor;
  final double strokeWidth;
  final double letterSpacing;

  const _TextWithGoldStroke({
    required this.text,
    required this.fontSize,
    required this.fillColor,
    this.strokeWidth = 4.0,
    this.letterSpacing = 0,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w300,
      height: 0.85,
      letterSpacing: letterSpacing,
    );

    const goldColor = Color(0xFFFFD700);

    return Stack(
      children: [
        // LAYER 0: Flare ngoài — blur rộng
        Text(
          text,
          style: baseStyle.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth * 2.5
              ..strokeJoin = StrokeJoin.round
              ..color = goldColor.withValues(alpha: 0.25)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
          ),
        ),
        // LAYER 1: Flare gần — blur nhẹ
        Text(
          text,
          style: baseStyle.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth * 1.5
              ..strokeJoin = StrokeJoin.round
              ..color = goldColor.withValues(alpha: 0.5)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
          ),
        ),
        // LAYER 2: Viền gold sắc nét
        Text(
          text,
          style: baseStyle.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = goldColor,
          ),
        ),
        // LAYER 3: Fill đỏ
        Text(
          text,
          style: baseStyle.copyWith(color: fillColor),
        ),
      ],
    );
  }
}

// ============================================================
// NGÀY LỄ (compact)
// ============================================================
class _NgayLeCompact extends StatelessWidget {
  final List<String> dsLe;
  const _NgayLeCompact({required this.dsLe});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.celebration, color: Colors.orange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              dsLe.join(' • '),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8B4513),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// NÚT XEM TIẾT KHÍ & SAO — VIỀN GOLD GRADIENT
// ============================================================
class _NutXemTietKhiSao extends StatelessWidget {
  final DateTime ngay;
  final dynamic lunar;

  const _NutXemTietKhiSao({required this.ngay, required this.lunar});

  @override
  Widget build(BuildContext context) {
    return _GoldGradientBorder(
      borderWidth: 1.5,
      radius: 14,
      innerColor: Colors.white.withValues(alpha: 0.60),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _hienDialogTietKhiSao(context),
          borderRadius: BorderRadius.circular(12.5),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.wb_sunny_outlined,
                  size: 18,
                  color: Color(0xFF7B3F00),
                ),
                SizedBox(width: 8),
                Text(
                  'Xem tiết khí & sao tốt xấu',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7B3F00),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _hienDialogTietKhiSao(BuildContext context) {
    final tietKhi = AmLichHelper.layTietKhi(ngay);
    final tot = lunar != null ? AmLichHelper.laySaoTot(lunar) : <String>[];
    final xau = lunar != null ? AmLichHelper.laySaoXau(lunar) : <String>[];

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome,
                          color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Tiết khí & Sao',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.wb_sunny_outlined,
                                size: 18, color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            Text('Tiết khí: ',
                                style: TextStyle(
                                    color: Colors.grey.shade700, fontSize: 15)),
                            Text(
                              tietKhi.isEmpty ? '—' : tietKhi,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        if (tot.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Icon(Icons.thumb_up_alt_outlined,
                                  size: 18, color: Colors.green.shade700),
                              const SizedBox(width: 8),
                              Text('Sao tốt',
                                  style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: tot
                                .map((s) => Chip(
                                      label: Text(s,
                                          style: const TextStyle(fontSize: 12)),
                                      backgroundColor: Colors.green.shade50,
                                      side: BorderSide(
                                          color: Colors.green.shade200),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ))
                                .toList(),
                          ),
                        ],
                        if (xau.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Icon(Icons.thumb_down_alt_outlined,
                                  size: 18, color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              Text('Sao xấu',
                                  style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: xau
                                .map((s) => Chip(
                                      label: Text(s,
                                          style: const TextStyle(fontSize: 12)),
                                      backgroundColor: Colors.red.shade50,
                                      side: BorderSide(
                                          color: Colors.red.shade200),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ))
                                .toList(),
                          ),
                        ],
                        if (tot.isEmpty && xau.isEmpty) ...[
                          const SizedBox(height: 12),
                          Text('Không có dữ liệu sao.',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// CUSTOM PAINTER: RIPPLE
// ============================================================
class _RipplePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Offset center;

  _RipplePainter({
    required this.progress,
    required this.color,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final maxR = math.min(size.width, size.height) * 0.55;
    final r = maxR * progress;
    final opacity = (1 - progress) * 0.55;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14.0 * (1 - progress * 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..isAntiAlias = true;
    canvas.drawCircle(center, r, glowPaint);

    final mainPaint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5 * (1 - progress * 0.4)
      ..isAntiAlias = true;
    canvas.drawCircle(center, r, mainPaint);

    if (r > 50) {
      final midPaint = Paint()
        ..color = color.withValues(alpha: opacity * 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..isAntiAlias = true;
      canvas.drawCircle(center, r * 0.62, midPaint);
    }

    if (r > 90) {
      final innerPaint = Paint()
        ..color = color.withValues(alpha: opacity * 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..isAntiAlias = true;
      canvas.drawCircle(center, r * 0.35, innerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.center != center;
}