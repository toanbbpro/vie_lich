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
  final _tagController = TextEditingController();

  int _ngayAm = 1;
  int _thangAm = 1;
  int _baoTruoc = 3;
  int _gioNhac = 11;
  int _phutNhac = 30;
  String? _duongDanAnh;
  bool _daXuatLich = false;
  
  List<String> _tags = []; 

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
      _gioNhac = s.gioNhac;
      _phutNhac = s.phutNhac;
      _duongDanAnh = s.duongDanAnh;
      _daXuatLich = s.daXuatLich;
      
      if (s.tag != null && s.tag!.trim().isNotEmpty) {
        _tags = s.tag!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    }
  }

  @override
  void dispose() {
    _tenController.dispose();
    _ghiChuController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag() {
    final text = _tagController.text;
    if (text.trim().isEmpty) {
      return;
    }

    final parts = text.split(',');
    setState(() {
      for (var p in parts) {
        final t = p.trim();
        if (t.isNotEmpty && !_tags.contains(t)) {
          _tags.add(t);
        }
      }
    });
    _tagController.clear();
  }

  Future<void> _chonGioNhac() async {
    final chon = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _gioNhac, minute: _phutNhac),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (chon != null) {
      setState(() {
        _gioNhac = chon.hour;
        _phutNhac = chon.minute;
      });
    }
  }

  Future<void> _chonAnh() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (picked == null) {
        return;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final imgDir = Directory('${appDir.path}/images');
      if (!imgDir.existsSync()) {
        await imgDir.create(recursive: true);
      }
      
      final ext = picked.path.split('.').last;
      final fileName = 'sk_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final savedPath = '${imgDir.path}/$fileName';
      await File(picked.path).copy(savedPath);

      if (!mounted) {
        return;
      }
      setState(() => _duongDanAnh = savedPath);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _luu({bool dongManHinh = true}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    _addTag(); 
    
    final provider = Provider.of<SuKienProvider>(context, listen: false);

    final hienTai = widget.suKien;
    final suKien = SuKien(
      id: hienTai?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      ten: _tenController.text.trim(),
      ngayAm: _ngayAm,
      thangAm: _thangAm,
      namAm: hienTai?.namAm,
      ghiChu: _ghiChuController.text.trim().isEmpty ? null : _ghiChuController.text.trim(),
      duongDanAnh: _duongDanAnh,
      baoTruoc: _baoTruoc,
      daXuatLich: _isEditing ? _daXuatLich : false,
      gioNhac: _gioNhac,
      phutNhac: _phutNhac,
      tag: _tags.isEmpty ? null : _tags.join(', '), 
    );

    if (_isEditing) {
      await provider.capNhatSuKien(suKien);
    } else {
      await provider.themSuKien(suKien);
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing ? 'Đã cập nhật nhắc lịch thành công' : 'Đã lưu nhắc lịch thành công'),
      ),
    );

    if (dongManHinh) {
      Navigator.pop(context);
    }
  }

  Future<void> _xoa() async {
    final xacNhan = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa sự kiện'),
        content: Text('Bạn có chắc chắn muốn xóa "${widget.suKien!.ten}" không? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (xacNhan == true) {
      if (!mounted) {
        return;
      }
      await Provider.of<SuKienProvider>(context, listen: false).xoaSuKien(widget.suKien!.id);
      
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
    }
  }

  Future<void> _xuatLich() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final tam = SuKien(
      id: widget.suKien?.id ?? 'tmp',
      ten: _tenController.text.trim(),
      ngayAm: _ngayAm,
      thangAm: _thangAm,
      ghiChu: _ghiChuController.text.trim().isEmpty ? null : _ghiChuController.text.trim(),
      baoTruoc: _baoTruoc,
      gioNhac: _gioNhac,
      phutNhac: _phutNhac,
    );

    final ok = await CalendarExport.xuatSuKien(tam);
    
    if (!mounted) {
      return;
    }

    if (ok) {
      setState(() => _daXuatLich = true);
      if (_isEditing) {
        await _luu(dongManHinh: false);
      } 
      
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xuất lịch hệ thống thành công')));
    }
  }

  String _previewNgayDuong() {
    try {
      final now = DateTime.now();
      var ngay = LunarSolarConverter.lunarToSolar(_ngayAm, _thangAm, now.year);
      if (ngay.isBefore(DateTime(now.year, now.month, now.day))) {
        ngay = LunarSolarConverter.lunarToSolar(_ngayAm, _thangAm, now.year + 1);
      }
      return DateFormat('EEEE, dd/MM/yyyy', 'vi').format(ngay);
    } catch (_) {
      return 'Ngày âm không hợp lệ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final provider = Provider.of<SuKienProvider>(context, listen: false);
    final Set<String> allAvailableTags = {'Giỗ', 'Bên nội', 'Bên ngoại', 'Lễ Tết', 'Cá nhân'};
    
    for (var sk in provider.danhSachSuKien) {
      if (sk.tag != null && sk.tag!.trim().isNotEmpty) {
        final list = sk.tag!.split(',').map((e) => e.trim());
        allAvailableTags.addAll(list);
      }
    }
    allAvailableTags.removeWhere((t) => _tags.contains(t) || t.isEmpty);
    final suggestedTags = allAvailableTags.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Sửa nhắc lịch ${widget.suKien!.ten}' : 'Thêm nhắc lịch',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: FilledButton.icon(
              onPressed: () => _luu(),
              icon: const Icon(Icons.save, size: 18),
              label: const Text(
                'Lưu',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.lightBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
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
              TextFormField(
                controller: _tenController,
                decoration: const InputDecoration(
                  labelText: 'Tên nhắc lịch *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập tên nhắc lịch' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _ngayAm,
                      decoration: const InputDecoration(labelText: 'Ngày âm', border: OutlineInputBorder()),
                      items: List.generate(30, (i) => i + 1).map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
                      onChanged: (v) => setState(() => _ngayAm = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int>(
                      initialValue: _thangAm,
                      decoration: const InputDecoration(labelText: 'Tháng âm', border: OutlineInputBorder()),
                      items: List.generate(12, (i) => i + 1).map((e) => DropdownMenuItem(value: e, child: Text(AmLichHelper.layTenThang(e)))).toList(),
                      onChanged: (v) => setState(() => _thangAm = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Dương lịch tới: ${_previewNgayDuong()}', style: TextStyle(fontSize: 13, color: theme.colorScheme.primary))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _tagController,
                decoration: InputDecoration(
                  labelText: 'Thẻ (Tags)',
                  hintText: 'Nhập thẻ và bấm + hoặc phẩy',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.local_offer_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.add_circle, color: theme.colorScheme.primary),
                    onPressed: _addTag,
                  ),
                ),
                onChanged: (val) {
                  if (val.contains(',')) {
                    _addTag();
                  }
                },
                onFieldSubmitted: (_) => _addTag(),
              ),
              
              if (_tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: -8,
                    children: _tags.map((t) => Chip(
                      label: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
                      backgroundColor: theme.colorScheme.primaryContainer,
                      deleteIcon: const Icon(Icons.cancel, size: 18),
                      onDeleted: () => setState(() => _tags.remove(t)),
                    )).toList(),
                  ),
                ),

              if (suggestedTags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gợi ý (Bấm để thêm):', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: -8,
                        children: suggestedTags.map((t) => ActionChip(
                          label: Text(t, style: TextStyle(fontSize: 12, color: theme.colorScheme.primary)),
                          backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          side: BorderSide.none,
                          onPressed: () => setState(() => _tags.add(t)),
                        )).toList(),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _baoTruoc,
                decoration: const InputDecoration(labelText: 'Báo trước', border: OutlineInputBorder(), prefixIcon: Icon(Icons.notifications_active_outlined)),
                items: const [0, 1, 2, 3, 5, 7, 10, 15, 30].map((e) => DropdownMenuItem(value: e, child: Text(e == 0 ? 'Không báo trước' : '$e ngày'))).toList(),
                onChanged: (v) => setState(() => _baoTruoc = v!),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _chonGioNhac,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Giờ nhắc', border: OutlineInputBorder(), prefixIcon: Icon(Icons.access_time)),
                  child: Text('${_gioNhac.toString().padLeft(2, '0')}:${_phutNhac.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ghiChuController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Ghi chú', border: OutlineInputBorder(), prefixIcon: Icon(Icons.notes), alignLabelWithHint: true),
              ),
              const SizedBox(height: 16),
              if (_duongDanAnh == null)
                OutlinedButton.icon(onPressed: _chonAnh, icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Thêm ảnh minh họa'))
              else
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Image.file(File(_duongDanAnh!), height: 150, width: double.infinity, fit: BoxFit.cover),
                    IconButton(icon: const Icon(Icons.cancel, color: Colors.white), onPressed: () => setState(() => _duongDanAnh = null)),
                  ],
                ),
                
              const SizedBox(height: 32),
              
              OutlinedButton.icon(
                onPressed: _xuatLich,
                icon: Icon(_daXuatLich ? Icons.event_available : Icons.event, color: _daXuatLich ? Colors.green : null),
                label: Text(_daXuatLich ? 'Đã xuất lịch hệ thống (Xuất lại)' : 'Xuất sang lịch hệ thống'),
              ),
              
              if (_isEditing) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _xoa,
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Xóa sự kiện', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}