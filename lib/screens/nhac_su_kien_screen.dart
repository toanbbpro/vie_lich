import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/su_kien.dart';
import '../providers/su_kien_provider.dart';
import '../services/calendar_export.dart';
import '../services/data_transfer_service.dart';
import 'them_sua_su_kien_screen.dart';

class NhacSuKienScreen extends StatefulWidget {
  const NhacSuKienScreen({super.key});

  @override
  State<NhacSuKienScreen> createState() => _NhacSuKienScreenState();
}

class _NhacSuKienScreenState extends State<NhacSuKienScreen> {
  String _selectedTag = 'Tất cả';

  // Hàm quét toàn bộ dữ liệu để lấy danh sách Tag tự động
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

  Future<void> _nhapDuLieu(BuildContext context) async {
    final provider = Provider.of<SuKienProvider>(context, listen: false);
    final dsMoi = await DataTransferService.importFromJson();

    if (dsMoi == null) return;

    int count = 0;
    for (var sk in dsMoi) {
      await provider.capNhatSuKien(sk);
      count++;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã khôi phục $count sự kiện!')));
    }
  }

  Future<void> _xuatDuLieu(BuildContext context, List<SuKien> ds) async {
    if (ds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có dữ liệu để xuất')));
      return;
    }
    await DataTransferService.exportAndShare(ds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhắc lịch'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Khôi phục từ file JSON',
            onPressed: () => _nhapDuLieu(context),
          ),
          Consumer<SuKienProvider>(
            builder: (ctx, provider, _) => IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Chia sẻ / Sao lưu',
              onPressed: () => _xuatDuLieu(context, provider.danhSachSuKien),
            ),
          ),
        ],
      ),
      body: Consumer<SuKienProvider>(
        builder: (context, provider, _) {
          final dsGoc = provider.danhSachSuKien;

          if (dsGoc.isEmpty) return _EmptyState();

          // Lấy danh sách Tag động từ dữ liệu thực tế
          final dsTag = _layDanhSachTagDong(dsGoc);

          // Đề phòng trường hợp User vừa xóa sự kiện cuối cùng chứa Tag đang chọn
          String activeTag = _selectedTag;
          if (!dsTag.contains(activeTag)) {
            activeTag = 'Tất cả';
          }

          // Lọc sự kiện theo Tag
          var ds = dsGoc;
          if (activeTag == 'Chưa gắn thẻ') {
            ds = ds
                .where((sk) => sk.tag == null || sk.tag!.trim().isEmpty)
                .toList();
          } else if (activeTag != 'Tất cả') {
            ds = ds.where((sk) {
              if (sk.tag == null || sk.tag!.trim().isEmpty) return false;
              final list = sk.tag!.split(',').map((e) => e.trim());
              return list.contains(activeTag);
            }).toList();
          }

          // Sắp xếp ngày gần nhất
          final dsSapXep = List<SuKien>.from(ds);
          dsSapXep.sort((a, b) {
            final na = CalendarExport.tinhNgaySuKien(a);
            final nb = CalendarExport.tinhNgaySuKien(b);
            if (na == null && nb == null) return 0;
            if (na == null) return 1;
            if (nb == null) return -1;
            return na.compareTo(nb);
          });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thanh cuộn Tag ngang động
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: dsTag.map((tag) {
                    final isSelected = activeTag == tag;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(tag),
                        selected: isSelected,
                        showCheckmark: false,
                        onSelected: (val) => setState(() => _selectedTag = tag),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Danh sách
              if (dsSapXep.isEmpty)
                const Expanded(
                    child: Center(
                        child: Text('Không có sự kiện nào trong nhóm này.')))
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: dsSapXep.length,
                    itemBuilder: (context, index) {
                      return _ItemSuKien(suKien: dsSapXep[index]);
                    },
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ThemSuaSuKienScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Thêm sự kiện'),
      ),
    );
  }
}

// ==== GIAO DIỆN PHỤ ====
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
            Icon(Icons.notifications_none,
                size: 80,
                color: theme.colorScheme.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('Chưa có sự kiện nào',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary)),
            const SizedBox(height: 8),
            Text(
                'Nhấn nút "Thêm sự kiện" bên dưới để tạo nhắc ngày giỗ, lễ theo âm lịch.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

class _ItemSuKien extends StatelessWidget {
  final SuKien suKien;
  const _ItemSuKien({required this.suKien});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ngaySuKien = CalendarExport.tinhNgaySuKien(suKien);
    final ngayBao = CalendarExport.tinhNgayBao(suKien);

    String ngayText = '${suKien.ngayAm}/${suKien.thangAm} âm lịch';
    if (ngaySuKien != null) {
      ngayText += '  •  ${DateFormat('dd/MM/yyyy', 'vi').format(ngaySuKien)}';
    }

    final gioText =
        'Nhắc lúc ${suKien.gioNhac.toString().padLeft(2, '0')}:${suKien.phutNhac.toString().padLeft(2, '0')}';
    String baoText = suKien.baoTruoc == 0
        ? 'Không báo'
        : 'Báo trước ${suKien.baoTruoc} ngày';
    if (ngayBao != null) {
      baoText += ' (${DateFormat('dd/MM', 'vi').format(ngayBao)})';
    }

    // Tách chuỗi tag ra để vẽ nhiều cái Label nhỏ
    List<String> eventTags = [];
    if (suKien.tag != null && suKien.tag!.trim().isNotEmpty) {
      eventTags = suKien.tag!.split(',').map((e) => e.trim()).toList();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: _AvatarSuKien(duongDanAnh: suKien.duongDanAnh),
        title: Row(
          children: [
            Expanded(
                child: Text(suKien.ten,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
            if (suKien.daXuatLich)
              Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(Icons.event_available,
                      size: 16, color: Colors.green.shade600)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ngayText,
                  style: const TextStyle(fontSize: 13, color: Colors.red)),
              const SizedBox(height: 2),
              Text('$gioText  •  $baoText',
                  style: TextStyle(
                      fontSize: 12, color: theme.colorScheme.primary)),
              if (eventTags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: eventTags
                        .map((t) => Text('#$t',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700)))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ThemSuaSuKienScreen(suKien: suKien))),
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
      child = ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.file(File(duongDanAnh!),
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(theme)));
    } else {
      child = _placeholder(theme);
    }
    return SizedBox(width: 48, height: 48, child: child);
  }

  Widget _placeholder(ThemeData theme) {
    return Container(
        decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer, shape: BoxShape.circle),
        child: Icon(Icons.event, color: theme.colorScheme.primary));
  }
}
