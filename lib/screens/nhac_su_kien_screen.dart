import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Thư viện vẽ QR

import '../models/su_kien.dart';
import '../providers/su_kien_provider.dart';
import '../services/calendar_export.dart';
import 'them_sua_su_kien_screen.dart';
import 'qr_scanner_screen.dart'; // Màn hình quét vừa tạo

class NhacSuKienScreen extends StatefulWidget {
  const NhacSuKienScreen({super.key});

  @override
  State<NhacSuKienScreen> createState() => _NhacSuKienScreenState();
}

class _NhacSuKienScreenState extends State<NhacSuKienScreen> {
  final Set<String> _selectedTags = {};
  bool _isSelecting = false;
  final Set<String> _selectedIds = {};

  List<String> _layDanhSachTagDong(List<SuKien> ds) {
    final Set<String> tags = {};
    for (var sk in ds) {
      if (sk.tag != null && sk.tag!.trim().isNotEmpty) {
        final list = sk.tag!.split(',').map((e) => e.trim());
        tags.addAll(list);
      }
    }
    final sortedTags = tags.toList()..sort();
    return ['Tất cả', ...sortedTags, 'Chưa gắn thẻ'];
  }

  void _batCheDoChon([String? initialId]) {
    setState(() {
      _isSelecting = true;
      _selectedIds.clear();
      if (initialId != null) {
        _selectedIds.add(initialId);
      }
    });
  }

  void _tatCheDoChon() {
    setState(() {
      _isSelecting = false;
      _selectedIds.clear();
    });
  }

  void _toggleChonItem(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  // MÁY A: ĐÓNG GÓI VÀ HIỂN THỊ MÃ QR
  Future<void> _chiaSeQuaQR(List<SuKien> dsGoc) async {
    final dsChon = dsGoc.where((e) => _selectedIds.contains(e.id)).toList();
    if (dsChon.isEmpty) return;

    if (dsChon.length > 25) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chỉ nên chia sẻ tối đa 25 nhắc lịch mỗi lần qua mã QR.')));
      return;
    }

    try {
      // 1. Chuyển sang JSON (Bỏ đường dẫn ảnh nội bộ)
      final List<Map<String, dynamic>> jsonList = dsChon.map((e) {
        final map = e.toJson();
        map['duongDanAnh'] = null; 
        return map;
      }).toList();
      
      final String jsonString = jsonEncode(jsonList);
      
      // 2. Nén bằng Gzip để tiết kiệm 70% dung lượng QR Code
      final bytes = utf8.encode(jsonString);
      final compressed = gzip.encode(bytes);
      final base64Str = base64Encode(compressed);
      
      final qrData = 'VL_QR:$base64Str';

      if (!mounted) return;
      _tatCheDoChon(); // Tắt chế độ chọn

      // 3. Bật hộp thoại hiển thị mã QR
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Mã QR Nhắc lịch', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Đưa máy khác vào quét mã này để nhận:', textAlign: TextAlign.center, style: TextStyle(fontSize: 13)),
              const SizedBox(height: 16),
              SizedBox(
                width: 250,
                height: 250,
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  errorCorrectionLevel: QrErrorCorrectLevel.L,
                ),
              ),
              const SizedBox(height: 16),
              Text('Gồm ${dsChon.length} sự kiện', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))
          ],
        ),
      );
    } catch (e) {
      debugPrint('Lỗi tạo QR: $e');
    }
  }

  // MÁY B: BẬT CAMERA QUÉT QR VÀ KHÔI PHỤC
  Future<void> _quetMaQR() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );

    if (result != null && result is String && result.startsWith('VL_QR:') && mounted) {
      try {
        // 1. Giải mã Base64 và xả nén Gzip
        final base64Str = result.substring(6);
        final compressed = base64Decode(base64Str);
        final bytes = gzip.decode(compressed);
        final jsonString = utf8.decode(bytes);
        
        final List<dynamic> decoded = jsonDecode(jsonString);
        final dsMoi = decoded.map((e) => SuKien.fromJson(e as Map<String, dynamic>)).toList();
        
        if (dsMoi.isEmpty || !mounted) return;

        // 2. Bật Pop-up hỏi ý kiến
        final xacNhan = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Phát hiện nhắc lịch mới 🪄', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text('Hệ thống tìm thấy ${dsMoi.length} nhắc lịch từ mã QR. Bạn có muốn lưu vào máy không?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy bỏ')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Lưu ngay')),
            ],
          ),
        );

        if (xacNhan == true && mounted) {
          final provider = Provider.of<SuKienProvider>(context, listen: false);
          for (var sk in dsMoi) {
            await provider.capNhatSuKien(sk); 
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🎉 Đã lưu thành công ${dsMoi.length} nhắc lịch!')));
          }
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mã QR không hợp lệ hoặc bị lỗi!')));
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Consumer<SuKienProvider>(
      builder: (context, provider, _) {
        final dsGoc = provider.danhSachSuKien;
        final dsTag = _layDanhSachTagDong(dsGoc);

        var ds = dsGoc;
        if (_selectedTags.isNotEmpty) {
          ds = ds.where((sk) {
            final raw = sk.tag?.trim() ?? '';
            final itemTags = raw.isEmpty ? <String>{} : raw.split(',').map((e) => e.trim()).toSet();
            if (_selectedTags.contains('Chưa gắn thẻ') && itemTags.isEmpty) return true;
            final regularTags = _selectedTags.where((t) => t != 'Chưa gắn thẻ');
            if (regularTags.isEmpty) return false;
            return regularTags.every((t) => itemTags.contains(t));
          }).toList();
        }

        final dsSapXep = List<SuKien>.from(ds);
        dsSapXep.sort((a, b) {
          final na = CalendarExport.tinhNgaySuKien(a);
          final nb = CalendarExport.tinhNgaySuKien(b);
          if (na == null && nb == null) return 0;
          if (na == null) return 1;
          if (nb == null) return -1;
          return na.compareTo(nb);
        });

        return Scaffold(
          appBar: _isSelecting
              ? AppBar(
                  leading: IconButton(icon: const Icon(Icons.close), onPressed: _tatCheDoChon),
                  title: Text('Đã chọn ${_selectedIds.length}'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.select_all),
                      tooltip: 'Chọn tất cả',
                      onPressed: () {
                        setState(() {
                          if (_selectedIds.length == dsSapXep.length) {
                            _selectedIds.clear();
                          } else {
                            _selectedIds.addAll(dsSapXep.map((e) => e.id));
                          }
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_2), // Đổi icon share thành icon QR
                      tooltip: 'Tạo mã QR',
                      onPressed: _selectedIds.isEmpty ? null : () => _chiaSeQuaQR(dsGoc),
                    ),
                  ],
                )
              : AppBar(
                  title: const Text('Nhắc lịch'),
                  centerTitle: true,
                  actions: [
                    // NÚT MỞ CAMERA QUÉT QR
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      tooltip: 'Quét mã QR nhận lịch',
                      onPressed: _quetMaQR,
                    ),
                    if (dsGoc.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.checklist_rtl),
                        tooltip: 'Chọn nhiều',
                        onPressed: () => _batCheDoChon(),
                      ),
                  ],
                ),
          body: dsGoc.isEmpty
              ? _EmptyState()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: dsTag.map((tag) {
                          final bool isSelected = tag == 'Tất cả' ? _selectedTags.isEmpty : _selectedTags.contains(tag);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(tag),
                              selected: isSelected,
                              showCheckmark: tag != 'Tất cả',
                              onSelected: (val) {
                                setState(() {
                                  if (tag == 'Tất cả') {
                                    _selectedTags.clear();
                                  } else {
                                    if (val) {
                                      _selectedTags.add(tag);
                                    } else {
                                      _selectedTags.remove(tag);
                                    }
                                  }
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    if (dsSapXep.isEmpty)
                      const Expanded(child: Center(child: Text('Không tìm thấy nhắc lịch phù hợp bộ lọc.')))
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 88),
                          itemCount: dsSapXep.length,
                          itemBuilder: (context, index) {
                            final item = dsSapXep[index];
                            final isChecked = _selectedIds.contains(item.id);
                            return _ItemSuKien(
                              suKien: item,
                              isSelecting: _isSelecting,
                              isSelected: isChecked,
                              onToggleSelect: () => _toggleChonItem(item.id),
                              onLongPress: () {
                                if (!_isSelecting) _batCheDoChon(item.id);
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
          floatingActionButton: _isSelecting
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThemSuaSuKienScreen())),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm nhắc lịch'),
                ),
        );
      },
    );
  }
}

// ==== GIAO DIỆN PHỤ (GIỮ NGUYÊN) ====
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 80, color: theme.colorScheme.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('Chưa có nhắc lịch nào', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
            const SizedBox(height: 8),
            Text('Nhấn nút "Thêm nhắc lịch" bên dưới để tạo nhắc ngày giỗ, lễ theo âm lịch.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

class _ItemSuKien extends StatelessWidget {
  final SuKien suKien;
  final bool isSelecting;
  final bool isSelected;
  final VoidCallback onToggleSelect;
  final VoidCallback onLongPress;

  const _ItemSuKien({
    required this.suKien,
    required this.isSelecting,
    required this.isSelected,
    required this.onToggleSelect,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ngaySuKien = CalendarExport.tinhNgaySuKien(suKien);
    final ngayBao = CalendarExport.tinhNgayBao(suKien);

    String ngayText = '${suKien.ngayAm}/${suKien.thangAm} âm lịch';
    if (ngaySuKien != null) ngayText += '  •  ${DateFormat('dd/MM/yyyy', 'vi').format(ngaySuKien)}';

    final gioText = 'Nhắc lúc ${suKien.gioNhac.toString().padLeft(2, '0')}:${suKien.phutNhac.toString().padLeft(2, '0')}';
    String baoText = suKien.baoTruoc == 0 ? 'Không báo' : 'Báo trước ${suKien.baoTruoc} ngày';
    if (ngayBao != null) baoText += ' (${DateFormat('dd/MM', 'vi').format(ngayBao)})';

    List<String> eventTags = [];
    if (suKien.tag != null && suKien.tag!.trim().isNotEmpty) {
      eventTags = suKien.tag!.split(',').map((e) => e.trim()).toList();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: isSelecting
            ? Checkbox(value: isSelected, onChanged: (_) => onToggleSelect())
            : _AvatarSuKien(duongDanAnh: suKien.duongDanAnh),
        title: Row(
          children: [
            Expanded(child: Text(suKien.ten, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (suKien.daXuatLich) Padding(padding: const EdgeInsets.only(left: 6), child: Icon(Icons.event_available, size: 16, color: Colors.green.shade600)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ngayText, style: const TextStyle(fontSize: 13, color: Colors.red)),
              const SizedBox(height: 2),
              Text('$gioText  •  $baoText', style: TextStyle(fontSize: 12, color: theme.colorScheme.primary)),
              if (eventTags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: eventTags.map((t) => Text('#$t', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade700))).toList(),
                  ),
                ),
            ],
          ),
        ),
        trailing: isSelecting ? null : const Icon(Icons.chevron_right),
        onTap: () {
          if (isSelecting) {
            onToggleSelect();
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ThemSuaSuKienScreen(suKien: suKien)));
          }
        },
        onLongPress: onLongPress,
      ),
    );
  }
}

class _AvatarSuKien extends StatelessWidget {
  final String? duongDanAnh;
  const _AvatarSuKien({required this.duongDanAnh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget child;
    if (duongDanAnh != null && File(duongDanAnh!).existsSync()) {
      child = ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.file(File(duongDanAnh!), width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder(theme)));
    } else {
      child = _placeholder(theme);
    }
    return SizedBox(width: 48, height: 48, child: child);
  }

  Widget _placeholder(ThemeData theme) {
    return Container(decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, shape: BoxShape.circle), child: Icon(Icons.event, color: theme.colorScheme.primary));
  }
}