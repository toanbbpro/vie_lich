import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

import '../models/su_kien.dart';
import '../services/notification_service.dart';

class SuKienProvider extends ChangeNotifier {
  final Box<SuKien> _box = Hive.box<SuKien>('suKienBox');

  /// Toàn bộ danh sách sự kiện
  List<SuKien> get danhSachSuKien => _box.values.toList();

  /// Thêm sự kiện mới + lên lịch thông báo
  Future<void> themSuKien(SuKien suKien) async {
    await _box.put(suKien.id, suKien);
    await NotificationService.lenLichSuKien(suKien);
    notifyListeners();
  }

  /// Xóa sự kiện + hủy thông báo
  Future<void> xoaSuKien(String id) async {
    await NotificationService.huyLichSuKien(id);
    await _box.delete(id);
    notifyListeners();
  }

  /// Cập nhật sự kiện + lên lịch lại thông báo
  Future<void> capNhatSuKien(SuKien suKien) async {
    await _box.put(suKien.id, suKien);
    await NotificationService.lenLichSuKien(suKien);
    notifyListeners();
  }

  /// Lấy danh sách sự kiện trong một ngày âm cụ thể
  List<SuKien> suKienTrongNgay(int ngayAm, int thangAm) {
    return _box.values
        .where((sk) => sk.ngayAm == ngayAm && sk.thangAm == thangAm)
        .toList();
  }
}
