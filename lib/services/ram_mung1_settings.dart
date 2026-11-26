import 'package:shared_preferences/shared_preferences.dart';
import '../utils/am_lich_helper.dart';

class RamMung1Config {
  final bool enabled;
  final bool before1Day;
  final int beforeHour;
  final int beforeMinute;
  final bool onDay;
  final int onDayHour;
  final int onDayMinute;

  const RamMung1Config({
    this.enabled = false,
    this.before1Day = true,
    this.beforeHour = 18,
    this.beforeMinute = 0,
    this.onDay = true,
    this.onDayHour = 6,
    this.onDayMinute = 0,
  });

  RamMung1Config copyWith({
    bool? enabled,
    bool? before1Day,
    int? beforeHour,
    int? beforeMinute,
    bool? onDay,
    int? onDayHour,
    int? onDayMinute,
  }) {
    return RamMung1Config(
      enabled: enabled ?? this.enabled,
      before1Day: before1Day ?? this.before1Day,
      beforeHour: beforeHour ?? this.beforeHour,
      beforeMinute: beforeMinute ?? this.beforeMinute,
      onDay: onDay ?? this.onDay,
      onDayHour: onDayHour ?? this.onDayHour,
      onDayMinute: onDayMinute ?? this.onDayMinute,
    );
  }

  static String fmtGio(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  String get moTaNgan {
    if (!enabled) {
      return 'Đang tắt • Bấm để hẹn nhắc tự động hằng tháng';
    }
    final parts = <String>[];
    if (before1Day) {
      parts.add('Trước 1 ngày (${fmtGio(beforeHour, beforeMinute)})');
    }
    if (onDay) {
      parts.add('Đúng ngày (${fmtGio(onDayHour, onDayMinute)})');
    }
    if (parts.isEmpty) {
      return 'Chưa chọn mốc giờ nhắc';
    }
    return parts.join(' • ');
  }
}

class MocNhacRamMung1 {
  final DateTime thoiGianBao;
  final DateTime ngaySuKienDuong;
  final int ngayAm;
  final int thangAm;
  final bool laThangNhuan;
  final bool laNhacTruoc;
  final String title;
  final String body;

  const MocNhacRamMung1({
    required this.thoiGianBao,
    required this.ngaySuKienDuong,
    required this.ngayAm,
    required this.thangAm,
    required this.laThangNhuan,
    required this.laNhacTruoc,
    required this.title,
    required this.body,
  });
}

class RamMung1Settings {
  static const String kEnabled = 'ram_mung1_enabled';
  static const String kBefore1Day = 'ram_mung1_before_1day';
  static const String kBeforeHour = 'ram_mung1_before_hour';
  static const String kBeforeMinute = 'ram_mung1_before_minute';
  static const String kOnDay = 'ram_mung1_on_day';
  static const String kOnDayHour = 'ram_mung1_on_day_hour';
  static const String kOnDayMinute = 'ram_mung1_on_day_minute';

  static const Set<String> allKeys = {
    kEnabled,
    kBefore1Day,
    kBeforeHour,
    kBeforeMinute,
    kOnDay,
    kOnDayHour,
    kOnDayMinute,
  };

  static Future<RamMung1Config> load() async {
    final prefs = await SharedPreferences.getInstance();
    return RamMung1Config(
      enabled: prefs.getBool(kEnabled) ?? false,
      before1Day: prefs.getBool(kBefore1Day) ?? true,
      beforeHour: (prefs.getInt(kBeforeHour) ?? 18).clamp(0, 23),
      beforeMinute: (prefs.getInt(kBeforeMinute) ?? 0).clamp(0, 59),
      onDay: prefs.getBool(kOnDay) ?? true,
      onDayHour: (prefs.getInt(kOnDayHour) ?? 6).clamp(0, 23),
      onDayMinute: (prefs.getInt(kOnDayMinute) ?? 0).clamp(0, 59),
    );
  }

  static Future<void> save(RamMung1Config config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kEnabled, config.enabled);
    await prefs.setBool(kBefore1Day, config.before1Day);
    await prefs.setInt(kBeforeHour, config.beforeHour.clamp(0, 23));
    await prefs.setInt(kBeforeMinute, config.beforeMinute.clamp(0, 59));
    await prefs.setBool(kOnDay, config.onDay);
    await prefs.setInt(kOnDayHour, config.onDayHour.clamp(0, 23));
    await prefs.setInt(kOnDayMinute, config.onDayMinute.clamp(0, 59));
  }

  /// Tính danh sách các mốc thông báo Mùng 1 & Rằm tiếp theo (kể cả tháng nhuận / tháng thiếu 29 ngày).
  static List<MocNhacRamMung1> tinhCacMocNhacTiepTheo(
    RamMung1Config config,
    DateTime now, {
    int soKy = 12,
  }) {
    if (!config.enabled || (!config.before1Day && !config.onDay)) {
      return const [];
    }

    final ketQua = <MocNhacRamMung1>[];
    final startDay = DateTime(now.year, now.month, now.day);
    int demKy = 0;

    for (int i = 0; i <= 240 && demKy < soKy; i++) {
      final targetDay = startDay.add(Duration(days: i));
      final lunar = AmLichHelper.duongSangAm(targetDay);
      if (lunar == null || (lunar.day != 1 && lunar.day != 15)) {
        continue;
      }

      final tenDip = lunar.day == 1 ? 'Mùng 1' : 'Rằm';
      final tenThang =
          '${AmLichHelper.layTenThang(lunar.month)}${lunar.isLeap ? ' (nhuận)' : ''}';
      final ngayDuongStr =
          '${targetDay.day.toString().padLeft(2, '0')}/${targetDay.month.toString().padLeft(2, '0')}/${targetDay.year}';

      bool coMocTrongTuongLai = false;

      if (config.before1Day) {
        final homTruoc = targetDay.subtract(const Duration(days: 1));
        final thoiGianTruoc = DateTime(
          homTruoc.year,
          homTruoc.month,
          homTruoc.day,
          config.beforeHour,
          config.beforeMinute,
        );
        if (thoiGianTruoc.isAfter(now)) {
          coMocTrongTuongLai = true;
          ketQua.add(
            MocNhacRamMung1(
              thoiGianBao: thoiGianTruoc,
              ngaySuKienDuong: targetDay,
              ngayAm: lunar.day,
              thangAm: lunar.month,
              laThangNhuan: lunar.isLeap,
              laNhacTruoc: true,
              title: 'Ngày mai là $tenDip $tenThang',
              body:
                  'Nhắc chuẩn bị lễ $tenDip (${lunar.day}/${lunar.month} âm lịch • $ngayDuongStr)',
            ),
          );
        }
      }

      if (config.onDay) {
        final thoiGianDungNgay = DateTime(
          targetDay.year,
          targetDay.month,
          targetDay.day,
          config.onDayHour,
          config.onDayMinute,
        );
        if (thoiGianDungNgay.isAfter(now)) {
          coMocTrongTuongLai = true;
          ketQua.add(
            MocNhacRamMung1(
              thoiGianBao: thoiGianDungNgay,
              ngaySuKienDuong: targetDay,
              ngayAm: lunar.day,
              thangAm: lunar.month,
              laThangNhuan: lunar.isLeap,
              laNhacTruoc: false,
              title: 'Hôm nay là $tenDip $tenThang',
              body:
                  'Nhắc lịch $tenDip (${lunar.day}/${lunar.month} âm lịch • $ngayDuongStr)',
            ),
          );
        }
      }

      if (coMocTrongTuongLai) {
        demKy++;
      }
    }

    ketQua.sort((a, b) => a.thoiGianBao.compareTo(b.thoiGianBao));
    return ketQua;
  }
}
