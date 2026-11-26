import 'package:full_calender/enums/branch.dart';
import 'package:full_calender/enums/language_name.dart';
import 'package:full_calender/enums/solar_term.dart';
import 'package:full_calender/enums/time_zone.dart';
import 'package:full_calender/full_calender.dart';
import 'package:full_calender/full_calender_extension.dart';
import 'package:full_calender/models/lunar_date_time.dart';
import 'lunar_vn.dart';

class AmLichHelper {
  static final int _vnTimeZone = TimeZone.vietnamese.timezone; // UTC+7

  /// Khung giờ 12 Địa Chi (theo thứ tự Branch.rat -> Branch.pig)
  static const List<String> _khungGioChi = [
    'Tý (23h–1h)',
    'Sửu (1h–3h)',
    'Dần (3h–5h)',
    'Mão (5h–7h)',
    'Thìn (7h–9h)',
    'Tỵ (9h–11h)',
    'Ngọ (11h–13h)',
    'Mùi (13h–15h)',
    'Thân (15h–17h)',
    'Dậu (17h–19h)',
    'Tuất (19h–21h)',
    'Hợi (21h–23h)',
  ];

  /// Lễ DƯƠNG LỊCH Việt Nam (ngày/tháng cố định)
  static const Map<String, String> _leDuongLichVN = {
    '1/1': 'Tết Dương lịch',
    '14/2': 'Lễ Tình nhân (Valentine)',
    '27/2': 'Ngày Thầy thuốc Việt Nam',
    '8/3': 'Quốc tế Phụ nữ',
    '26/3': 'Ngày thành lập Đoàn TNCS Hồ Chí Minh',
    '30/4': 'Ngày Giải phóng miền Nam',
    '1/5': 'Quốc tế Lao động',
    '7/5': 'Chiến thắng Điện Biên Phủ',
    '19/5': 'Ngày sinh Chủ tịch Hồ Chí Minh',
    '1/6': 'Quốc tế Thiếu nhi',
    '28/6': 'Ngày Gia đình Việt Nam',
    '27/7': 'Ngày Thương binh - Liệt sĩ',
    '19/8': 'Ngày Cách mạng Tháng Tám',
    '2/9': 'Quốc khánh',
    '10/10': 'Ngày Giải phóng Thủ đô',
    '14/10': 'Ngày Truyền thống Hội Nông dân',
    '20/10': 'Ngày Phụ nữ Việt Nam',
    '7/11': 'Ngày Truyền thống Công đoàn VN',
    '20/11': 'Ngày Nhà giáo Việt Nam',
    '22/12': 'Ngày thành lập QĐND Việt Nam',
    '24/12': 'Đêm Giáng sinh',
    '25/12': 'Lễ Giáng sinh',
  };

  // ============================================================
  // CHUYỂN ĐỔI ÂM - DƯƠNG (chuẩn Việt Nam UTC+7)
  // ============================================================

  static LunarDateTime? duongSangAm(DateTime duongLich) {
    try {
      return FullCalender(
        date: DateTime(duongLich.year, duongLich.month, duongLich.day),
        timeZone: _vnTimeZone,
      ).lunarDate;
    } catch (e) {
      return null;
    }
  }

  static DateTime? amSangDuong(
    int nam,
    int thang,
    int ngay, {
    bool isLeap = false,
  }) {
    try {
      return FullCalenderExtension.convertLunarDateToSolarDate(
        LunarDateTime(
          year: nam,
          month: thang,
          day: ngay,
          isLeap: isLeap,
          timeZone: _vnTimeZone,
        ),
        _vnTimeZone,
      );
    } catch (e) {
      return null;
    }
  }

  static LunarDate layLunarDateVN(DateTime duongLich) {
    return LunarSolarConverter.solarToLunar(duongLich);
  }

  static String layNgayAmNgan(LunarDateTime lunar) {
    return '${lunar.day}/${lunar.month}';
  }

  static String layNgayAmDayDu(LunarDateTime lunar) {
    return '${lunar.day} tháng ${lunar.month}';
  }

  static String layTenThang(int thangAm) {
    const tenThang = {
      1: 'Tháng Giêng',
      2: 'Tháng Hai',
      3: 'Tháng Ba',
      4: 'Tháng Tư',
      5: 'Tháng Năm',
      6: 'Tháng Sáu',
      7: 'Tháng Bảy',
      8: 'Tháng Tám',
      9: 'Tháng Chín',
      10: 'Tháng Mười',
      11: 'Tháng Một',
      12: 'Tháng Chạp',
    };
    return tenThang[thangAm] ?? 'Tháng $thangAm';
  }

  static String layTenNgay(int ngayAm) {
    if (ngayAm <= 10) return 'Mùng $ngayAm';
    return 'Ngày $ngayAm';
  }

  // ============================================================
  // CAN CHI (VIỆT HÓA 100%)
  // ============================================================

  static String layCanChiNgay(LunarDateTime lunar) {
    try {
      return lunar.stemBranchOfDay.name(LanguageName.vietNam);
    } catch (e) {
      return '';
    }
  }

  static String layCanChiThang(LunarDateTime lunar) {
    try {
      return lunar.stemBranchOfMonth.name(LanguageName.vietNam);
    } catch (e) {
      return '';
    }
  }

  static String layCanChiNam(LunarDateTime lunar) {
    try {
      return lunar.stemBranchOfYear.name(LanguageName.vietNam);
    } catch (e) {
      return '';
    }
  }

  static String layConGiap(LunarDateTime lunar) {
    try {
      return lunar.stemBranchOfYear.branch.vietnameseName;
    } catch (e) {
      return '';
    }
  }

  static String layChuoiCanChiDayDu(LunarDateTime lunar) {
    final ngay = layCanChiNgay(lunar);
    final thang = layCanChiThang(lunar);
    final nam = layCanChiNam(lunar);
    final parts = <String>[];
    if (ngay.isNotEmpty) parts.add('Ngày $ngay');
    if (thang.isNotEmpty) parts.add('tháng $thang');
    if (nam.isNotEmpty) parts.add('năm $nam');
    return parts.join(', ');
  }

  // ============================================================
  // TIẾT KHÍ & NGÀY / GIỜ HOÀNG ĐẠO
  // ============================================================

  static String layTietKhi(DateTime duongLich) {
    try {
      return FullCalender(
        date: DateTime(duongLich.year, duongLich.month, duongLich.day),
        timeZone: _vnTimeZone,
      ).solarTerm.vietnameseName;
    } catch (e) {
      return '';
    }
  }

  static bool laNgayHoangDao(LunarDateTime lunar) {
    try {
      return lunar.isLuckyDay;
    } catch (e) {
      return false;
    }
  }

  static List<String> layGioHoangDao(LunarDateTime lunar) {
    try {
      final flags = lunar.listLuckyHours;
      final ketQua = <String>[];
      for (int i = 0; i < flags.length && i < _khungGioChi.length; i++) {
        if (flags[i]) {
          ketQua.add(_khungGioChi[i]);
        }
      }
      return ketQua;
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // NGÀY LỄ VIỆT NAM
  // ============================================================

  /// Trả về danh sách các ngày lễ VN trong ngày được chỉ định
  /// (bao gồm lễ Dương lịch, lễ Âm lịch VN và ngày bắt đầu Tiết Thanh Minh).
  static List<String> layNgayLe(DateTime duongLich, LunarDateTime lunar) {
    final ds = <String>{};

    // 1. Lễ DƯƠNG LỊCH VN (cố định theo ngày/tháng dương)
    final keyDuong = '${duongLich.day}/${duongLich.month}';
    if (_leDuongLichVN.containsKey(keyDuong)) {
      ds.add(_leDuongLichVN[keyDuong]!);
    }

    // 2. Lễ ÂM LỊCH VN (theo danh sách thuần Việt)
    final lunarVN = LunarDate(
      day: lunar.day,
      month: lunar.month,
      year: lunar.year,
      isLeap: lunar.isLeap,
    );
    final holiday = lunarVN.holiday;
    if (holiday != null && holiday.isNotEmpty) {
      ds.add(holiday);
    }

    // 3. Tiết Thanh Minh (ngày đầu tiên chuyển sang Tiết Thanh Minh)
    try {
      final today = DateTime(duongLich.year, duongLich.month, duongLich.day);
      final termToday = FullCalender(date: today, timeZone: _vnTimeZone).solarTerm;
      if (termToday == SolarTerm.pureBrightness) {
        final yesterday = today.subtract(const Duration(days: 1));
        final termYesterday =
            FullCalender(date: yesterday, timeZone: _vnTimeZone).solarTerm;
        if (termYesterday != SolarTerm.pureBrightness) {
          ds.add('Tiết Thanh Minh (Tảo mộ)');
        }
      }
    } catch (_) {}

    return ds.toList();
  }

  // ============================================================
  // TIỆN ÍCH KHÁC
  // ============================================================

  static bool laNgayRamHoacMung1(LunarDateTime lunar) {
    return lunar.day == 1 || lunar.day == 15;
  }

  static bool laThangNhuan(LunarDateTime lunar) {
    return lunar.isLeap;
  }
}
