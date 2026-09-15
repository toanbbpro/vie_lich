import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/su_kien.dart';
import '../providers/su_kien_provider.dart';
import '../services/calendar_export.dart';
import '../utils/am_lich_helper.dart';
import '../utils/lunar_vn.dart';

class ThemSuaSuKienScreen extends StatefulWidget {
  final SuKien? suKien;

  const ThemSuaSuKienScreen({super.key, this.suKien});

  @override
  State<ThemSuaSuKienScreen> createState() => _ThemSuaSuKienScreenState();
}

class _ThemSuaSuKienScreenState extends State<ThemSuaSuKienScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tenController = TextEditingController();
  final _ghiChuController = TextEditingController();

  int _ngayAm = 1;
  int _thangAm = 1;
  int _baoTruoc = 3;
  String? _duongDanAnh;
  bool _daXuatLich = false;

  bool get _isEditing => widget.suKien != null;

  @override
  void initState() {
    super.initState();
    if (widget.suKien != null) {
      final s = widget.suKien!;
      _tenController.text = s.ten;
      _ghiChuController.text = s.ghiChu ?? '';
      _ngayAm = s.ngayAm;
      _thangAm = s.thangAm;
      _baoTruoc = s.baoTruoc;
      _duongDanAnh = s.duongDanAnh;
      _daXuatLich = s.daXuatLich;
    }
  }

  @override
  void dispose() {
    _tenController.dispose();
    _ghiChuController.dispose();
    super.dispose();
  }

  /// ===== CHỌN ẢNH =====
  Future<void> _chonAnh() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;

      // Copy vào thư mục riêng của app để persist
      final appDir = await getApplicationDocumentsDirectory();
      final imgDir = Directory('${appDir.path}/images');
      if (!imgDir.existsSync()) {
        await imgDir.create(recursive: true);
      }
      final ext = picked.path.split('.').last;
      final fileName = 'sk_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final savedPath = '${imgDir.path}/$fileName';
      await File(picked.path).copy(savedPath);

      if (!mounted) return;
      setState(() => _duongDanAnh = savedPath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi chọn ảnh: $e')),
      );
    }
  }

  /// ===== XÓA ẢNH =====
  void _xoaAnh() {
    setState(() => _duongDanAnh = null);
  }

  /// ===== LƯU =====
  Future<void> _luu() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<SuKienProvider>(context, listen: false);

    if (_isEditing) {
      final updated = SuKien(
        id: widget.suKien!.id,
        ten: _tenController.text.trim(),
        ngayAm: _ngayAm,
        thangAm: _thangAm,
        namAm: widget.suKien!.namAm,
        ghiChu: _ghiChuController.text.trim().isEmpty
            ? null
            : _ghiChuController.text.trim(),
        duongDanAnh: _duongDanAnh,
        baoTruoc: _baoTruoc,
        daXuatLich: _daXuatLich,
      );
      await provider.capNhatSuKien(updated);
    } else {
      final moi = SuKien(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        ten: _tenController.text.trim(),
        ngayAm: _ngayAm,
        thangAm: _thangAm,
        ghiChu: _ghiChuController.text.trim().isEmpty
            ? null
            : _ghiChuController.text.trim(),
        duongDanAnh: _duongDanAnh,
        baoTruoc: _baoTruoc,
        daXuatLich: false,
      );
      await provider.themSuKien(moi);
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  /// ===== XÓA SỰ KIỆN =====
  Future<void> _xoa() async {
    final xacNhan = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa sự kiện'),
        content: Text('Bạn có chắc muốn xóa "${widget.suKien!.ten}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    // Kiểm tra mounted sau await showDialog
    if (!mounted) return;
    if (xacNhan != true) return;

    final provider = Provider.of<SuKienProvider>(context, listen: false);
    await provider.xoaSuKien(widget.suKien!.id);

    if (!mounted) return;
    Navigator.pop(context);
  }

  /// ===== XUẤT SANG LỊCH HỆ THỐNG =====
  Future<void> _xuatLich() async {
    if (!_formKey.currentState!.validate()) return;

    final tam = SuKien(
      id: widget.suKien?.id ?? 'tmp',
      ten: _tenController.text.trim(),
      ngayAm: _ngayAm,
      thangAm: _thangAm,
      ghiChu: _ghiChuController.text.trim().isEmpty
          ? null
          : _ghiChuController.text.trim(),
      baoTruoc: _baoTruoc,
    );

    final ok = await CalendarExport.xuatSuKien(tam);

    // Kiểm tra mounted sau await
    if (!mounted) return;

    if (ok) {
      setState(() => _daXuatLich = true);

      // Nếu đang sửa, cập nhật cờ trong DB
      if (_isEditing) {
        final provider = Provider.of<SuKienProvider>(context, listen: false);
        final updated = SuKien(
          id: widget.suKien!.id,
          ten: _tenController.text.trim(),
          ngayAm: _ngayAm,
          thangAm: _thangAm,
          namAm: widget.suKien!.namAm,
          ghiChu: _ghiChuController.text.trim().isEmpty
              ? null
              : _ghiChuController.text.trim(),
          duongDanAnh: _duongDanAnh,
          baoTruoc: _baoTruoc,
          daXuatLich: true,
        );
        await provider.capNhatSuKien(updated);
        if (!mounted) return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã mở ứng dụng lịch hệ thống')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể xuất sự kiện')),
      );
    }
  }

  /// ===== PREVIEW NGÀY DƯƠNG =====
  String _previewNgayDuong() {
    try {
      final now = DateTime.now();
      var ngay = LunarSolarConverter.lunarToSolar(_ngayAm, _thangAm, now.year);
      if (ngay.isBefore(DateTime(now.year, now.month, now.day))) {
        ngay =
            LunarSolarConverter.lunarToSolar(_ngayAm, _thangAm, now.year + 1);
      }
      final fmt = DateFormat('EEEE, dd/MM/yyyy', 'vi');
      return fmt.format(ngay);
    } catch (e) {
      return 'Ngày âm không hợp lệ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _isEditing ? 'Sửa sự kiện' : 'Thêm sự kiện';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Xóa',
              onPressed: _xoa,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // === TÊN SỰ KIỆN ===
              TextFormField(
                controller: _tenController,
                decoration: const InputDecoration(
                  labelText: 'Tên sự kiện *',
                  hintText: 'Ví dụ: Giỗ Ông Nội',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Vui lòng nhập tên sự kiện';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // === NGÀY ÂM + THÁNG ÂM ===
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _ngayAm,
                      decoration: const InputDecoration(
                        labelText: 'Ngày âm',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(30, (i) => i + 1)
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text('$e'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _ngayAm = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int>(
                      initialValue: _thangAm,
                      decoration: const InputDecoration(
                        labelText: 'Tháng âm',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(12, (i) => i + 1)
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(AmLichHelper.layTenThang(e)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _thangAm = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // === PREVIEW NGÀY DƯƠNG ===
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sự kiện năm nay/sau: ${_previewNgayDuong()}',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // === SỐ NGÀY BÁO TRƯỚC ===
              DropdownButtonFormField<int>(
                initialValue: _baoTruoc,
                decoration: const InputDecoration(
                  labelText: 'Báo trước',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notifications_active_outlined),
                ),
                items: const [0, 1, 2, 3, 5, 7, 10, 15, 30]
                    .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e == 0 ? 'Không báo trước' : '$e ngày'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _baoTruoc = v!),
              ),
              const SizedBox(height: 16),

              // === GHI CHÚ ===
              TextFormField(
                controller: _ghiChuController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú',
                  hintText: 'Thông tin thêm về sự kiện...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),

              // === ẢNH ===
              _KhungAnh(
                duongDanAnh: _duongDanAnh,
                onChonAnh: _chonAnh,
                onXoaAnh: _xoaAnh,
              ),
              const SizedBox(height: 24),

              // === NÚT LƯU ===
              FilledButton.icon(
                onPressed: _luu,
                icon: const Icon(Icons.save),
                label: Text(_isEditing ? 'Cập nhật' : 'Lưu sự kiện'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 10),

              // === NÚT XUẤT LỊCH ===
              OutlinedButton.icon(
                onPressed: _xuatLich,
                icon: Icon(
                  _daXuatLich ? Icons.event_available : Icons.event,
                  color: _daXuatLich ? Colors.green : null,
                ),
                label: Text(
                  _daXuatLich
                      ? 'Đã xuất lịch (xuất lại)'
                      : 'Xuất sang lịch hệ thống',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: _daXuatLich ? Colors.green.shade700 : null,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// ===== KHUNG CHỌN ẢNH =====
class _KhungAnh extends StatelessWidget {
  final String? duongDanAnh;
  final VoidCallback onChonAnh;
  final VoidCallback onXoaAnh;

  const _KhungAnh({
    required this.duongDanAnh,
    required this.onChonAnh,
    required this.onXoaAnh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (duongDanAnh == null) {
      return OutlinedButton.icon(
        onPressed: onChonAnh,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Chọn ảnh (tùy chọn)'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Ảnh sự kiện',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.file(
                  File(duongDanAnh!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 48),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onXoaAnh,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Material(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onChonAnh,
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Đổi ảnh',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
