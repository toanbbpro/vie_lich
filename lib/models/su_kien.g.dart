// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'su_kien.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SuKienAdapter extends TypeAdapter<SuKien> {
  @override
  final typeId = 0;

  @override
  SuKien read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SuKien(
      id: fields[0] as String,
      ten: fields[1] as String,
      ngayAm: (fields[2] as num).toInt(),
      thangAm: (fields[3] as num).toInt(),
      namAm: (fields[4] as num?)?.toInt(),
      ghiChu: fields[5] as String?,
      duongDanAnh: fields[6] as String?,
      baoTruoc: fields[7] == null ? 3 : (fields[7] as num).toInt(),
      daXuatLich: fields[8] == null ? false : fields[8] as bool,
      gioNhac: fields[9] == null ? 11 : (fields[9] as num).toInt(),
      phutNhac: fields[10] == null ? 30 : (fields[10] as num).toInt(),
      tag: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SuKien obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.ten)
      ..writeByte(2)
      ..write(obj.ngayAm)
      ..writeByte(3)
      ..write(obj.thangAm)
      ..writeByte(4)
      ..write(obj.namAm)
      ..writeByte(5)
      ..write(obj.ghiChu)
      ..writeByte(6)
      ..write(obj.duongDanAnh)
      ..writeByte(7)
      ..write(obj.baoTruoc)
      ..writeByte(8)
      ..write(obj.daXuatLich)
      ..writeByte(9)
      ..write(obj.gioNhac)
      ..writeByte(10)
      ..write(obj.phutNhac)
      ..writeByte(11)
      ..write(obj.tag);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuKienAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
