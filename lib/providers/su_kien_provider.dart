import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import '../models/su_kien.dart';
import '../services/notification_service.dart';
import '../utils/am_lich_helper.dart';

class SuKienProvider extends ChangeNotifier {
  final Box<SuKien> _box = Hive.box<SuKien>('suKienBox');

  // Danh sách lưu trữ các ngày Dương Lịch có sự kiện (dùng Set để chống trùng lặp)
  Set<DateTime> _cacNgayCoSuKienDuongLich = {};
  Set<DateTime> get cacNgayCoSuKienDuongLich => _cacNgayCoSuKienDuongLich;

  SuKienProvider() {
    _capNhatDanhSachNgayCoSuKien(); // Cập nhật ngay khi khởi tạo
  }

  /// Toàn bộ danh sách sự kiện
  List<SuKien> get danhSachSuKien => _box.values.toList();

  /// Thêm sự kiện mới + lên lịch thông báo
  Future<void> themSuKien(SuKien suKien) async {
    await _box.put(suKien.id, suKien);
    await NotificationService.lenLichSuKien(suKien);
    _capNhatDanhSachNgayCoSuKien(); // Tính toán lại ngày chấm đỏ
    notifyListeners();
  }

  /// Xóa sự kiện + hủy thông báo
  Future<void> xoaSuKien(String id) async {
    await NotificationService.huyLichSuKien(id);
    await _box.delete(id);
    _capNhatDanhSachNgayCoSuKien(); // Tính toán lại ngày chấm đỏ
    notifyListeners();
  }

  /// Cập nhật sự kiện + lên lịch lại thông báo
  Future<void> capNhatSuKien(SuKien suKien) async {
    await _box.put(suKien.id, suKien);
    await NotificationService.lenLichSuKien(suKien);
    _capNhatDanhSachNgayCoSuKien(); // Tính toán lại ngày chấm đỏ
    notifyListeners();
  }

  /// Lấy danh sách sự kiện trong một ngày âm cụ thể
  List<SuKien> suKienTrongNgay(int ngayAm, int thangAm) {
    return _box.values
        .where((sk) => sk.ngayAm == ngayAm && sk.thangAm == thangAm)
        .toList();
  }

  /// =========================================================
  /// LOGIC: TÍNH TOÁN NGÀY DƯƠNG LỊCH ĐỂ HIỂN THỊ CHẤM ĐỎ
  /// =========================================================
  void _capNhatDanhSachNgayCoSuKien() {
    final now = DateTime.now();
    Set<DateTime> dsMoi = {};

    // Lấy năm âm lịch hiện tại để đối chiếu
    final amHienTai = AmLichHelper.duongSangAm(now);
    final namAmHienTai = amHienTai != null ? amHienTai.getYear() : now.year;

    final danhSach = _box.values.toList();

    for (var sk in danhSach) {
      // 1. Sự kiện lặp hàng năm (namAm == null)
      if (sk.namAm == null) {
        // Vẽ cho 3 năm: Năm ngoái, năm nay, và năm sau để lịch cuộn luôn có chấm
        for (int i = -1; i <= 1; i++) {
          DateTime? ngayDuong =
              AmLichHelper.amSangDuong(namAmHienTai + i, sk.thangAm, sk.ngayAm);
          if (ngayDuong != null) {
            dsMoi.add(DateTime(ngayDuong.year, ngayDuong.month, ngayDuong.day));
          }
        }
      }
      // 2. Sự kiện chỉ diễn ra đúng 1 năm cố định
      else {
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
