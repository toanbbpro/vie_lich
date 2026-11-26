import 'package:flutter_test/flutter_test.dart';
import 'package:vie_lich/models/su_kien.dart';
import 'package:vie_lich/services/ics_service.dart';
import 'package:vie_lich/services/ram_mung1_settings.dart';

void main() {
  group('IcsService - Xuất & Nhập lịch .ics đa năm', () {
    test('Xuất đúng số năm (1, 3, 5, 10) và xử lý tháng thiếu 29 ngày', () {
      final sk = SuKien(
        id: 'gio-ong-noi',
        ten: 'Giỗ Ông Nội',
        ngayAm: 10,
        thangAm: 3,
        baoTruoc: 3,
        gioNhac: 11,
        phutNhac: 30,
        tag: 'Giỗ, Bên nội',
        ghiChu: 'Chuẩn bị hương hoa; mâm cỗ, mời họ hàng',
      );

      for (final nam in IcsService.cacLuaChonSoNam) {
        final ics = IcsService.taoNoiDungIcs(
          [sk],
          soNam: nam,
          now: DateTime(2026, 1, 1),
        );
        final countVEvent = 'BEGIN:VEVENT'.allMatches(ics).length;
        expect(countVEvent, nam);
        // báo trước 3 ngày lúc 11:30 => 690 - 4320 = -3630 phút = -P2DT12H30M
        expect(ics, contains('TRIGGER:-P2DT12H30M'));
      }

      // Tháng Chạp năm Giáp Thìn (2024) là tháng thiếu (29 ngày: kết thúc 28/01/2025).
      // Sự kiện ngày 30/12 âm phải lùi về 28/01/2025 chứ không tràn sang Mùng 1 Tết (29/01/2025).
      final ngayTatNien2024 = IcsService.tinhNgayDuongTheoNamAm(2024, 12, 30);
      expect(ngayTatNien2024, DateTime(2025, 1, 28));
    });

    test('Round-trip Xuất 5 năm -> Nhập ngược tự gộp trùng và giữ nguyên thuộc tính', () {
      final goc = [
        SuKien(
          id: 'sk-1',
          ten: 'Giỗ Cụ Tổ, nhánh trưởng; họ Lê',
          ngayAm: 15,
          thangAm: 7,
          baoTruoc: 5,
          gioNhac: 9,
          phutNhac: 15,
          ghiChu: 'Dòng 1\nDòng 2 có dấu phẩy, chấm phẩy; và gạch chéo \\',
          tag: 'Giỗ, Bên nội',
        ),
        SuKien(
          id: 'sk-2',
          ten: 'Sinh nhật Bé Bơ',
          ngayAm: 2,
          thangAm: 8,
          baoTruoc: 1,
          gioNhac: 8,
          phutNhac: 0,
          tag: 'Cá nhân',
        ),
      ];

      final ics = IcsService.taoNoiDungIcs(
        goc,
        soNam: 5,
        now: DateTime(2026, 1, 1),
      );
      expect('BEGIN:VEVENT'.allMatches(ics).length, 10);

      final nhapLai = IcsService.parseNoiDungIcs(ics);
      expect(nhapLai, hasLength(2));

      expect(nhapLai[0].ten, goc[0].ten);
      expect(nhapLai[0].ngayAm, 15);
      expect(nhapLai[0].thangAm, 7);
      expect(nhapLai[0].namAm, isNull);
      expect(nhapLai[0].baoTruoc, 5);
      expect(nhapLai[0].gioNhac, 9);
      expect(nhapLai[0].phutNhac, 15);
      expect(nhapLai[0].ghiChu, goc[0].ghiChu);
      expect(nhapLai[0].tag, 'Giỗ, Bên nội');

      expect(nhapLai[1].ten, 'Sinh nhật Bé Bơ');
      expect(nhapLai[1].ngayAm, 2);
      expect(nhapLai[1].thangAm, 8);
    });

    test('Nhập file .ics chuẩn từ Google/Apple Calendar bên ngoài', () {
      const externalIcs = 'BEGIN:VCALENDAR\r\n'
          'VERSION:2.0\r\n'
          'BEGIN:VEVENT\r\n'
          'UID:google-event-123@google.com\r\n'
          'DTSTART;VALUE=DATE:20260217\r\n'
          'DTEND;VALUE=DATE:20260218\r\n'
          'SUMMARY:Họp mặt đầu xuân\r\n'
          'DESCRIPTION:Gặp mặt đại gia đình\r\n'
          'CATEGORIES:Lễ Tết\r\n'
          'END:VEVENT\r\n'
          'END:VCALENDAR\r\n';

      final parsed = IcsService.parseNoiDungIcs(externalIcs);
      expect(parsed, hasLength(1));
      // 17/02/2026 dương lịch là Mùng 1 Tết Bính Ngọ (1/1 âm lịch)
      expect(parsed.first.ten, 'Họp mặt đầu xuân');
      expect(parsed.first.ngayAm, 1);
      expect(parsed.first.thangAm, 1);
      expect(parsed.first.ghiChu, 'Gặp mặt đại gia đình');
      expect(parsed.first.tag, 'Lễ Tết');
    });
  });

  group('RamMung1Settings - Tính lịch nhắc Mùng 1 & Rằm hằng tháng', () {
    test('Tính đúng chiều hôm trước (kể cả tháng thiếu 29 ngày) và sáng đúng ngày', () {
      const cfg = RamMung1Config(
        enabled: true,
        before1Day: true,
        beforeHour: 18,
        beforeMinute: 0,
        onDay: true,
        onDayHour: 6,
        onDayMinute: 0,
      );

      // Ngày 27/01/2025 (28 tháng Chạp năm Giáp Thìn - tháng thiếu chỉ có 29 ngày).
      // Mùng 1 Tết Ất Tỵ là 29/01/2025 => nhắc trước 1 ngày phải rơi vào 18:00 ngày 28/01/2025!
      final mocs = RamMung1Settings.tinhCacMocNhacTiepTheo(
        cfg,
        DateTime(2025, 1, 27, 10, 0),
        soKy: 4,
      );

      expect(mocs.length, 8);
      expect(mocs[0].laNhacTruoc, isTrue);
      expect(mocs[0].thoiGianBao, DateTime(2025, 1, 28, 18, 0));
      expect(mocs[0].ngayAm, 1);
      expect(mocs[0].thangAm, 1);

      expect(mocs[1].laNhacTruoc, isFalse);
      expect(mocs[1].thoiGianBao, DateTime(2025, 1, 29, 6, 0));
      expect(mocs[1].ngayAm, 1);
      expect(mocs[1].thangAm, 1);

      // Kỳ tiếp theo là Rằm tháng Giêng (12/02/2025 dương lịch)
      expect(mocs[2].laNhacTruoc, isTrue);
      expect(mocs[2].thoiGianBao, DateTime(2025, 2, 11, 18, 0));
      expect(mocs[2].ngayAm, 15);
      expect(mocs[3].thoiGianBao, DateTime(2025, 2, 12, 6, 0));
    });
  });
}
