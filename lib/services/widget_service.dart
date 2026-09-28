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

  static Future<void> capNhatWidget() async {
    final now = DateTime.now();

    List<int> ngayCoSuKienHienTai = [];
    String tenSuKienGanNhat = "Không có sự kiện sắp tới";
    String thoiGianSuKienGanNhat = "";
    String loaiSuKienGanNhat = "event";

    try {
      var box = Hive.isBoxOpen('suKienBox')
          ? Hive.box<SuKien>('suKienBox')
          : await Hive.openBox<SuKien>('suKienBox');

      List<SuKien> danhSachSuKien = box.values.toList();
      List<Map<String, dynamic>> dsDaChuyenDoi = [];

      LunarDay? amHienTai = AmLichHelper.duongSangAm(now);
      int namAmHienTai =
          amHienTai != null ? amHienTai.getYear() : now.year;
      DateTime todayOnly = DateTime(now.year, now.month, now.day);

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

      List<Map<String, dynamic>> suKienSapToi =
          dsDaChuyenDoi.where((sk) {
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
    } catch (e) {
      debugPrint("Lỗi khi đọc sự kiện Hive cho Widget: $e");
    }

    // ============================================================
    // ANDROID / iOS: giữ nguyên cách cũ
    // ============================================================
    String nextEventText = thoiGianSuKienGanNhat.isEmpty
        ? tenSuKienGanNhat
        : "$tenSuKienGanNhat\n($thoiGianSuKienGanNhat)";

    if (Platform.isAndroid) {
      await HomeWidget.renderFlutterWidget(
        HomeScreenWidgetUI(
          thangDuyet: now.month,
          namDuyet: now.year,
          tenSuKien: tenSuKienGanNhat,
          thoiGianSuKien: thoiGianSuKienGanNhat,
          loaiSuKien: loaiSuKienGanNhat,
          ngayCoSuKien: ngayCoSuKienHienTai.toSet().toList(),
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
      // macOS: build JSON đầy đủ rồi gửi qua MethodChannel
      // ============================================================
      final jsonData = _buildMacOSWidgetJson(
        now: now,
        ngayCoSuKien: ngayCoSuKienHienTai,
        tenSuKien: tenSuKienGanNhat,
        thoiGianSuKien: thoiGianSuKienGanNhat,
        loaiSuKien: loaiSuKienGanNhat,
      );

      try {
        await platform.invokeMethod('updateWidget', {
          'data': jsonData,
          'groupId': appGroupId,
        });
      } catch (e) {
        debugPrint("Lỗi gửi dữ liệu Widget macOS: $e");
        rethrow;
      }
    }
  }

  /// Build JSON data cho widget macOS.
  /// Trả về string JSON đã encode.
  static String _buildMacOSWidgetJson({
    required DateTime now,
    required List<int> ngayCoSuKien,
    required String tenSuKien,
    required String thoiGianSuKien,
    required String loaiSuKien,
  }) {
    // Thông tin ngày hiện tại
    final amHienTai = AmLichHelper.duongSangAm(now);

    // Danh sách ô lịch đầy đủ (bắt đầu từ thứ Hai của tuần chứa ngày 1)
    final ngayDauThang = DateTime(now.year, now.month, 1);
    final offset = ngayDauThang.weekday - 1; // 0 = Thứ Hai
    final ngayBatDau = ngayDauThang.subtract(Duration(days: offset));
    final soNgayTrongThang = DateTime(now.year, now.month + 1, 0).day;
    final tongO = offset + soNgayTrongThang;
    final soTuan = (tongO / 7).ceil();

    final List<Map<String, dynamic>> dsO = [];
    for (int i = 0; i < soTuan * 7; i++) {
      final ngay = ngayBatDau.add(Duration(days: i));
      final lunar = AmLichHelper.duongSangAm(ngay);
      final laTrongThang = ngay.month == now.month && ngay.year == now.year;

      dsO.add({
        'ngayDuong': ngay.day,
        'ngayAm': lunar?.getDay() ?? 0,
        'thangAm': lunar?.getMonth() ?? 0,
        'laChuNhat': ngay.weekday == 7,
        'laHomNay': ngay.year == now.year &&
            ngay.month == now.month &&
            ngay.day == now.day,
        'coSuKien': laTrongThang && ngayCoSuKien.contains(ngay.day),
        'laDauThangAm': lunar?.getDay() == 1,
        'laTrongThang': laTrongThang,
      });
    }

    final map = {
      'thangDuong': now.month,
      'namDuong': now.year,
      'ngayDuong': now.day,
      'thu': _thuNames[now.weekday - 1],
      'ngayAm': amHienTai?.getDay() ?? 0,
      'thangAm': amHienTai?.getMonth() ?? 0,
      'namAm': amHienTai?.getYear() ?? now.year,
      'canChiNam': AmLichHelper.layCanChiNam(amHienTai!),
      'dsO': dsO,
      'tenSuKien': tenSuKien,
      'thoiGianSuKien': thoiGianSuKien,
      'loaiSuKien': loaiSuKien,
    };

    return jsonEncode(map);
  }
}