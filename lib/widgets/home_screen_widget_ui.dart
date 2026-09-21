import 'package:flutter/material.dart';
import 'package:tyme/tyme.dart'; 
import '../utils/am_lich_helper.dart'; 

class HomeScreenWidgetUI extends StatelessWidget {
  final int thangDuyet;
  final int namDuyet;
  final String tenSuKien;
  final String thoiGianSuaKien;
  final String loaiSuKien;
  final List<int> ngayCoSuKien;

  const HomeScreenWidgetUI({
    super.key,
    required this.thangDuyet,
    required this.namDuyet,
    this.tenSuKien = "Không có sự kiện sắp tới",
    this.thoiGianSuaKien = "",
    this.loaiSuKien = "event",
    this.ngayCoSuKien = const [],
  });

  IconData _layIconTheoLoai() {
    switch (loaiSuKien) {
      case "cake": return Icons.cake;
      case "alarm": return Icons.alarm;
      default: return Icons.event_available;
    }
  }

  List<Widget> _buildLuoilich(double itemWidth, double itemHeight) {
    final ngayDauThang = DateTime(namDuyet, thangDuyet, 1);
    final thuCuaNgayDau = ngayDauThang.weekday; 
    final tongSoNgayThangNay = DateTime(namDuyet, thangDuyet + 1, 0).day;
    
    int soODauThang = thuCuaNgayDau - 1; 
    int tongSoO = soODauThang + tongSoNgayThangNay;
    
    int soDong = (tongSoO > 35) ? 6 : 5;
    
    List<Widget> danhSachDong = [];
    int ngayDangXet = 1;

    for (int r = 0; r < soDong; r++) {
      List<Widget> danhSachCot = [];
      for (int c = 0; c < 7; c++) {
        int viTriO = r * 7 + c;
        if (viTriO < soODauThang || ngayDangXet > tongSoNgayThangNay) {
          danhSachCot.add(SizedBox(width: itemWidth, height: itemHeight)); 
        } else {
          bool isSunday = (c == 6);
          danhSachCot.add(
            SizedBox(
              width: itemWidth,
              height: itemHeight,
              child: _buildONgay(ngayDangXet, isSunday),
            )
          );
          ngayDangXet++;
        }
      }
      danhSachDong.add(Row(children: danhSachCot));
    }
    
    return danhSachDong;
  }

  Widget _buildONgay(int day, bool isSunday) {
    final now = DateTime.now();
    final isToday = (day == now.day && thangDuyet == now.month && namDuyet == now.year);
    final hasEvent = ngayCoSuKien.contains(day);
    
    DateTime ngayDuongLich = DateTime(namDuyet, thangDuyet, day);
    LunarDay? amLich = AmLichHelper.duongSangAm(ngayDuongLich);
    
    String chuoiAmLich = '';
    if (amLich != null) {
       int lDay = amLich.getDay();
       int lMonth = amLich.getMonth();
       chuoiAmLich = (lDay == 1) ? '$lDay/$lMonth' : '$lDay';
    }

    return Container(
      margin: const EdgeInsets.all(2), // Giảm nhẹ margin
      decoration: isToday 
          ? BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1), 
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ) 
          : null,
      child: Stack(
        children: [
          // Ngày Dương
          Center(
            child: Text(
              '$day', 
              style: TextStyle(
                fontSize: 24, // Chỉnh xuống 24 để vừa vặn
                fontWeight: isToday ? FontWeight.bold : FontWeight.w500, 
                color: isToday ? Colors.red : (isSunday ? Colors.red.shade400 : Colors.black87)
              ),
            ),
          ),
          
          // Ngày Âm 
          Positioned(
            bottom: 4,
            right: 4,
            child: Text(
              chuoiAmLich, 
              style: TextStyle(
                fontSize: 12, // Chỉnh xuống 12
                fontWeight: FontWeight.w500,
                color: isToday ? Colors.red.shade300 : Colors.grey.shade600
              ),
            ),
          ),

          // Chấm sự kiện
          if (hasEvent)
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)), 
            )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String thongTinSuKien = tenSuKien;
    if (thoiGianSuaKien.isNotEmpty) {
      thongTinSuKien = '$tenSuKien ($thoiGianSuaKien)';
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 500, // Cập nhật lại width = 500
        height: 375, // Cập nhật lại height = 375
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            // KHỐI 1: LỊCH THÁNG
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24), 
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    // HEADER ĐỎ
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10), 
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Center(
                        child: Text(
                          'Tháng $thangDuyet, $namDuyet',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), 
                        ),
                      ),
                    ),
                    
                    // DÒNG THỨ
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 10.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'].map((thu) {
                          return Expanded(
                            child: Center(
                              child: Text(thu, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: thu == 'CN' ? Colors.red : Colors.grey[700])),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    
                    const Divider(height: 1),
                    
                    // LƯỚI LỊCH
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final itemWidth = constraints.maxWidth / 7;
                            final tongSoNgayThangNay = DateTime(namDuyet, thangDuyet + 1, 0).day;
                            final thuCuaNgayDau = DateTime(namDuyet, thangDuyet, 1).weekday;
                            int tongSoO = (thuCuaNgayDau - 1) + tongSoNgayThangNay;
                            int soDong = (tongSoO > 35) ? 6 : 5;
                            final itemHeight = constraints.maxHeight / soDong;

                            return Column(
                              children: _buildLuoilich(itemWidth, itemHeight),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // KHE HỞ
            const SizedBox(height: 8), 

            // KHỐI 2: SỰ KIỆN GẦN NHẤT
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 3))],
              ),
              child: Row(
                children: [
                  Icon(_layIconTheoLoai(), color: Colors.orange, size: 24), 
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      thongTinSuKien,
                      style: const TextStyle(
                        color: Colors.deepOrange, 
                        fontWeight: FontWeight.bold, 
                        fontSize: 18 
                      ),
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}