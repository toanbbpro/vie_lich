import 'dart:math';

/// Đối tượng chứa thông tin Ngày Âm Lịch
class LunarDate {
  final int day;
  final int month;
  final int year;
  final bool isLeap;

  LunarDate({
    required this.day,
    required this.month,
    required this.year,
    this.isLeap = false,
  });

  /// Can - Chi của Năm (vd: Bính Ngọ, Giáp Thìn)
  String get canChiYear {
    const can = [
      'Giáp',
      'Ất',
      'Bính',
      'Đinh',
      'Mậu',
      'Kỷ',
      'Canh',
      'Tân',
      'Nhâm',
      'Quý'
    ];
    const chi = [
      'Tý',
      'Sửu',
      'Dần',
      'Mão',
      'Thìn',
      'Tỵ',
      'Ngọ',
      'Mùi',
      'Thân',
      'Dậu',
      'Tuất',
      'Hợi'
    ];
    return '${can[(year + 6) % 10]} ${chi[(year + 8) % 12]}';
  }

  /// Can - Chi của Ngày
  String getCanChiDay(DateTime solarDate) {
    const can = [
      'Giáp',
      'Ất',
      'Bính',
      'Đinh',
      'Mậu',
      'Kỷ',
      'Canh',
      'Tân',
      'Nhâm',
      'Quý'
    ];
    const chi = [
      'Tý',
      'Sửu',
      'Dần',
      'Mão',
      'Thìn',
      'Tỵ',
      'Ngọ',
      'Mùi',
      'Thân',
      'Dậu',
      'Tuất',
      'Hợi'
    ];
    final jd = LunarSolarConverter.jdFromDate(
        solarDate.day, solarDate.month, solarDate.year);
    return '${can[(jd + 9) % 10]} ${chi[(jd + 1) % 12]}';
  }

  /// Can - Chi của Tháng
  String get canChiMonth {
    const can = [
      'Giáp',
      'Ất',
      'Bính',
      'Đinh',
      'Mậu',
      'Kỷ',
      'Canh',
      'Tân',
      'Nhâm',
      'Quý'
    ];
    const chi = [
      'Tý',
      'Sửu',
      'Dần',
      'Mão',
      'Thìn',
      'Tỵ',
      'Ngọ',
      'Mùi',
      'Thân',
      'Dậu',
      'Tuất',
      'Hợi'
    ];
    final canIndex = (year * 12 + month + 3) % 10;
    final chiIndex = (month + 1) % 12;
    return '${can[canIndex]} ${chi[chiIndex]}';
  }

  /// Tên ngày lễ truyền thống Việt Nam (nếu có)
  String? get holiday {
    if (isLeap) return null;

    final key = '$day/$month';
    const vietnameseHolidays = {
      '1/1': 'Mùng 1 Tết Nguyên Đán',
      '2/1': 'Mùng 2 Tết Nguyên Đán',
      '3/1': 'Mùng 3 Tết Nguyên Đán',
      '15/1': 'Tết Nguyên Tiêu',
      '3/3': 'Tết Hàn Thực',
      '10/3': 'Giỗ Tổ Hùng Vương',
      '15/4': 'Lễ Phật Đản',
      '5/5': 'Tết Đoan Ngọ',
      '7/7': 'Lễ Thất Tịch',
      '15/7': 'Lễ Vu Lan (Rằm tháng Bảy)',
      '15/8': 'Tết Trung Thu',
      '9/9': 'Tết Trùng Cửu',
      '10/10': 'Tết Trùng Thập',
      '15/10': 'Tết Hạ Nguyên',
      '23/12': 'Ông Công Ông Táo',
    };

    if (vietnameseHolidays.containsKey(key)) {
      return vietnameseHolidays[key];
    }

    if (month == 12) {
      final totalDays =
          LunarSolarConverter.getDaysInLunarMonth(month, year, isLeap);
      if (day == totalDays) {
        return 'Đêm Giao Thừa';
      }
    }

    return null;
  }

  @override
  String toString() {
    final leapStr = isLeap ? ' (Nhuận)' : '';
    return '$day/$month$leapStr/$year ($canChiYear)';
  }
}

/// Thuật toán chuyển đổi Thiên văn Hồ Ngọc Đức (Múi giờ UTC+7)
class LunarSolarConverter {
  static const double timeZone = 7.0;

  static int jdFromDate(int d, int m, int y) {
    final a = (14 - m) ~/ 12;
    final y1 = y + 4800 - a;
    final m1 = m + 12 * a - 3;
    var jd = d +
        ((153 * m1 + 2) ~/ 5) +
        365 * y1 +
        (y1 ~/ 4) -
        (y1 ~/ 100) +
        (y1 ~/ 400) -
        32045;
    if (jd < 2299161) {
      jd = d + ((153 * m1 + 2) ~/ 5) + 365 * y1 + (y1 ~/ 4) - 32083;
    }
    return jd;
  }

  static List<int> jdToDate(int jd) {
    int a, b, c, d, e, m, day, month, year;
    if (jd > 2299160) {
      a = jd + 32044;
      b = (4 * a + 3) ~/ 146097;
      c = a - (146097 * b) ~/ 4;
      d = (4 * c + 3) ~/ 1461;
      e = c - (1461 * d) ~/ 4;
      m = (5 * e + 2) ~/ 153;
      day = e - ((153 * m + 2) ~/ 5) + 1;
      month = m + 3 - 12 * (m ~/ 10);
      year = 100 * b + d - 4800 + (m ~/ 10);
    } else {
      c = jd + 32082;
      d = (4 * c + 3) ~/ 1461;
      e = c - (1461 * d) ~/ 4;
      m = (5 * e + 2) ~/ 153;
      day = e - ((153 * m + 2) ~/ 5) + 1;
      month = m + 3 - 12 * (m ~/ 10);
      year = d - 4800 + (m ~/ 10);
    }
    return [day, month, year];
  }

  static int _getNewMoonDay(int k) {
    final t = k / 1236.85;
    final t2 = t * t;
    final t3 = t2 * t;
    const dr = pi / 180;

    var jd1 =
        2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3;
    jd1 += 0.00033 * sin((166.56 + 132.87 * t - 0.009173 * t2) * dr);

    final m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3;
    final mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3;
    final f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3;

    var c1 = (0.1734 - 0.000393 * t) * sin(m * dr) + 0.0021 * sin(2 * dr * m);
    c1 -= 0.4068 * sin(mpr * dr) + 0.0161 * sin(2 * dr * mpr);
    c1 -= 0.0004 * sin(3 * dr * mpr);
    c1 += 0.0104 * sin(2 * dr * f) - 0.0051 * sin((m + mpr) * dr);
    c1 -= 0.0074 * sin((m - mpr) * dr) + 0.0004 * sin((2 * f + m) * dr);
    c1 -= 0.0004 * sin((2 * f - m) * dr) - 0.0006 * sin((2 * f + mpr) * dr);
    c1 += 0.0010 * sin((2 * f - mpr) * dr) + 0.0005 * sin((2 * mpr + m) * dr);

    final double deltat = (t < -11)
        ? 0.001 +
            0.000839 * t +
            0.0002261 * t2 -
            0.00000845 * t3 -
            0.000000081 * t * t3
        : -0.000278 + 0.000265 * t + 0.000262 * t2;

    final jdNew = jd1 + c1 - deltat;
    return (jdNew + 0.5 + timeZone / 24).floor();
  }

  static int _getSunLongitude(int dayNumber) {
    final t = (dayNumber - 2451545.5 - timeZone / 24) / 36525;
    final t2 = t * t;
    const dr = pi / 180;

    final m =
        357.52910 + 35999.05030 * t - 0.0001559 * t2 - 0.00000048 * t * t2;
    final l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2;
    var dl = (1.914600 - 0.004817 * t - 0.000014 * t2) * sin(dr * m);
    dl += (0.019993 - 0.000101 * t) * sin(dr * 2 * m) +
        0.000290 * sin(dr * 3 * m);

    var l = l0 + dl;
    l = l * dr;
    l = l - pi * 2 * (l / (pi * 2)).floor();
    return (l / pi * 6).floor();
  }

  static int _getLunarMonth11(int yy) {
    final off = jdFromDate(31, 12, yy) - 2415021;
    final k = (off / 29.530588853).floor();
    var nm = _getNewMoonDay(k);
    final sunLong = _getSunLongitude(nm);
    if (sunLong >= 9) {
      nm = _getNewMoonDay(k - 1);
    }
    return nm;
  }

  static int _getLeapMonthOffset(int a11) {
    final k = ((a11 - 2415021.076998695) / 29.530588853 + 0.5).floor();
    var last = 0;
    var i = 1;
    var arc = _getSunLongitude(_getNewMoonDay(k + i));
    do {
      last = arc;
      i++;
      arc = _getSunLongitude(_getNewMoonDay(k + i));
    } while (arc != last && i < 14);
    return i - 1;
  }

  static LunarDate solarToLunar(DateTime solarDate) {
    final dd = solarDate.day;
    final mm = solarDate.month;
    final yy = solarDate.year;

    final dayNumber = jdFromDate(dd, mm, yy);
    final k = ((dayNumber - 2415021.076998695) / 29.530588853).floor();
    var monthStart = _getNewMoonDay(k + 1);
    if (monthStart > dayNumber) {
      monthStart = _getNewMoonDay(k);
    }

    var a11 = _getLunarMonth11(yy);
    var b11 = a11;
    int lunarYear;

    if (a11 >= monthStart) {
      lunarYear = yy;
      a11 = _getLunarMonth11(yy - 1);
    } else {
      lunarYear = yy + 1;
      b11 = _getLunarMonth11(yy + 1);
    }

    final lunarDay = dayNumber - monthStart + 1;
    final diff = (monthStart - a11) ~/ 29;
    var lunarLeap = false;
    var lunarMonth = diff + 11;

    if (b11 - a11 > 365) {
      final leapMonthDiff = _getLeapMonthOffset(a11);
      if (diff >= leapMonthDiff) {
        lunarMonth = diff + 10;
        if (diff == leapMonthDiff) {
          lunarLeap = true;
        }
      }
    }

    if (lunarMonth > 12) {
      lunarMonth -= 12;
    }
    if (lunarMonth >= 11 && diff < 4) {
      lunarYear -= 1;
    }

    return LunarDate(
      day: lunarDay,
      month: lunarMonth,
      year: lunarYear,
      isLeap: lunarLeap,
    );
  }

  static DateTime lunarToSolar(int lunarDay, int lunarMonth, int lunarYear,
      {bool isLeap = false}) {
    int a11 = (lunarMonth < 11)
        ? _getLunarMonth11(lunarYear - 1)
        : _getLunarMonth11(lunarYear);
    final b11 = (lunarMonth < 11)
        ? _getLunarMonth11(lunarYear)
        : _getLunarMonth11(lunarYear + 1);

    final k = ((a11 - 2415021.076998695) / 29.530588853 + 0.5).floor();
    var off = lunarMonth - 11;
    if (off < 0) off += 12;

    if (b11 - a11 > 365) {
      final leapOff = _getLeapMonthOffset(a11);
      if (isLeap) {
        off = leapOff;
      } else if (off >= leapOff) {
        off += 1;
      }
    }

    final monthStart = _getNewMoonDay(k + off);
    final solarJd = monthStart + lunarDay - 1;
    final parts = jdToDate(solarJd);

    return DateTime(parts[2], parts[1], parts[0]);
  }

  static int getDaysInLunarMonth(int month, int year, bool isLeap) {
    final startSolar = lunarToSolar(1, month, year, isLeap: isLeap);
    DateTime nextMonthSolar;
    if (month == 12) {
      nextMonthSolar = lunarToSolar(1, 1, year + 1, isLeap: false);
    } else {
      nextMonthSolar = lunarToSolar(1, month + 1, year, isLeap: false);
    }
    return nextMonthSolar.difference(startSolar).inDays;
  }
}
