import 'package:flutter/material.dart';
import 'package:tyme/tyme.dart';
import '../utils/am_lich_helper.dart';

class HomeScreenWidgetUI4x2 extends StatelessWidget {
  final int thangDuyet;
  final int namDuyet;
  final String tenSuKien;
  final String thoiGianSuKien;
  final String loaiSuKien;
  final List<int> ngayCoSuKien;

  const HomeScreenWidgetUI4x2({
    super.key,
    required this.thangDuyet,
    required this.namDuyet,
    this.tenSuKien = "Không có sự kiện sắp tới",
    this.thoiGianSuKien = "",
    this.loaiSuKien = "event",
    this.ngayCoSuKien = const [],
  });

  IconData _layIconTheoLoai() {
    switch (loaiSuKien) {
      case "cake":
        return Icons.cake;
      case "alarm":
        return Icons.alarm;
      default:
        return Icons.event_available;
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
          danhSachCot.add(SizedBox(
            width: itemWidth,
            height: itemHeight,
            child: _buildONgay(ngayDangXet, isSunday),
          ));
          ngayDangXet++;
        }
      }
      danhSachDong.add(Row(children: danhSachCot));
    }
    return danhSachDong;
  }

  Widget _buildONgay(int day, bool isSunday) {
    final now = DateTime.now();
    final isToday =
        (day == now.day && thangDuyet == now.month && namDuyet == now.year);
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
      margin: const EdgeInsets.all(1),
      decoration: isToday
          ? BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            )
          : null,
      child: Stack(
        children: [
          // 1. Số dương: Góc trên trái
          Positioned(
            top: 4,
            left: 6,
            child: Text(
              '$day',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                  color: isToday
                      ? Colors.red
                      : (isSunday ? Colors.red.shade400 : Colors.black87)),
            ),
          ),

          // 2. Số âm: Góc dưới phải
          Positioned(
            bottom: 2,
            right: 6,
            child: Text(
              chuoiAmLich,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                  color: isToday ? Colors.red.shade700 : Colors.grey.shade600),
            ),
          ),

          // 3. Chấm đỏ sự kiện: Góc dưới trái
          if (hasEvent)
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle)),
            )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final lunarToday = AmLichHelper.duongSangAm(now);
    final amDay = lunarToday?.getDay() ?? 0;
    final amMonth = lunarToday?.getMonth() ?? 0;
    final canChi =
        lunarToday != null ? AmLichHelper.layCanChiNam(lunarToday) : '';
    final tenThangAm = AmLichHelper.layTenThang(amMonth);

    String thongTinSuKien = tenSuKien;
    if (thoiGianSuKien.isNotEmpty) {
      thongTinSuKien = '$tenSuKien\n($thoiGianSuKien)';
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 800,
        height: 360,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ================= KHỐI TRÁI: VẠN NIÊN =================
            Expanded(
              flex: 4,
              child: Container(
                margin: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(56),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 3))
                  ],
                ),
                // ĐÃ SỬA: Tăng padding đáy và 2 bên để không bị lẹm góc
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'ÂM LỊCH',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        color: Colors.red.shade400,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$amDay',
                              style: TextStyle(
                                fontSize: 125,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                                height: 0.85,
                              ),
                            ),
                            const SizedBox(height: 8),
                            FractionallySizedBox(
                              widthFactor: 0.75,
                              child: Text(
                                '$tenThangAm, năm $canChi',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.normal,
                                  color: Colors.orange.shade800,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Khối Sự kiện
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(_layIconTheoLoai(),
                              color: Colors.orange, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              thongTinSuKien,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.normal,
                                color: Colors.deepOrange,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Khoảng trống ở giữa
            const SizedBox(width: 4),

            // ================= KHỐI PHẢI: LỊCH THÁNG =================
            Expanded(
              flex: 6,
              child: Container(
                margin: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(56),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 3))
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      color: Colors.redAccent,
                      width: double.infinity,
                      child: Center(
                        child: Text(
                          'Tháng $thangDuyet, $namDuyet',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4.0, horizontal: 4.0),
                      child: Row(
                        children: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
                            .map((thu) {
                          return Expanded(
                            child: Center(
                              child: Text(thu,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: thu == 'CN'
                                          ? Colors.red
                                          : Colors.grey[700])),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    Divider(height: 1, color: Colors.grey.shade300),
                    Expanded(
                      child: Padding(
                        // ĐÃ SỬA: Thêm padding đáy 20 để các số không bị lẹm vào góc bo
                        padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 20.0),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final itemWidth = constraints.maxWidth / 7;
                            final tongSoNgayThangNay =
                                DateTime(namDuyet, thangDuyet + 1, 0).day;
                            final thuCuaNgayDau =
                                DateTime(namDuyet, thangDuyet, 1).weekday;
                            int tongSoO =
                                (thuCuaNgayDau - 1) + tongSoNgayThangNay;
                            int soDong = (tongSoO > 35) ? 6 : 5;
                            final itemHeight = constraints.maxHeight / soDong;

                            return Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
          ],
        ),
      ),
    );
  }
}
