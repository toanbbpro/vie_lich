import 'package:add_2_calendar/add_2_calendar.dart';
import '../models/su_kien.dart';
import '../utils/lunar_vn.dart';

class CalendarExport {
  /// Trả về ngày dương của sự kiện âm lịch trong tương lai gần nhất.
  /// Nếu năm nay đã qua, dùng năm sau.
  static DateTime? tinhNgaySuKien(SuKien suKien) {
    final now = DateTime.now();
    try {
      // Thử năm nay trước
      var ngay = LunarSolarConverter.lunarToSolar(
        suKien.ngayAm,
        suKien.thangAm,
        now.year,
      );
      // Nếu ngày đã qua, thử năm sau
      if (ngay.isBefore(DateTime(now.year, now.month, now.day))) {
        ngay = LunarSolarConverter.lunarToSolar(
          suKien.ngayAm,
          suKien.thangAm,
          now.year + 1,
        );
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

  /// Xuất sự kiện sang lịch hệ thống (Google Calendar / Apple Calendar).
  /// Trả về true nếu thành công.
  static Future<bool> xuatSuKien(SuKien suKien) async {
    try {
      final ngayBao = tinhNgayBao(suKien);
      if (ngayBao == null) return false;

      final moTa = StringBuffer();
      if (suKien.ghiChu != null && suKien.ghiChu!.isNotEmpty) {
        moTa.writeln(suKien.ghiChu);
        moTa.writeln();
      }
      moTa.writeln('Ngày âm: ${suKien.ngayAm}/${suKien.thangAm}');
      moTa.writeln('Báo trước: ${suKien.baoTruoc} ngày');

      final event = Event(
        title: '[Nhắc] ${suKien.ten}',
        description: moTa.toString(),
        startDate: ngayBao,
        endDate: ngayBao.add(const Duration(hours: 1)),
        allDay: true,
      );

      await Add2Calendar.addEvent2Cal(event);
      return true;
    } catch (e) {
      return false;
    }
  }
}
