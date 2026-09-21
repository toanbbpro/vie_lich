import 'package:home_widget/home_widget.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart'; // Đã đổi sang bản CE theo đúng cấu hình của bạn
import 'package:tyme/tyme.dart';
import '../widgets/home_screen_widget_ui.dart';
import '../models/su_kien.dart';
import '../utils/am_lich_helper.dart';

class WidgetService {
  static Future<void> capNhatWidget() async {
    final now = DateTime.now();
    
    List<int> ngayCoSuKienHienTai = [];
    String tenSuKienGanNhat = "Không có sự kiện sắp tới";
    String thoiGianSuKienGanNhat = "";
    String loaiSuKienGanNhat = "event";

    try {
      // Mở Box một cách an toàn
      var box = Hive.isBoxOpen('suKienBox') 
          ? Hive.box<SuKien>('suKienBox') 
          : await Hive.openBox<SuKien>('suKienBox');
      
      List<SuKien> danhSachSuKien = box.values.toList();
      
      // Danh sách phụ chứa sự kiện sau khi đã quy đổi sang ngày Dương
      List<Map<String, dynamic>> dsDaChuyenDoi = [];
      
      // Lấy năm âm lịch hiện tại để làm mốc tính toán
      LunarDay? amHienTai = AmLichHelper.duongSangAm(now);
      int namAmHienTai = amHienTai != null ? amHienTai.getYear() : now.year;
      DateTime todayOnly = DateTime(now.year, now.month, now.day);

      // --- CHUYỂN ĐỔI ÂM SANG DƯƠNG CHO TẤT CẢ SỰ KIỆN ---
      for (var sk in danhSachSuKien) {
        // Nếu sự kiện lặp hàng năm (namAm == null), ta lấy năm âm hiện tại
        int namAmTinhToan = sk.namAm ?? namAmHienTai;
        DateTime? ngayDuong = AmLichHelper.amSangDuong(namAmTinhToan, sk.thangAm, sk.ngayAm);
        
        // Kiểm tra nếu sự kiện lặp năm mà ngày đó đã qua trong năm nay -> tính cho năm sau
        if (sk.namAm == null && ngayDuong != null) {
          DateTime dateOnly = DateTime(ngayDuong.year, ngayDuong.month, ngayDuong.day);
          if (dateOnly.isBefore(todayOnly)) {
            ngayDuong = AmLichHelper.amSangDuong(namAmHienTai + 1, sk.thangAm, sk.ngayAm);
          }
        }
        
        if (ngayDuong != null) {
          dsDaChuyenDoi.add({
            'ten': sk.ten,
            'ngayDuong': ngayDuong,
            'tag': sk.tag ?? 'event'
          });
          
          // Thêm vào list chấm đỏ nếu diễn ra trong tháng và năm nay
          if (ngayDuong.month == now.month && ngayDuong.year == now.year) {
            ngayCoSuKienHienTai.add(ngayDuong.day);
          }
        }
      }

      // --- TÌM SỰ KIỆN GẦN NHẤT TRONG TƯƠNG LAI ---
      List<Map<String, dynamic>> suKienSapToi = dsDaChuyenDoi.where((sk) {
        DateTime ngayDuong = sk['ngayDuong'];
        DateTime dateOnly = DateTime(ngayDuong.year, ngayDuong.month, ngayDuong.day);
        return dateOnly.isAfter(todayOnly) || dateOnly.isAtSameMomentAs(todayOnly);
      }).toList();

      if (suKienSapToi.isNotEmpty) {
        // Sắp xếp tăng dần theo thời gian
        suKienSapToi.sort((a, b) => (a['ngayDuong'] as DateTime).compareTo(b['ngayDuong'] as DateTime));
        
        var skGanNhat = suKienSapToi.first;
        DateTime dateSK = skGanNhat['ngayDuong'];
        
        tenSuKienGanNhat = skGanNhat['ten'];
        loaiSuKienGanNhat = skGanNhat['tag'];
        
        int soNgayConLai = DateTime(dateSK.year, dateSK.month, dateSK.day).difference(todayOnly).inDays;
        String ngayText = '${dateSK.day.toString().padLeft(2, '0')}/${dateSK.month.toString().padLeft(2, '0')}/${dateSK.year}';
        
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

    // --- CHỤP ẢNH UI & ĐẨY LÊN WIDGET ---
    await HomeWidget.renderFlutterWidget(
      HomeScreenWidgetUI(
        thangDuyet: now.month, 
        namDuyet: now.year,
        tenSuKien: tenSuKienGanNhat, 
        thoiGianSuaKien: thoiGianSuKienGanNhat,
        loaiSuKien: loaiSuKienGanNhat, 
        ngayCoSuKien: ngayCoSuKienHienTai.toSet().toList(), // Lọc trùng lặp bằng toSet()
      ),
      key: 'widget_image', 
      logicalSize: const Size(500, 375), 
    );

    await HomeWidget.updateWidget(
      name: 'HomeScreenWidgetProvider',
      androidName: 'HomeScreenWidgetProvider',
    );
  }
}