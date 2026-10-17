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

  // Cũ: Đường dẫn 1 ảnh duy nhất. Giữ lại để đọc dữ liệu cũ.
  @HiveField(6)
  String? duongDanAnh;

  @HiveField(7)
  int baoTruoc;

  @HiveField(8)
  bool daXuatLich;

  @HiveField(9)
  int gioNhac;

  @HiveField(10)
  int phutNhac;

  @HiveField(11)
  String? tag;

  // 👇 MỚI: Danh sách chứa nhiều ảnh/video
  @HiveField(12)
  List<String>? dsMedia;

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
    this.gioNhac = 11,
    this.phutNhac = 30,
    this.tag,
    this.dsMedia,
  });

  /// Getter thông minh: Tự động gộp ảnh cũ (duongDanAnh) vào danh sách mới.
  /// Nhờ vậy, các sự kiện tạo từ bản 2.0.0 trở về trước vẫn hiển thị bình thường.
  List<String> get danhSachMedia {
    if (dsMedia != null && dsMedia!.isNotEmpty) {
      return dsMedia!;
    }
    if (duongDanAnh != null && duongDanAnh!.isNotEmpty) {
      return [duongDanAnh!];
    }
    return [];
  }

  /// Getter tiện lợi để lấy ảnh đại diện (hiển thị ở danh sách ngoài màn hình chính)
  String? get anhDaiDien {
    final list = danhSachMedia;
    return list.isNotEmpty ? list.first : null;
  }

  // Chuyển Object thành Map để lưu JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ten': ten,
      'ngayAm': ngayAm,
      'thangAm': thangAm,
      'namAm': namAm,
      'ghiChu': ghiChu,
      'baoTruoc': baoTruoc,
      'gioNhac': gioNhac,
      'phutNhac': phutNhac,
      'tag': tag,
      // KHÔNG lưu duongDanAnh / dsMedia vì đường dẫn máy này mang qua máy khác sẽ hỏng
      // KHÔNG lưu daXuatLich vì qua máy mới phải xuất lịch lại từ đầu
    };
  }

  // Khôi phục Object từ file JSON
  factory SuKien.fromJson(Map<String, dynamic> json) {
    return SuKien(
      id: json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      ten: json['ten'] as String? ?? 'Sự kiện không tên',
      ngayAm: json['ngayAm'] as int? ?? 1,
      thangAm: json['thangAm'] as int? ?? 1,
      namAm: json['namAm'] as int?,
      ghiChu: json['ghiChu'] as String?,
      duongDanAnh: null,
      baoTruoc: json['baoTruoc'] as int? ?? 3,
      daXuatLich: false,
      gioNhac: json['gioNhac'] as int? ?? 11,
      phutNhac: json['phutNhac'] as int? ?? 30,
      tag: json['tag'] as String?,
      dsMedia: null, // Không import đường dẫn ảnh từ máy khác
    );
  }
}
