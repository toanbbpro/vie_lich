import 'package:tyme/tyme.dart';
import 'lunar_vn.dart';

class AmLichHelper {
  // ============================================================
  // BẢNG CHUYỂN ĐỔI SANG TIẾNG VIỆT
  // ============================================================

  static const Map<String, String> _canChiMap = {
    '甲子': 'Giáp Tý',
    '乙丑': 'Ất Sửu',
    '丙寅': 'Bính Dần',
    '丁卯': 'Đinh Mão',
    '戊辰': 'Mậu Thìn',
    '己巳': 'Kỷ Tỵ',
    '庚午': 'Canh Ngọ',
    '辛未': 'Tân Mùi',
    '壬申': 'Nhâm Thân',
    '癸酉': 'Quý Dậu',
    '甲戌': 'Giáp Tuất',
    '乙亥': 'Ất Hợi',
    '丙子': 'Bính Tý',
    '丁丑': 'Đinh Sửu',
    '戊寅': 'Mậu Dần',
    '己卯': 'Kỷ Mão',
    '庚辰': 'Canh Thìn',
    '辛巳': 'Tân Tỵ',
    '壬午': 'Nhâm Ngọ',
    '癸未': 'Quý Mùi',
    '甲申': 'Giáp Thân',
    '乙酉': 'Ất Dậu',
    '丙戌': 'Bính Tuất',
    '丁亥': 'Đinh Hợi',
    '戊子': 'Mậu Tý',
    '己丑': 'Kỷ Sửu',
    '庚寅': 'Canh Dần',
    '辛卯': 'Tân Mão',
    '壬辰': 'Nhâm Thìn',
    '癸巳': 'Quý Tỵ',
    '甲午': 'Giáp Ngọ',
    '乙未': 'Ất Mùi',
    '丙申': 'Bính Thân',
    '丁酉': 'Đinh Dậu',
    '戊戌': 'Mậu Tuất',
    '己亥': 'Kỷ Hợi',
    '庚子': 'Canh Tý',
    '辛丑': 'Tân Sửu',
    '壬寅': 'Nhâm Dần',
    '癸卯': 'Quý Mão',
    '甲辰': 'Giáp Thìn',
    '乙巳': 'Ất Tỵ',
    '丙午': 'Bính Ngọ',
    '丁未': 'Đinh Mùi',
    '戊申': 'Mậu Thân',
    '己酉': 'Kỷ Dậu',
    '庚戌': 'Canh Tuất',
    '辛亥': 'Tân Hợi',
    '壬子': 'Nhâm Tý',
    '癸丑': 'Quý Sửu',
    '甲寅': 'Giáp Dần',
    '乙卯': 'Ất Mão',
    '丙辰': 'Bính Thìn',
    '丁巳': 'Đinh Tỵ',
    '戊午': 'Mậu Ngọ',
    '己未': 'Kỷ Mùi',
    '庚申': 'Canh Thân',
    '辛酉': 'Tân Dậu',
    '壬戌': 'Nhâm Tuất',
    '癸亥': 'Quý Hợi',
  };

  static const Map<String, String> _tietKhiMap = {
    '立春': 'Lập Xuân',
    '雨水': 'Vũ Thủy',
    '惊蛰': 'Kinh Trập',
    '春分': 'Xuân Phân',
    '清明': 'Thanh Minh',
    '谷雨': 'Cốc Vũ',
    '立夏': 'Lập Hạ',
    '小满': 'Tiểu Mãn',
    '芒种': 'Mang Chủng',
    '夏至': 'Hạ Chí',
    '小暑': 'Tiểu Thử',
    '大暑': 'Đại Thử',
    '立秋': 'Lập Thu',
    '处暑': 'Xử Thử',
    '白露': 'Bạch Lộ',
    '秋分': 'Thu Phân',
    '寒露': 'Hàn Lộ',
    '霜降': 'Sương Giáng',
    '立冬': 'Lập Đông',
    '小雪': 'Tiểu Tuyết',
    '大雪': 'Đại Tuyết',
    '冬至': 'Đông Chí',
    '小寒': 'Tiểu Hàn',
    '大寒': 'Đại Hàn',
  };

  static const Map<String, String> _saoMap = {
    '四相': 'Tứ Tướng',
    '王日': 'Vương Nhật',
    '月空': 'Nguyệt Không',
    '官日': 'Quan Nhật',
    '敬安': 'Kính An',
    '金匮': 'Kim Quỹ',
    '鸣吠对': 'Minh Phệ Đối',
    '月德合': 'Nguyệt Đức Hợp',
    '阴德': 'Âm Đức',
    '守日': 'Thủ Nhật',
    '吉期': 'Cát Kỳ',
    '六合': 'Lục Hợp',
    '不将': 'Bất Tướng',
    '普护': 'Phổ Hộ',
    '宝光': 'Bảo Quang',
    '时德': 'Thời Đức',
    '相日': 'Tướng Nhật',
    '驿马': 'Dịch Mã',
    '天后': 'Thiên Hậu',
    '天马': 'Thiên Mã',
    '天巫': 'Thiên Vu',
    '福德': 'Phúc Đức',
    '福生': 'Phúc Sinh',
    '五合': 'Ngũ Hợp',
    '天恩': 'Thiên Ân',
    '民日': 'Dân Nhật',
    '天仓': 'Thiên Thương',
    '金堂': 'Kim Đường',
    '天德': 'Thiên Đức',
    '月德': 'Nguyệt Đức',
    '月恩': 'Nguyệt Ân',
    '三合': 'Tam Hợp',
    '时阴': 'Thời Âm',
    '六仪': 'Lục Nghi',
    '玉堂': 'Ngọc Đường',
    '解神': 'Giải Thần',
    '鸣吠': 'Minh Phệ',
    '母仓': 'Mẫu Thương',
    '阳德': 'Dương Đức',
    '五富': 'Ngũ Phú',
    '生气': 'Sinh Khí',
    '除神': 'Trừ Thần',
    '司命': 'Ty Mệnh',
    '天德合': 'Thiên Đức Hợp',
    '临日': 'Lâm Nhật',
    '天喜': 'Thiên Hỷ',
    '天医': 'Thiên Y',
    '圣心': 'Thánh Tâm',
    '青龙': 'Thanh Long',
    '益后': 'Ích Hậu',
    '明堂': 'Minh Đường',
    '续世': 'Tục Thế',
    '要安': 'Yếu An',
    '玉宇': 'Ngọc Vũ',
    '时阳': 'Thời Dương',
    '天愿': 'Thiên Nguyện',
    '天赦': 'Thiên Xá',
    '天符': 'Thiên Phù',
    '天乙': 'Thiên Ất',
    '天官': 'Thiên Quan',
    '五帝': 'Ngũ Đế',
    '天宝': 'Thiên Bảo',
    '大明': 'Đại Minh',
    '七圣': 'Thất Thánh',
    '神在': 'Thần Tại',
    '福厚': 'Phúc Hậu',
    '岁德': 'Tuế Đức',
    '岁德合': 'Tuế Đức Hợp',
    '岁支德': 'Tuế Chi Đức',
    '龙德': 'Long Đức',
    '月忌': 'Nguyệt Kỵ',
    '游祸': 'Du Họa',
    '血支': 'Huyết Chi',
    '重日': 'Trùng Nhật',
    '朱雀': 'Chu Tước',
    '月建': 'Nguyệt Kiến',
    '小时': 'Tiểu Thời',
    '土府': 'Thổ Phủ',
    '月厌': 'Nguyệt Yếm',
    '地火': 'Địa Hỏa',
    '触水龙': 'Xúc Thủy Long',
    '三丧': 'Tam Tang',
    '鬼哭': 'Quỷ Khốc',
    '大退': 'Đại Thoái',
    '五虚': 'Ngũ Hư',
    '归忌': 'Quy Kỵ',
    '白虎': 'Bạch Hổ',
    '灾煞': 'Tai Sát',
    '天火': 'Thiên Hỏa',
    '复日': 'Phục Nhật',
    '河魁': 'Hà Khôi',
    '死神': 'Tử Thần',
    '月煞': 'Nguyệt Sát',
    '月虚': 'Nguyệt Hư',
    '厌对': 'Yếm Đối',
    '招摇': 'Chiêu Dao',
    '死气': 'Tử Khí',
    '九坎': 'Cửu Khảm',
    '九焦': 'Cửu Tiêu',
    '月害': 'Nguyệt Hại',
    '大时': 'Đại Thời',
    '大败': 'Đại Bại',
    '咸池': 'Hàm Trì',
    '小耗': 'Tiểu Hao',
    '天牢': 'Thiên Lao',
    '月破': 'Nguyệt Phá',
    '大耗': 'Đại Hao',
    '四击': 'Tứ Kích',
    '九空': 'Cửu Không',
    '元武': 'Nguyên Vũ',
    '五离': 'Ngũ Ly',
    '大煞': 'Đại Sát',
    '勾陈': 'Câu Trần',
    '天罡': 'Thiên Cương',
    '月刑': 'Nguyệt Hình',
    '天吏': 'Thiên Lại',
    '致死': 'Chí Tử',
    '土符': 'Thổ Phù',
    '血忌': 'Huyết Kỵ',
    '天刑': 'Thiên Hình',
    '逐阵': 'Trục Trận',
    '往亡': 'Vãng Vong',
    '劫煞': 'Kiếp Sát',
    '天贼': 'Thiên Tặc',
    '四废': 'Tứ Phế',
    '八专': 'Bát Chuyên',
    '阳破阴冲': 'Dương Phá Âm Xung',
    '阴错': 'Âm Thác',
    '四耗': 'Tứ Hao',
    '阳错': 'Dương Thác',
    '八风': 'Bát Phong',
    '三阴': 'Tam Âm',
    '四忌': 'Tứ Kỵ',
    '八龙': 'Bát Long',
    '地囊': 'Địa Nang',
    '大会': 'Đại Hội',
    '四穷': 'Tứ Cùng',
    '小会': 'Tiểu Hội',
    '孤辰': 'Cô Thần',
    '单阴': 'Đơn Âm',
    '七鸟': 'Thất Điểu',
    '行狠': 'Hành Ngoan',
    '岁薄': 'Tuế Bạc',
    '了戾': 'Liễu Lệ',
    '阴阳击冲': 'Âm Dương Kích Xung',
    '天狗': 'Thiên Cẩu',
    '七符': 'Thất Phù',
    '九虎': 'Cửu Hổ',
    '阴位': 'Âm Vị',
    '绝阳': 'Tuyệt Dương',
    '纯阴': 'Thuần Âm',
    '六蛇': 'Lục Xà',
    '阳错阴冲': 'Dương Thác Âm Xung',
    '阴阳交破': 'Âm Dương Giao Phá',
    '天棒': 'Thiên Bổng',
    '天瘟': 'Thiên Ôn',
    '天耗': 'Thiên Hao',
    '地耗': 'Địa Hao',
    '月耗': 'Nguyệt Hao',
    '时耗': 'Thời Hao',
    '飞廉': 'Phi Liêm',
    '披麻': 'Phi Ma',
    '黄砂': 'Hoàng Sa',
    '玄武': 'Huyền Vũ',
    '阳位': 'Dương Vị',
    '寡宿': 'Quả Tú',
    '五墓': 'Ngũ Mộ',
  };

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

  /// Dịch Can Chi từ Hán sang Việt
  static String _chuyenCanChiSangViet(String han) {
    if (han.isEmpty) return '';
    final clean = han.replaceAll(RegExp(r'[日月年]'), '').trim();
    if (_canChiMap.containsKey(clean)) return _canChiMap[clean]!;
    if (clean.length >= 2) {
      final twoChar = clean.substring(0, 2);
      if (_canChiMap.containsKey(twoChar)) return _canChiMap[twoChar]!;
    }
    return han;
  }

  static String _dichTenSao(String han) {
    if (han.isEmpty) return '';
    final clean = han.replaceAll(RegExp(r'[日月年]'), '').trim();
    if (_saoMap.containsKey(clean)) return _saoMap[clean]!;
    if (_saoMap.containsKey(han)) return _saoMap[han]!;
    return '';
  }

  // ============================================================
  // CHUYỂN ĐỔI ÂM - DƯƠNG (dùng tyme để tra cứu can chi/sao)
  // ============================================================

  static LunarDay? duongSangAm(DateTime duongLich) {
    try {
      final solarDay = SolarDay.fromYmd(
        duongLich.year,
        duongLich.month,
        duongLich.day,
      );
      return solarDay.getLunarDay();
    } catch (e) {
      return null;
    }
  }

  static DateTime? amSangDuong(int nam, int thang, int ngay) {
    try {
      final lunarDay = LunarDay.fromYmd(nam, thang, ngay);
      final solarDay = lunarDay.getSolarDay();
      return DateTime(
        solarDay.getYear(),
        solarDay.getMonth(),
        solarDay.getDay(),
      );
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // CHUỖI NGÀY ÂM (dùng code VN để thống nhất)
  // ============================================================

  /// Lấy đối tượng LunarDate VN
  static LunarDate layLunarDateVN(DateTime duongLich) {
    return LunarSolarConverter.solarToLunar(duongLich);
  }

  static String layNgayAmNgan(LunarDay lunar) {
    return '${lunar.getDay()}/${lunar.getMonth()}';
  }

  static String layNgayAmDayDu(LunarDay lunar) {
    return '${lunar.getDay()} tháng ${lunar.getMonth()}';
  }

  static String layTenThang(int thangAm) {
    const tenThang = [
      '',
      'Giêng',
      'Hai',
      'Ba',
      'Tư',
      'Năm',
      'Sáu',
      'Bảy',
      'Tám',
      'Chín',
      'Mười',
      'Mười một',
      'Chạp'
    ];
    if (thangAm >= 1 && thangAm <= 12) {
      return 'Tháng ${tenThang[thangAm]}';
    }
    return 'Tháng $thangAm';
  }

  static String layTenNgay(int ngayAm) {
    if (ngayAm == 1) return 'Mùng 1';
    if (ngayAm <= 10) return 'Mùng $ngayAm';
    if (ngayAm == 15) return 'Rằm';
    if (ngayAm == 30) return 'Ba mươi';
    if (ngayAm == 29) return 'Hai chín';
    return '$ngayAm';
  }

  // ============================================================
  // CAN CHI (dùng code VN để chính xác cho múi giờ VN)
  // ============================================================

  static String layCanChiNgay(LunarDay lunar) {
    try {
      return _chuyenCanChiSangViet(lunar.getSixtyCycleDay().getName());
    } catch (e) {
      return '';
    }
  }

  static String layCanChiThang(LunarDay lunar) {
    try {
      return _chuyenCanChiSangViet(
          lunar.getSixtyCycleDay().getMonth().getName());
    } catch (e) {
      return '';
    }
  }

  static String layCanChiNam(LunarDay lunar) {
    try {
      return _chuyenCanChiSangViet(
          lunar.getSixtyCycleDay().getYear().getName());
    } catch (e) {
      return '';
    }
  }

  static String layConGiap(LunarDay lunar) {
    try {
      return _chuyenCanChiSangViet(
          lunar.getSixtyCycleDay().getYear().getEarthBranch().getName());
    } catch (e) {
      return '';
    }
  }

  static String layChuoiCanChiDayDu(LunarDay lunar) {
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
  // TIẾT KHÍ
  // ============================================================

  static String layTietKhi(DateTime duongLich) {
    try {
      final solarDay = SolarDay.fromYmd(
        duongLich.year,
        duongLich.month,
        duongLich.day,
      );
      final han = solarDay.getTerm().getName();
      return _tietKhiMap[han] ?? han;
    } catch (e) {
      return '';
    }
  }

  // ============================================================
  // SAO TỐT / XẤU
  // ============================================================

  static List<String> laySaoTot(LunarDay lunar) {
    try {
      final list = lunar
          .getGods()
          .where((god) => god.getLuck().getName() == '吉')
          .map((god) => _dichTenSao(god.getName()))
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();
      return list.take(8).toList();
    } catch (e) {
      return [];
    }
  }

  static List<String> laySaoXau(LunarDay lunar) {
    try {
      final list = lunar
          .getGods()
          .where((god) => god.getLuck().getName() == '凶')
          .map((god) => _dichTenSao(god.getName()))
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();
      return list.take(8).toList();
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // NGÀY LỄ VIỆT NAM (dùng code thuần VN)
  // ============================================================

  /// Trả về danh sách các ngày lễ VN trong ngày được chỉ định.
  /// Bao gồm cả lễ âm lịch (Tết, Giỗ Tổ,...) và lễ dương lịch (2/9, 20/11,...).
  static List<String> layNgayLe(DateTime duongLich, LunarDay lunar) {
    final ds = <String>{};

    // 1. Lễ DƯƠNG LỊCH VN (cố định theo ngày/tháng dương)
    final keyDuong = '${duongLich.day}/${duongLich.month}';
    if (_leDuongLichVN.containsKey(keyDuong)) {
      ds.add(_leDuongLichVN[keyDuong]!);
    }

    // 2. Lễ ÂM LỊCH VN (dùng thuật toán Hồ Ngọc Đức)
    try {
      final lunarVN = LunarSolarConverter.solarToLunar(duongLich);
      final holiday = lunarVN.holiday;
      if (holiday != null && holiday.isNotEmpty) {
        ds.add(holiday);
      }
    } catch (_) {}

    return ds.toList();
  }

  // ============================================================
  // TIỆN ÍCH KHÁC
  // ============================================================

  static bool laNgayRamHoacMung1(LunarDay lunar) {
    final ngay = lunar.getDay();
    return ngay == 1 || ngay == 15;
  }

  static bool laThangNhuan(LunarDay lunar) {
    try {
      final lm = LunarMonth.fromYm(lunar.getYear(), lunar.getMonth());
      return lm.isLeap();
    } catch (e) {
      return false;
    }
  }
}
