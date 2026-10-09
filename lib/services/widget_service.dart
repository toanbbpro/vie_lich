import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce/hive.dart';
import 'package:tyme/tyme.dart';
import 'package:home_widget/home_widget.dart';
import '../widgets/home_screen_widget_ui.dart';
import '../models/su_kien.dart';
import '../utils/am_lich_helper.dart';

class WidgetService {
  static const String appGroupId = 'group.com.toanbb.vie_Lich';
  static const String macOSWidgetName = 'VIELichWidget';
  static const platform = MethodChannel('vie_lich_mac_widget');

  static const List<String> _thuNames = [
    'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm',
    'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật',
  ];

  /// Số ngày pre-compute cho widget macOS
  static const int _macOSMultiDayCount = 7;

  static Future<void> capNhatWidget() async {
    final now = DateTime.now();

    List<SuKien> danhSachSuKien = [];
    try {
      var box = Hive.isBoxOpen('suKienBox')
          ? Hive.box<SuKien>('suKienBox')
          : await Hive.openBox<SuKien>('suKienBox');
      danhSachSuKien = box.values.toList();
    } catch (e) {
      debugPrint("Lỗi đọc sự kiện Hive cho Widget: $e");
    }

    // === Tính data cho NGÀY HÔM NAY (dùng cho Android/iOS) ===
    final todayData = _tinhDuLieuMotNgay(now, danhSachSuKien);

    String nextEventText = todayData['thoiGianSuKien'].isEmpty
        ? todayData['tenSuKien']
        : "${todayData['tenSuKien']}\n(${todayData['thoiGianSuKien']})";

    // ============================================================
    // ANDROID / iOS
    // ============================================================
    if (Platform.isAndroid) {
      await HomeWidget.renderFlutterWidget(
        HomeScreenWidgetUI(
          thangDuyet: now.month,
          namDuyet: now.year,
          tenSuKien: todayData['tenSuKien'],
          thoiGianSuKien: todayData['thoiGianSuKien'],
          loaiSuKien: todayData['loaiSuKien'],
          ngayCoSuKien: (todayData['ngayCoSuKien'] as List).cast<int>(),
        ),
        key: 'widget_image',
        logicalSize: const Size(500, 375),
      );
      await HomeWidget.updateWidget(
        name: 'HomeScreenWidgetProvider',
        androidName: 'HomeScreenWidgetProvider',
      );
    } else if (Platform.isIOS) {
      await HomeWidget.setAppGroupId(appGroupId);
      await HomeWidget.saveWidgetData<String>('next_event', nextEventText);
      await HomeWidget.updateWidget(iOSName: macOSWidgetName);
    } else if (Platform.isMacOS) {
      // ============================================================
      // macOS: gửi 7 ngày data
      // ============================================================
      final List<String> dayJsonList = [];
      for (int i = 0; i < _macOSMultiDayCount; i++) {
        final targetDay = now.add(Duration(days: i));
        final dayJson = _buildDayJson(targetDay, danhSachSuKien);
        dayJsonList.add(dayJson);
      }

      // Gửi array các string JSON (Swift sẽ decode thành [WidgetData])
      try {
        await platform.invokeMethod('updateWidget', {
          'data': dayJsonList,
          'groupId': appGroupId,
          'isMulti': true,
        });
        debugPrint('✅ Gửi $_macOSMultiDayCount ngày cho widget macOS');
      } catch (e) {
        debugPrint("Lỗi gửi dữ liệu Widget macOS: $e");
        rethrow;
      }
    }
  }

  /// Tính dữ liệu cần thiết cho widget của 1 ngày cụ thể
  static Map<String, dynamic> _tinhDuLieuMotNgay(
    DateTime targetDay,
    List<SuKien> danhSachSuKien,
  ) {
    final now = targetDay;
    final todayOnly = DateTime(now.year, now.month, now.day);

    List<int> ngayCoSuKienHienTai = [];
    String tenSuKienGanNhat = "Không có sự kiện sắp tới";
    String thoiGianSuKienGanNhat = "";
    String loaiSuKienGanNhat = "event";

    LunarDay? amHienTai = AmLichHelper.duongSangAm(now);
    int namAmHienTai = amHienTai != null ? amHienTai.getYear() : now.year;

    List<Map<String, dynamic>> dsDaChuyenDoi = [];
    for (var sk in danhSachSuKien) {
      int namAmTinhToan = sk.namAm ?? namAmHienTai;
      DateTime? ngayDuong =
          AmLichHelper.amSangDuong(namAmTinhToan, sk.thangAm, sk.ngayAm);

      if (sk.namAm == null && ngayDuong != null) {
        DateTime dateOnly =
            DateTime(ngayDuong.year, ngayDuong.month, ngayDuong.day);
        if (dateOnly.isBefore(todayOnly)) {
          ngayDuong = AmLichHelper.amSangDuong(
              namAmHienTai + 1, sk.thangAm, sk.ngayAm);
        }
      }

      if (ngayDuong != null) {
        dsDaChuyenDoi.add({
          'ten': sk.ten,
          'ngayDuong': ngayDuong,
          'tag': sk.tag ?? 'event',
        });
        if (ngayDuong.month == now.month && ngayDuong.year == now.year) {
          ngayCoSuKienHienTai.add(ngayDuong.day);
        }
      }
    }

    List<Map<String, dynamic>> suKienSapToi = dsDaChuyenDoi.where((sk) {
      DateTime ngayDuong = sk['ngayDuong'];
      DateTime dateOnly =
          DateTime(ngayDuong.year, ngayDuong.month, ngayDuong.day);
      return dateOnly.isAfter(todayOnly) ||
          dateOnly.isAtSameMomentAs(todayOnly);
    }).toList();

    if (suKienSapToi.isNotEmpty) {
      suKienSapToi.sort((a, b) =>
          (a['ngayDuong'] as DateTime).compareTo(b['ngayDuong'] as DateTime));
      var skGanNhat = suKienSapToi.first;
      DateTime dateSK = skGanNhat['ngayDuong'];

      tenSuKienGanNhat = skGanNhat['ten'];
      loaiSuKienGanNhat = skGanNhat['tag'];

      int soNgayConLai = DateTime(dateSK.year, dateSK.month, dateSK.day)
          .difference(todayOnly)
          .inDays;
      String ngayText =
          '${dateSK.day.toString().padLeft(2, '0')}/${dateSK.month.toString().padLeft(2, '0')}/${dateSK.year}';

      if (soNgayConLai == 0) {
        thoiGianSuKienGanNhat = 'Hôm nay - $ngayText';
      } else if (soNgayConLai == 1) {
        thoiGianSuKienGanNhat = 'Ngày mai - $ngayText';
      } else {
        thoiGianSuKienGanNhat = 'Còn $soNgayConLai ngày - $ngayText';
      }
    }

    return {
      'tenSuKien': tenSuKienGanNhat,
      'thoiGianSuKien': thoiGianSuKienGanNhat,
      'loaiSuKien': loaiSuKienGanNhat,
      'ngayCoSuKien': ngayCoSuKienHienTai,
    };
  }

  /// Build JSON cho 1 ngày, trả về String
  static String _buildDayJson(DateTime targetDay, List<SuKien> danhSachSuKien) {
    final dayInfo = _tinhDuLieuMotNgay(targetDay, danhSachSuKien);
    final ngayCoSuKien = (dayInfo['ngayCoSuKien'] as List).cast<int>();

    final amHienTai = AmLichHelper.duongSangAm(targetDay);

    // Lưới lịch của tháng chứa targetDay
    final ngayDauThang = DateTime(targetDay.year, targetDay.month, 1);
    final offset = ngayDauThang.weekday - 1;
    final ngayBatDau = ngayDauThang.subtract(Duration(days: offset));
    final soNgayTrongThang =
        DateTime(targetDay.year, targetDay.month + 1, 0).day;
    final tongO = offset + soNgayTrongThang;
    final soTuan = (tongO / 7).ceil();

    final List<Map<String, dynamic>> dsO = [];
    for (int i = 0; i < soTuan * 7; i++) {
      final ngay = ngayBatDau.add(Duration(days: i));
      final lunar = AmLichHelper.duongSangAm(ngay);
      final laTrongThang =
          ngay.month == targetDay.month && ngay.year == targetDay.year;

      dsO.add({
        'ngayDuong': ngay.day,
        'ngayAm': lunar?.getDay() ?? 0,
        'thangAm': lunar?.getMonth() ?? 0,
        'laChuNhat': ngay.weekday == 7,
        'laHomNay': ngay.year == targetDay.year &&
            ngay.month == targetDay.month &&
            ngay.day == targetDay.day,
        'coSuKien': laTrongThang && ngayCoSuKien.contains(ngay.day),
        'laDauThangAm': lunar?.getDay() == 1,
        'laTrongThang': laTrongThang,
      });
    }

    final map = {
      'thangDuong': targetDay.month,
      'namDuong': targetDay.year,
      'ngayDuong': targetDay.day,
      'thu': _thuNames[targetDay.weekday - 1],
      'ngayAm': amHienTai?.getDay() ?? 0,
      'thangAm': amHienTai?.getMonth() ?? 0,
      'namAm': amHienTai?.getYear() ?? targetDay.year,
      'canChiNam': amHienTai != null
          ? AmLichHelper.layCanChiNam(amHienTai)
          : '',
      'dsO': dsO,
      'tenSuKien': dayInfo['tenSuKien'],
      'thoiGianSuKien': dayInfo['thoiGianSuKien'],
      'loaiSuKien': dayInfo['loaiSuKien'],
    };

    return jsonEncode(map);
  }
}