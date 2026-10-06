import 'package:flutter/material.dart';

import '../utils/am_lich_helper.dart';

/// Widget "medium" cho Windows — tái tạo phong cách widget macOS
/// trong ảnh: khối ngày lớn bên trái + lưới lịch tháng bên phải
/// + hàng sự kiện sắp tới ở dưới cùng.
class HomeScreenWidgetWindows extends StatelessWidget {
  /// Tháng/năm dương lịch cần hiển thị trên lưới lịch.
  final int thangDuyet;
  final int namDuyet;

  /// Sự kiện gần nhất (đã tính sẵn ở DesktopWidgetScreen).
  final String tenSuKien;
  final String thoiGianSuKien;
  final String loaiSuKien;

  /// Danh sách các ngày trong tháng có sự kiện (dùng để chấm đỏ).
  final List<int> ngayCoSuKien;

  const HomeScreenWidgetWindows({
    super.key,
    required this.thangDuyet,
    required this.namDuyet,
    required this.tenSuKien,
    required this.thoiGianSuKien,
    this.loaiSuKien = 'event',
    this.ngayCoSuKien = const [],
  });

  // --------------------------------------------------------------
  // Bảng màu — dựa trên widget macOS trong ảnh (dark mode)
  // --------------------------------------------------------------
  static const Color _bg = Color(0xFF19191B);
  static const Color _red = Color(0xFFFF3B30);
  static const Color _white = Colors.white;
  static const Color _grey = Color(0xFF98989D);
  static const Color _dim = Color(0xFF48484A);
  static const Color _divider = Color(0xFF2C2C2E);
  static const Color _orange = Color(0xFFFF9500);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // Lấy âm lịch của hôm nay
    int lunarDay = 0, lunarMonth = 0, lunarYear = now.year;
    try {
      final am = AmLichHelper.duongSangAm(now);
      if (am != null) {
        lunarDay = am.getDay();
        lunarMonth = am.getMonth();
        lunarYear = am.getYear();
      }
    } catch (_) {}

    // Tên thứ trong tuần
    final thu = _thuTrongTuan(now.weekday);

    // Can chi năm âm
    final canChi = _canChiNam(lunarYear);

    // Dữ liệu lưới lịch
    final cells = _buildCalendarCells(thangDuyet, namDuyet);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==========================================================
            // PHẦN TRÊN: Khối ngày lớn (trái) + Lịch tháng (phải)
            // ==========================================================
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---------- KHỐI NGÀY LỚN (TRÁI) ----------
                  SizedBox(
                    width: 96,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '${now.day}',
                          style: const TextStyle(
                            color: _red,
                            fontSize: 46,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          thu,
                          style: const TextStyle(
                            color: _white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$lunarDay/$lunarMonth $canChi',
                          style: const TextStyle(
                            color: _grey,
                            fontSize: 10,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ---------- VÁCH NGĂN DỌC ----------
                  Container(
                    width: 1,
                    color: _divider,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                  ),

                  // ---------- LỊCH THÁNG (PHẢI) ----------
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header tháng
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            'Tháng ${thangDuyet.toString().padLeft(2, '0')}/$namDuyet',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _red,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                            ),
                          ),
                        ),
                        // Header thứ trong tuần
                        Row(
                          children: const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
                              .map((d) => Expanded(
                                    child: Text(
                                      d,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _grey,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        height: 1.0,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 2),
                        // Lưới lịch
                        Expanded(
                          child: Column(
                            children: List.generate(
                              (cells.length / 7).ceil(),
                              (weekIdx) => Expanded(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: List.generate(7, (dayIdx) {
                                    final idx = weekIdx * 7 + dayIdx;
                                    if (idx >= cells.length) {
                                      return const Expanded(
                                          child: SizedBox.shrink());
                                    }
                                    return Expanded(
                                      child: _buildCell(
                                          cells[idx], now.day, thangDuyet),
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // ==========================================================
            // PHẦN DƯỚI: Sự kiện sắp tới
            // ==========================================================
            Container(height: 1, color: _divider),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  _iconTheoLoai(loaiSuKien),
                  size: 14,
                  color: _orange,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    tenSuKien,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.0,
                    ),
                  ),
                ),
                if (thoiGianSuKien.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '·',
                      style: TextStyle(color: _grey, fontSize: 12, height: 1.0),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      thoiGianSuKien,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _grey,
                        fontSize: 11,
                        height: 1.0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // XÂY DỰNG 1 Ô LỊCH
  // ================================================================
  Widget _buildCell(_CalendarCell c, int todayDay, int currentMonth) {
    final isToday = c.isToday;
    final isWeekend = c.isWeekend;

    // Màu chữ số dương
    Color solarColor;
    if (!c.inMonth) {
      solarColor = _dim;
    } else if (isWeekend) {
      solarColor = _red;
    } else {
      solarColor = _white;
    }

    // Màu chữ số âm
    Color lunarColor;
    if (!c.inMonth) {
      lunarColor = _dim;
    } else if (isWeekend) {
      lunarColor = _red.withValues(alpha: 0.75);
    } else {
      lunarColor = _grey;
    }

    final hasEvent = c.inMonth && ngayCoSuKien.contains(c.date.day);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Số dương — có thể được bọc bởi pill đỏ nếu là hôm nay
          Container(
            padding: isToday
                ? const EdgeInsets.symmetric(horizontal: 7, vertical: 1)
                : EdgeInsets.zero,
            decoration: isToday
                ? BoxDecoration(
                    color: _red,
                    borderRadius: BorderRadius.circular(5),
                  )
                : null,
            child: Text(
              '${c.date.day}',
              style: TextStyle(
                color: isToday ? _white : solarColor,
                fontSize: 11,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                height: 1.0,
              ),
            ),
          ),
          // Số âm — ẩn nếu là hôm nay (cho gọn), hoặc nếu không có dữ liệu
          if (!isToday && c.lunarDay != null)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                c.lunarDay == 1
                    ? '1/${c.lunarMonth}'
                    : '${c.lunarDay}',
                style: TextStyle(
                  color: hasEvent ? _orange : lunarColor,
                  fontSize: 8,
                  fontWeight: hasEvent ? FontWeight.w700 : FontWeight.w400,
                  height: 1.0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ================================================================
  // XÂY DỰNG TOÀN BỘ Ô LỊCH CHO 1 THÁNG
  // ================================================================
  List<_CalendarCell> _buildCalendarCells(int month, int year) {
    final firstOfMonth = DateTime(year, month, 1);
    // DateTime.weekday: Mon=1 ... Sun=7. Ta bắt đầu tuần từ T2 → offset = weekday - 1
    final offset = firstOfMonth.weekday - 1;
    final startDate = firstOfMonth.subtract(Duration(days: offset));

    final lastOfMonth = DateTime(year, month + 1, 0);
    final totalDays = offset + lastOfMonth.day;
    final weeks = (totalDays / 7).ceil();
    final totalCells = weeks * 7;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final cells = <_CalendarCell>[];
    for (int i = 0; i < totalCells; i++) {
      final date = startDate.add(Duration(days: i));
      final inMonth = date.month == month && date.year == year;
      final isToday = date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      final wd = date.weekday;
      final isWeekend =
          wd == DateTime.saturday || wd == DateTime.sunday;

      int? lunarDay, lunarMonth;
      try {
        final am = AmLichHelper.duongSangAm(date);
        if (am != null) {
          lunarDay = am.getDay();
          lunarMonth = am.getMonth();
        }
      } catch (_) {}

      cells.add(_CalendarCell(
        date: date,
        inMonth: inMonth,
        isToday: isToday,
        isWeekend: isWeekend,
        lunarDay: lunarDay,
        lunarMonth: lunarMonth,
      ));
    }
    return cells;
  }

  // ================================================================
  // HELPERS
  // ================================================================
  String _thuTrongTuan(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Thứ Hai';
      case DateTime.tuesday:
        return 'Thứ Ba';
      case DateTime.wednesday:
        return 'Thứ Tư';
      case DateTime.thursday:
        return 'Thứ Năm';
      case DateTime.friday:
        return 'Thứ Sáu';
      case DateTime.saturday:
        return 'Thứ Bảy';
      case DateTime.sunday:
        return 'Chủ Nhật';
      default:
        return '';
    }
  }

  /// Can chi của năm âm lịch, ví dụ 2026 → "Bính Ngọ"
  String _canChiNam(int lunarYear) {
    const can = [
      'Giáp', 'Ất', 'Bính', 'Đinh', 'Mậu',
      'Kỷ', 'Canh', 'Tân', 'Nhâm', 'Quý'
    ];
    const chi = [
      'Tý', 'Sửu', 'Dần', 'Mão', 'Thìn', 'Tỵ',
      'Ngọ', 'Mùi', 'Thân', 'Dậu', 'Tuất', 'Hợi'
    ];
    // Năm 4 SCN là Giáp Tý
    final canIdx = (lunarYear - 4) % 10;
    final chiIdx = (lunarYear - 4) % 12;
    return '${can[canIdx < 0 ? canIdx + 10 : canIdx]} '
        '${chi[chiIdx < 0 ? chiIdx + 12 : chiIdx]}';
  }

  IconData _iconTheoLoai(String loai) {
    switch (loai) {
      case 'birthday':
        return Icons.cake_outlined;
      case 'holiday':
        return Icons.celebration_outlined;
      case 'anniversary':
        return Icons.favorite_outline;
      default:
        return Icons.event;
    }
  }
}

class _CalendarCell {
  final DateTime date;
  final bool inMonth;
  final bool isToday;
  final bool isWeekend;
  final int? lunarDay;
  final int? lunarMonth;

  _CalendarCell({
    required this.date,
    required this.inMonth,
    required this.isToday,
    required this.isWeekend,
    required this.lunarDay,
    required this.lunarMonth,
  });
}