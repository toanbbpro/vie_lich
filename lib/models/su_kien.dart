import 'package:hive_ce/hive.dart';

part 'su_kien.g.dart';

@HiveType(typeId: 0)
class SuKien extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String ten;

  @HiveField(2)
  int ngayAm;

  @HiveField(3)
  int thangAm;

  @HiveField(4)
  int? namAm;

  @HiveField(5)
  String? ghiChu;

  @HiveField(6)
  String? duongDanAnh;

  @HiveField(7)
  int baoTruoc;

  @HiveField(8)
  bool daXuatLich;

  SuKien({
    required this.id,
    required this.ten,
    required this.ngayAm,
    required this.thangAm,
    this.namAm,
    this.ghiChu,
    this.duongDanAnh,
    this.baoTruoc = 3,
    this.daXuatLich = false,
  });
}
