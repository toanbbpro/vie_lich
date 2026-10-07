import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/lich_provider.dart';
import '../utils/am_lich_helper.dart';

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
// MÀN CHÍNH
// ============================================================
class LichNgayScreen extends StatelessWidget {
  const LichNgayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LichProvider>(
      builder: (context, provider, _) {
        final ngay = provider.selectedDate;
        final lunar = AmLichHelper.duongSangAm(ngay);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // === BACKGROUND TRỐNG ĐỒNG ===
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _TrongDongPainter(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.07),
                    ),
                  ),
                ),
              ),

              // === CONTENT ===
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 700;
                    final maxContentWidth = isWide ? 560.0 : double.infinity;
                    final horizontalPadding = isWide ? 48.0 : 20.0;

                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxContentWidth),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: 12,
                          ),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragEnd: (details) {
                              final v = details.primaryVelocity ?? 0;
                              if (v < -300) {
                                provider.chonNgay(
                                    ngay.add(const Duration(days: 1)));
                              } else if (v > 300) {
                                provider.chonNgay(
                                    ngay.subtract(const Duration(days: 1)));
                              }
                            },
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              child: KeyedSubtree(
                                key: ValueKey(
                                    '${ngay.year}-${ngay.month}-${ngay.day}'),
                                child: _NgayContent(ngay: ngay, lunar: lunar),
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

    // 👇 Chiều cao CỐ ĐỊNH cho vùng ngày lễ — để cụm số không lệch
    // khi có / không có lễ. 52px đủ chứa 1 dòng lễ (maxLines: 2).
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

        // ============================================================
        // VÙNG NGÀY LỄ — LUÔN CHIẾM CHỖ dù rỗng
        // ============================================================
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final red = Colors.red.shade600;
    final blue = const Color(0xFF1565C0);
    final divider = theme.colorScheme.primary.withValues(alpha: 0.25);

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
            // ================================================
            // PHẦN TRÊN: SỐ DƯƠNG + SỐ ÂM
            // ================================================
            Expanded(
              child: Stack(
                children: [
                  // ================= SỐ DƯƠNG (TRÊN-TRÁI) =================
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

                  // ================= SỐ ÂM (DƯỚI-PHẢI) =================
                  Align(
                    alignment: const Alignment(0.7, 0.75),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$ngayAm',
                          style: TextStyle(
                            fontSize: lunarFontSize,
                            fontWeight: FontWeight.w300,
                            height: 0.85,
                            letterSpacing: -2,
                            color: red,
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, -4),
                          child: Text(
                            'Tháng $tenThangAmHoa',
                            style: TextStyle(
                              fontSize: monthFontSize,
                              color: red.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
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
            // BẢNG DƯỚI: Thứ | vạch dọc | 2 dòng
            // ================================================
            SizedBox(
              height: (h * 0.18).clamp(70.0, 110.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.only(right: 12),
                    alignment: Alignment.centerRight,
                    child: Text(
                      thuDisplay,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: thuFontSize,
                        fontWeight: FontWeight.w500,
                        color: primary,
                        height: 1.15,
                      ),
                    ),
                  ),
                  Container(width: 1, color: divider),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
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
                                  fontWeight: FontWeight.w500,
                                  color: primary,
                                  height: 1.15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          Container(height: 1, color: divider),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Ngày $ngayAm tháng $tenThangAm năm $canChiNam',
                                style: TextStyle(
                                  fontSize: metaFontSize,
                                  color: red,
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
          ],
        );
      },
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
        color: Colors.amber.shade50.withValues(alpha: 0.7),
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
// NÚT XEM TIẾT KHÍ & SAO
// ============================================================
class _NutXemTietKhiSao extends StatelessWidget {
  final DateTime ngay;
  final dynamic lunar;

  const _NutXemTietKhiSao({required this.ngay, required this.lunar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: () => _hienDialogTietKhiSao(context),
      icon: const Icon(Icons.wb_sunny_outlined, size: 18),
      label: const Text(
        'Xem tiết khí & sao tốt xấu',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.colorScheme.primary,
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.4),
          width: 1.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
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
// CUSTOM PAINTER: TRỐNG ĐỒNG
// ============================================================
class _TrongDongPainter extends CustomPainter {
  final Color color;
  _TrongDongPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..isAntiAlias = true;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final center = Offset(size.width / 2, size.height * 0.42);
    final radius = math.min(size.width, size.height) * 0.45;

    _drawTrongDong(canvas, center, radius, strokePaint, fillPaint);
  }

  void _drawTrongDong(
    Canvas canvas,
    Offset center,
    double radius,
    Paint strokePaint,
    Paint fillPaint,
  ) {
    for (int i = 0; i < 5; i++) {
      final r = radius * (1.0 - i * 0.18);
      canvas.drawCircle(center, r, strokePaint);
    }

    final dotRingR = radius * 0.82;
    const numDots = 32;
    for (int i = 0; i < numDots; i++) {
      final angle = (i * 2 * math.pi) / numDots;
      final dx = center.dx + dotRingR * math.cos(angle);
      final dy = center.dy + dotRingR * math.sin(angle);
      canvas.drawCircle(Offset(dx, dy), 1.8, fillPaint);
    }

    final starPath = Path();
    const numPoints = 12;
    final outerR = radius * 0.32;
    final innerR = radius * 0.13;
    for (int i = 0; i < numPoints * 2; i++) {
      final angle = (i * math.pi) / numPoints - math.pi / 2;
      final r = i.isEven ? outerR : innerR;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        starPath.moveTo(x, y);
      } else {
        starPath.lineTo(x, y);
      }
    }
    starPath.close();
    canvas.drawPath(starPath, strokePaint);

    final sawR = radius * 0.65;
    final sawPath = Path();
    const numTeeth = 40;
    for (int i = 0; i < numTeeth; i++) {
      final angle1 = (i * 2 * math.pi) / numTeeth;
      final angle2 = ((i + 0.5) * 2 * math.pi) / numTeeth;
      final r1 = sawR;
      final r2 = sawR + 5;
      final x1 = center.dx + r1 * math.cos(angle1);
      final y1 = center.dy + r1 * math.sin(angle1);
      final x2 = center.dx + r2 * math.cos(angle2);
      final y2 = center.dy + r2 * math.sin(angle2);
      if (i == 0) {
        sawPath.moveTo(x1, y1);
      } else {
        sawPath.lineTo(x1, y1);
      }
      sawPath.lineTo(x2, y2);
    }
    canvas.drawPath(sawPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _TrongDongPainter oldDelegate) =>
      oldDelegate.color != color;
}
