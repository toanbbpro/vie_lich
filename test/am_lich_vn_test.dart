import 'package:flutter_test/flutter_test.dart';
import 'package:vie_lich/utils/am_lich_helper.dart';

void main() {
  group('AmLichHelper (VN UTC+7)', () {
    test('Chuyển đổi Dương <-> Âm chuẩn Tết Nguyên Đán 2025, 2026, 2027', () {
      final tet2025 = AmLichHelper.duongSangAm(DateTime(2025, 1, 29))!;
      expect(tet2025.day, 1);
      expect(tet2025.month, 1);
      expect(tet2025.year, 2025);
      expect(AmLichHelper.layCanChiNam(tet2025), 'Ất Tỵ');

      final tet2026 = AmLichHelper.duongSangAm(DateTime(2026, 2, 17))!;
      expect(tet2026.day, 1);
      expect(tet2026.month, 1);
      expect(tet2026.year, 2026);
      expect(AmLichHelper.layCanChiNam(tet2026), 'Bính Ngọ');

      final backToSolar = AmLichHelper.amSangDuong(2027, 1, 1);
      expect(backToSolar, DateTime(2027, 2, 6));
    });

    test('Hiển thị đúng các ngày lễ Việt Nam mới và bỏ lễ TQ cũ', () {
      // Mùng 4 Tết 2026 (20/2/2026) -> Lễ hóa vàng
      final m4 = DateTime(2026, 2, 20);
      expect(
        AmLichHelper.layNgayLe(m4, AmLichHelper.duongSangAm(m4)!),
        contains('Lễ hóa vàng'),
      );

      // Mùng 7 Tết 2026 (23/2/2026) -> Lễ Khai Hạ
      final m7 = DateTime(2026, 2, 23);
      expect(
        AmLichHelper.layNgayLe(m7, AmLichHelper.duongSangAm(m7)!),
        contains('Lễ Khai Hạ'),
      );

      // Mùng 10 tháng Giêng 2026 (26/2/2026) -> Ngày vía Thần Tài
      final m10 = DateTime(2026, 2, 26);
      expect(
        AmLichHelper.layNgayLe(m10, AmLichHelper.duongSangAm(m10)!),
        contains('Ngày vía Thần Tài'),
      );

      // 20/8 âm 2026 (30/9/2026) -> Hội Kiếp Bạc - Giỗ Đức Thánh Trần
      final gioTran = AmLichHelper.amSangDuong(2026, 8, 20)!;
      expect(
        AmLichHelper.layNgayLe(gioTran, AmLichHelper.duongSangAm(gioTran)!),
        contains('Hội Kiếp Bạc - Giỗ Đức Thánh Trần'),
      );

      // 9/9 âm 2026 -> Không còn Tết Trùng Cửu
      final trungCuu = AmLichHelper.amSangDuong(2026, 9, 9)!;
      expect(
        AmLichHelper.layNgayLe(trungCuu, AmLichHelper.duongSangAm(trungCuu)!),
        isNot(contains('Tết Trùng Cửu')),
      );

      // Đêm Giao Thừa 2025 (29 Chạp, tháng thiếu: 28/1/2025)
      final giaoThua2025 = DateTime(2025, 1, 28);
      expect(
        AmLichHelper.layNgayLe(
            giaoThua2025, AmLichHelper.duongSangAm(giaoThua2025)!),
        contains('Lễ Tất Niên & Giao Thừa'),
      );
    });

    test('Nhận diện ngày đầu Tiết Thanh Minh trong năm 2026', () {
      // Thanh Minh 2026 rơi vào ngày 5/4/2026
      final thanhMinh = DateTime(2026, 4, 5);
      expect(AmLichHelper.layTietKhi(thanhMinh), 'Thanh Minh');
      expect(
        AmLichHelper.layNgayLe(
            thanhMinh, AmLichHelper.duongSangAm(thanhMinh)!),
        contains('Tiết Thanh Minh (Tảo mộ)'),
      );

      // Ngày hôm sau không bị lặp nhãn Tiết Thanh Minh
      final sauThanhMinh = DateTime(2026, 4, 6);
      expect(
        AmLichHelper.layNgayLe(
            sauThanhMinh, AmLichHelper.duongSangAm(sauThanhMinh)!),
        isNot(contains('Tiết Thanh Minh (Tảo mộ)')),
      );
    });

    test('Lấy Tiết khí, Ngày Hoàng Đạo/Hắc Đạo và Giờ Hoàng Đạo tiếng Việt', () {
      final ngay = DateTime(2026, 2, 17);
      final lunar = AmLichHelper.duongSangAm(ngay)!;

      expect(AmLichHelper.layTietKhi(ngay), isNotEmpty);
      expect(AmLichHelper.layChuoiCanChiDayDu(lunar), contains('Ngày'));
      expect(AmLichHelper.layGioHoangDao(lunar), hasLength(6));
      expect(AmLichHelper.laNgayHoangDao(lunar), isA<bool>());
    });
  });
}
