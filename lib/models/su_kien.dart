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

  // Khôi phục Object từ file JSON với kiểm tra biên an toàn
  factory SuKien.fromJson(Map<String, dynamic> json) {
    final rawId = (json['id'] as String?)?.trim() ?? '';
    final id = rawId.isEmpty
        ? DateTime.now().millisecondsSinceEpoch.toString()
        : (rawId.length > 128 ? rawId.substring(0, 128) : rawId);

    final rawTen = (json['ten'] as String?)?.trim() ?? '';
    final ten = rawTen.isEmpty
        ? 'Sự kiện không tên'
        : (rawTen.length > 200 ? rawTen.substring(0, 200) : rawTen);

    final rawGhiChu = (json['ghiChu'] as String?)?.trim();
    final ghiChu = (rawGhiChu == null || rawGhiChu.isEmpty)
        ? null
        : (rawGhiChu.length > 1000 ? rawGhiChu.substring(0, 1000) : rawGhiChu);

    final rawTag = (json['tag'] as String?)?.trim();
    final tag = (rawTag == null || rawTag.isEmpty)
        ? null
        : (rawTag.length > 200 ? rawTag.substring(0, 200) : rawTag);

    final rawNam = (json['namAm'] as num?)?.toInt();
    final namAm = (rawNam != null && rawNam >= 1900 && rawNam <= 2100)
        ? rawNam
        : null;

    return SuKien(
      id: id,
      ten: ten,
      ngayAm: (json['ngayAm'] as num?)?.toInt().clamp(1, 30) ?? 1,
      thangAm: (json['thangAm'] as num?)?.toInt().clamp(1, 12) ?? 1,
      namAm: namAm,
      ghiChu: ghiChu,
      duongDanAnh: null,
      baoTruoc: (json['baoTruoc'] as num?)?.toInt().clamp(0, 365) ?? 3,
      daXuatLich: false,
      gioNhac: (json['gioNhac'] as num?)?.toInt().clamp(0, 23) ?? 11,
      phutNhac: (json['phutNhac'] as num?)?.toInt().clamp(0, 59) ?? 30,
      tag: tag,
      dsMedia: null, // Không import đường dẫn ảnh từ máy khác
    );
  }
}
