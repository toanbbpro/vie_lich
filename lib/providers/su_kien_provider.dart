import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import '../models/su_kien.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';
import '../utils/am_lich_helper.dart';
import '../utils/app_constants.dart';

class SuKienProvider extends ChangeNotifier {
  late final Box<SuKien> _box;

  // Danh sách lưu trữ các ngày Dương Lịch có sự kiện (dùng Set để chống trùng lặp)
  Set<DateTime> _cacNgayCoSuKienDuongLich = {};
  Set<DateTime> get cacNgayCoSuKienDuongLich => _cacNgayCoSuKienDuongLich;

  bool _isInitialized = false;

  SuKienProvider() {
    _initBox();
  }

  Future<void> _initBox() async {
    _box = Hive.isBoxOpen(AppConstants.boxSuKien)
        ? Hive.box<SuKien>(AppConstants.boxSuKien)
        : await Hive.openBox<SuKien>(AppConstants.boxSuKien);
    _capNhatDanhSachNgayCoSuKien();
    _isInitialized = true;
    notifyListeners();
  }

  /// Toàn bộ danh sách sự kiện
  List<SuKien> get danhSachSuKien {
    if (!_isInitialized || !Hive.isBoxOpen(AppConstants.boxSuKien)) return [];
    return _box.values.toList();
  }

  /// Thêm sự kiện mới + lên lịch thông báo
  Future<void> themSuKien(SuKien suKien) async {
    await _box.put(suKien.id, suKien);
    await NotificationService.lenLichSuKien(suKien);
    _capNhatDanhSachNgayCoSuKien();
    notifyListeners();
    await WidgetService.capNhatWidget();
  }

  /// Xóa sự kiện + hủy thông báo
  Future<void> xoaSuKien(String id) async {
    await NotificationService.huyLichSuKien(id);
    await _box.delete(id);
    _capNhatDanhSachNgayCoSuKien();
    notifyListeners();
    await WidgetService.capNhatWidget();
  }

  /// Cập nhật sự kiện + lên lịch lại thông báo
  Future<void> capNhatSuKien(SuKien suKien) async {
    await _box.put(suKien.id, suKien);
    await NotificationService.lenLichSuKien(suKien);
    _capNhatDanhSachNgayCoSuKien();
    notifyListeners();
    await WidgetService.capNhatWidget();
  }

  /// Lấy danh sách sự kiện trong một ngày âm cụ thể
  List<SuKien> suKienTrongNgay(int ngayAm, int thangAm) {
    if (!_isInitialized) return [];
    return _box.values
        .where((sk) => sk.ngayAm == ngayAm && sk.thangAm == thangAm)
        .toList();
  }

  /// =========================================================
  /// LOGIC: TÍNH TOÁN NGÀY DƯƠNG LỊCH ĐỂ HIỂN THỊ CHẤM ĐỎ (CÓ CACHE)
  /// =========================================================
  void _capNhatDanhSachNgayCoSuKien() {
    if (!_isInitialized && Hive.isBoxOpen(AppConstants.boxSuKien) == false) return;
    
    final now = DateTime.now();
    Set<DateTime> dsMoi = {};

    final amHienTai = AmLichHelper.duongSangAm(now);
    final namAmHienTai = amHienTai != null ? amHienTai.getYear() : now.year;

    final danhSach = _box.values.toList();

    for (var sk in danhSach) {
      if (sk.namAm == null) {
        for (int i = -1; i <= 1; i++) {
          DateTime? ngayDuong =
              AmLichHelper.amSangDuong(namAmHienTai + i, sk.thangAm, sk.ngayAm);
          if (ngayDuong != null) {
            dsMoi.add(DateTime(ngayDuong.year, ngayDuong.month, ngayDuong.day));
          }
        }
      } else {
        DateTime? ngayDuong =
            AmLichHelper.amSangDuong(sk.namAm!, sk.thangAm, sk.ngayAm);
        if (ngayDuong != null) {
          dsMoi.add(DateTime(ngayDuong.year, ngayDuong.month, ngayDuong.day));
        }
      }
    }

    _cacNgayCoSuKienDuongLich = dsMoi;
  }
}

