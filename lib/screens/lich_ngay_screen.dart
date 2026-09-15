import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/lich_provider.dart';
import '../utils/am_lich_helper.dart';

class LichNgayScreen extends StatelessWidget {
  const LichNgayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LichProvider>(context);
    final ngay = provider.selectedDate;
    final lunar = AmLichHelper.duongSangAm(ngay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch ngày'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (lunar != null) _NgayCard(ngay: ngay, lunar: lunar),
            const SizedBox(height: 12),
            if (lunar != null) _NgayLeCard(ngay: ngay, lunar: lunar),
            const SizedBox(height: 24),
            if (lunar != null) _TietKhiSaoCard(ngay: ngay, lunar: lunar),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final chon = await showDatePicker(
                  context: context,
                  initialDate: ngay,
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2100),
                );
                if (chon != null) {
                  provider.chonNgay(chon);
                }
              },
              icon: const Icon(Icons.calendar_today),
              label: const Text('Chọn ngày khác'),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===== CARD: NGÀY (GỘP ÂM + DƯƠNG + CAN CHI 1 DÒNG) =====
class _NgayCard extends StatelessWidget {
  final DateTime ngay;
  final dynamic lunar;

  const _NgayCard({required this.ngay, required this.lunar});

  @override
  Widget build(BuildContext context) {
    final thu = DateFormat('EEEE', 'vi').format(ngay);
    final theme = Theme.of(context);

    final ngayAm = lunar.getDay() as int;
    final thangAm = lunar.getMonth() as int;
    final namAm = AmLichHelper.layCanChiNam(lunar);
    final chuoiCanChi = AmLichHelper.layChuoiCanChiDayDu(lunar);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Thứ
            Text(
              thu,
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),

            // Hàng ngang: Dương (trái) | Âm (phải)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // === BÊN TRÁI: DƯƠNG LỊCH ===
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${ngay.day}',
                        style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tháng ${ngay.month}',
                        style: const TextStyle(fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        'Năm ${ngay.year}',
                        style: const TextStyle(fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // === VÁCH NGĂN CÁCH ===
                Container(
                  width: 1,
                  height: 100,
                  color: Colors.grey.shade300,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),

                // === BÊN PHẢI: ÂM LỊCH ===
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        AmLichHelper.layTenNgay(ngayAm),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                          height: 1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AmLichHelper.layTenThang(thangAm),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        'Năm $namAm',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // === ĐƯỜNG NGĂN CÁCH + CAN CHI 1 DÒNG ===
            if (chuoiCanChi.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(color: Colors.grey.shade300, height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      chuoiCanChi,
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ===== CARD GỘP: TIẾT KHÍ + SAO TỐT / XẤU =====
class _TietKhiSaoCard extends StatelessWidget {
  final DateTime ngay;
  final dynamic lunar;

  const _TietKhiSaoCard({required this.ngay, required this.lunar});

  @override
  Widget build(BuildContext context) {
    final tietKhi = AmLichHelper.layTietKhi(ngay);
    final tot = AmLichHelper.laySaoTot(lunar);
    final xau = AmLichHelper.laySaoXau(lunar);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _TieuDe(text: 'Tiết khí & Sao'),
            const SizedBox(height: 12),

            // === TIẾT KHÍ ===
            Row(
              children: [
                Icon(Icons.wb_sunny_outlined,
                    size: 18, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  'Tiết khí: ',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  tietKhi.isEmpty ? '—' : tietKhi,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            // === SAO TỐT ===
            if (tot.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.thumb_up_alt_outlined,
                      size: 18, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Sao tốt',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tot
                    .map(
                      (s) => Chip(
                        label: Text(s, style: const TextStyle(fontSize: 12)),
                        backgroundColor: Colors.green.shade50,
                        side: BorderSide(color: Colors.green.shade200),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],

            // === SAO XẤU ===
            if (xau.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.thumb_down_alt_outlined,
                      size: 18, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Sao xấu',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: xau
                    .map(
                      (s) => Chip(
                        label: Text(s, style: const TextStyle(fontSize: 12)),
                        backgroundColor: Colors.red.shade50,
                        side: BorderSide(color: Colors.red.shade200),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],

            // Nếu không có gì
            if (tot.isEmpty && xau.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Không có dữ liệu sao.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ===== CARD: NGÀY LỄ =====
class _NgayLeCard extends StatelessWidget {
  final DateTime ngay;
  final dynamic lunar;

  const _NgayLeCard({required this.ngay, required this.lunar});

  @override
  Widget build(BuildContext context) {
    final dsLe = AmLichHelper.layNgayLe(ngay, lunar);
    if (dsLe.isEmpty) return const SizedBox.shrink();

    return Card(
      color: Colors.amber.shade50,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _TieuDe(text: 'Ngày lễ hôm nay', color: Colors.orange),
            const SizedBox(height: 8),
            ...dsLe.map(
              (le) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.celebration,
                        color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(le, style: const TextStyle(fontSize: 15)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===== WIDGET PHỤ =====
class _TieuDe extends StatelessWidget {
  final String text;
  final Color? color;

  const _TieuDe({required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: color ?? Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
