import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/lich_provider.dart';
import '../providers/su_kien_provider.dart'; // Đã thêm import SuKienProvider
import '../utils/am_lich_helper.dart';
import '../utils/lunar_vn.dart';

class LichThangScreen extends StatefulWidget {
  const LichThangScreen({super.key});

  @override
  State<LichThangScreen> createState() => _LichThangScreenState();
}

class _LichThangScreenState extends State<LichThangScreen> {
  late DateTime _focusedMonth;
  final Map<String, LunarDate> _cacheAmLich = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
  }

  /// Cache kết quả chuyển đổi âm lịch — thuật toán khá nặng, cache để rebuild nhanh.
  LunarDate _layAmLich(DateTime date) {
    final key = '${date.year}-${date.month}-${date.day}';
    return _cacheAmLich.putIfAbsent(
      key,
      () => LunarSolarConverter.solarToLunar(date),
    );
  }

  void _thangTruoc() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  void _thangSau() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  void _veHomNay() {
    final now = DateTime.now();
    setState(() {
      _focusedMonth = DateTime(now.year, now.month, 1);
    });
    Provider.of<LichProvider>(context, listen: false).chonNgay(now);
  }

  /// Trả về danh sách ngày vừa đủ để hiển thị tháng hiện tại.
  /// Số tuần thường là 5, có thể là 4 (tháng 2 không nhuận bắt đầu từ T2)
  /// hoặc 6 (tháng 31 ngày bắt đầu từ CN).
  List<DateTime> _layNgayTrongThang() {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    // weekday: 1 = Thứ Hai ... 7 = Chủ Nhật
    final offset = firstDay.weekday - 1;
    // Số ngày của tháng: ngày 0 của tháng sau = ngày cuối tháng này
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    final totalCells = offset + daysInMonth;
    final soTuan = (totalCells / 7).ceil();
    final start = firstDay.subtract(Duration(days: offset));
    return List.generate(soTuan * 7, (i) => start.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LichProvider>(context);
    final selectedDate = provider.selectedDate;

    // --- Lắng nghe danh sách sự kiện từ SuKienProvider ---
    final suKienProvider = Provider.of<SuKienProvider>(context);
    final cacNgayCoSuKien = suKienProvider.cacNgayCoSuKienDuongLich;
    // -------------------------------------------------------------

    final listNgay = _layNgayTrongThang();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch tháng'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Hôm nay',
            onPressed: _veHomNay,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // === HEADER ĐIỀU HƯỚNG THÁNG ===
            _HeaderThang(
              thang: _focusedMonth.month,
              nam: _focusedMonth.year,
              onPrev: _thangTruoc,
              onNext: _thangSau,
            ),
            // === HEADER THỨ TRONG TUẦN ===
            const _HeaderThu(),
            // === GRID NGÀY (số ô = số tuần * 7) ===
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.0,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: listNgay.length,
              itemBuilder: (context, index) {
                final date = listNgay[index];
                final amLich = _layAmLich(date);
                final isCurrentMonth = date.month == _focusedMonth.month &&
                    date.year == _focusedMonth.year;
                final isToday = date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day;
                final isSelected = date.year == selectedDate.year &&
                    date.month == selectedDate.month &&
                    date.day == selectedDate.day;

                // --- Kiểm tra xem ngày đang vẽ có sự kiện hay không ---
                final dateOnly = DateTime(date.year, date.month, date.day);
                final hasEvent = cacNgayCoSuKien.contains(dateOnly);
                // -------------------------------------------------------------

                return _ONgay(
                  date: date,
                  amLich: amLich,
                  isCurrentMonth: isCurrentMonth,
                  isToday: isToday,
                  isSelected: isSelected,
                  hasEvent: hasEvent,
                  onTap: () {
                    provider.chonNgay(date);
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            // === CHI TIẾT NGÀY ĐƯỢC CHỌN ===
            _ChiTietNgayChon(
              ngay: selectedDate,
              amLich: _layAmLich(selectedDate),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// ===== HEADER ĐIỀU HƯỚNG THÁNG =====
class _HeaderThang extends StatelessWidget {
  final int thang;
  final int nam;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _HeaderThang({
    required this.thang,
    required this.nam,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left, size: 28),
            tooltip: 'Tháng trước',
          ),
          Text(
            'Tháng $thang, $nam',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right, size: 28),
            tooltip: 'Tháng sau',
          ),
        ],
      ),
    );
  }
}

/// ===== HEADER THỨ TRONG TUẦN =====
class _HeaderThu extends StatelessWidget {
  const _HeaderThu();

  @override
  Widget build(BuildContext context) {
    const thu = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Row(
        children: List.generate(7, (i) {
          final isCN = i == 6;
          return Expanded(
            child: Center(
              child: Text(
                thu[i],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isCN ? Colors.red : theme.colorScheme.primary,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// ===== Ô NGÀY (dương đen trên trái + âm đỏ dưới phải) =====
class _ONgay extends StatelessWidget {
  final DateTime date;
  final LunarDate amLich;
  final bool isCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final bool hasEvent; // Nhận biến trạng thái sự kiện
  final VoidCallback onTap;

  const _ONgay({
    required this.date,
    required this.amLich,
    required this.isCurrentMonth,
    required this.isToday,
    required this.isSelected,
    this.hasEvent = false, // Mặc định là false
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCN = date.weekday == 7;

    Color colorDuong = isCN ? Colors.red.shade700 : Colors.black87;
    Color colorAm = Colors.red;
    if (!isCurrentMonth) {
      colorDuong = colorDuong.withValues(alpha: 0.35);
      colorAm = colorAm.withValues(alpha: 0.35);
    }

    Color? bg;
    if (isSelected) {
      bg = theme.colorScheme.primaryContainer;
    } else if (isToday) {
      bg = theme.colorScheme.primary.withValues(alpha: 0.08);
    }

    String ngayAmText;
    if (amLich.day == 1) {
      ngayAmText = '1/${amLich.month}';
    } else {
      ngayAmText = '${amLich.day}';
    }

    final isDauThangAm = amLich.day == 1;
    final isRam = amLich.day == 15;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: isToday
              ? Border.all(color: theme.colorScheme.primary, width: 1.5)
              : null,
        ),
        padding: const EdgeInsets.all(2),
        child: Stack(
          children: [
            Positioned(
              top: 2,
              left: 4,
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: colorDuong,
                ),
              ),
            ),
            Positioned(
              bottom: 2,
              right: 4,
              child: Text(
                ngayAmText,
                style: TextStyle(
                  fontSize: isDauThangAm ? 10 : 11,
                  color: colorAm,
                  fontWeight: (isDauThangAm || isRam)
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
            // Chấm mùng 1 / ngày rằm (mặc định)
            if (isDauThangAm || isRam)
              Positioned(
                bottom: 4,
                left: 4,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isRam ? Colors.orange : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),

            // Chấm màu xanh thông báo sự kiện (Góc trên phải)
            if (hasEvent)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ===== CHI TIẾT NGÀY ĐƯỢC CHỌN (dưới cùng) =====
class _ChiTietNgayChon extends StatelessWidget {
  final DateTime ngay;
  final LunarDate amLich;

  const _ChiTietNgayChon({required this.ngay, required this.amLich});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lunarDay = AmLichHelper.duongSangAm(ngay);
    final thu = DateFormat('EEEE, dd/MM/yyyy', 'vi').format(ngay);
    final tietKhi = AmLichHelper.layTietKhi(ngay);
    final dsLe =
        lunarDay != null ? AmLichHelper.layNgayLe(ngay, lunarDay) : <String>[];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              thu,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Âm lịch: ${AmLichHelper.layTenNgay(amLich.day)} '
              '${AmLichHelper.layTenThang(amLich.month).toLowerCase()}, '
              'năm ${amLich.canChiYear}'
              '${amLich.isLeap ? ' (nhuận)' : ''}',
              style: const TextStyle(fontSize: 14, color: Colors.red),
            ),
            if (lunarDay != null) ...[
              const SizedBox(height: 4),
              Text(
                AmLichHelper.layChuoiCanChiDayDu(lunarDay),
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
            if (tietKhi.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.wb_sunny_outlined,
                      size: 14, color: Colors.orange.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'Tiết khí: $tietKhi',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ],
            if (dsLe.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...dsLe.map(
                (le) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.celebration,
                          size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          le,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
