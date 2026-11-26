import 'dart:io' show Platform;
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';

import '../models/su_kien.dart';
import '../utils/am_lich_helper.dart';
import 'ics_service.dart';

class CalendarExport {
  /// Trả về ngày dương của sự kiện âm lịch trong tương lai gần nhất (chuẩn năm âm lịch UTC+7).
  static DateTime? tinhNgaySuKien(SuKien suKien) {
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    try {
      if (suKien.namAm != null) {
        return IcsService.tinhNgayDuongTheoNamAm(
            suKien.namAm!, suKien.thangAm, suKien.ngayAm);
      }
      final amHienTai = AmLichHelper.duongSangAm(now);
      final namAmHienTai = amHienTai?.year ?? now.year;

      var ngay = IcsService.tinhNgayDuongTheoNamAm(
          namAmHienTai, suKien.thangAm, suKien.ngayAm);
      if (ngay != null &&
          DateTime(ngay.year, ngay.month, ngay.day).isBefore(todayOnly)) {
        ngay = IcsService.tinhNgayDuongTheoNamAm(
            namAmHienTai + 1, suKien.thangAm, suKien.ngayAm);
      }
      return ngay;
    } catch (e) {
      return null;
    }
  }

  /// Trả về ngày báo (ngày sự kiện - số ngày báo trước).
  static DateTime? tinhNgayBao(SuKien suKien) {
    final ngaySuKien = tinhNgaySuKien(suKien);
    if (ngaySuKien == null) return null;
    return ngaySuKien.subtract(Duration(days: suKien.baoTruoc));
  }

  /// Xuất nhanh 1 năm sang lịch hệ thống trên Android/iOS (qua add_2_calendar).
  static Future<bool> xuatSuKien(SuKien suKien) async {
    try {
      final ngaySuKien = tinhNgaySuKien(suKien);
      if (ngaySuKien == null) return false;

      final moTa = StringBuffer();
      if (suKien.ghiChu != null && suKien.ghiChu!.isNotEmpty) {
        moTa.writeln(suKien.ghiChu);
        moTa.writeln();
      }
      moTa.writeln('Ngày âm: ${suKien.ngayAm}/${suKien.thangAm}');
      moTa.writeln('Báo trước: ${suKien.baoTruoc} ngày');

      final event = Event(
        title: '${suKien.ten} (${suKien.ngayAm}/${suKien.thangAm} ÂL)',
        description: moTa.toString(),
        startDate: ngaySuKien,
        endDate: ngaySuKien.add(const Duration(hours: 1)),
        allDay: true,
      );

      await Add2Calendar.addEvent2Cal(event);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Hiển thị hộp thoại chọn số năm (1 / 3 / 5 / 10 năm) để xuất ra file .ics
  /// hoặc mở trực tiếp ứng dụng Lịch hệ thống (trên Android/iOS khi chọn 1 năm cho 1 sự kiện).
  static Future<bool> hienDialogXuatLich(
    BuildContext context,
    List<SuKien> dsSuKien,
  ) async {
    if (dsSuKien.isEmpty) return false;

    final bool laMobileMotSuKien =
        (Platform.isAndroid || Platform.isIOS) && dsSuKien.length == 1;
    final bool coSuKienLap = dsSuKien.any((e) => e.namAm == null);
    int soNamChon = coSuKienLap ? 5 : 1;

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.calendar_month, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dsSuKien.length == 1
                          ? 'Xuất sang lịch hệ thống'
                          : 'Xuất ${dsSuKien.length} sự kiện (.ics)',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coSuKienLap
                        ? 'Vì ngày Âm lịch thay đổi theo từng năm Dương lịch, hệ thống sẽ tính sẵn chính xác các năm tiếp theo vào chuẩn lịch (.ics):'
                        : 'Xuất sự kiện ra định dạng chuẩn iCalendar (.ics) tương thích Google Calendar, Apple Calendar, Outlook, Thunderbird:',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  if (coSuKienLap) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Số năm muốn xuất:',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: IcsService.cacLuaChonSoNam.map((nam) {
                        final selected = soNamChon == nam;
                        return ChoiceChip(
                          label: Text('$nam năm'),
                          selected: selected,
                          onSelected: (_) =>
                              setModalState(() => soNamChon = nam),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                if (laMobileMotSuKien && soNamChon == 1)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(ctx, 'native_1y'),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Mở Lịch máy (1 năm)'),
                  ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'ics'),
                  icon: const Icon(Icons.ios_share, size: 16),
                  label: Text(
                      coSuKienLap ? 'Xuất .ics ($soNamChon năm)' : 'Xuất .ics'),
                ),
              ],
            );
          },
        );
      },
    );

    if (action == null) return false;
    if (action == 'native_1y') {
      return xuatSuKien(dsSuKien.first);
    }
    return IcsService.xuatFileIcs(dsSuKien, soNam: soNamChon);
  }
}
