import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/su_kien.dart';
import '../providers/su_kien_provider.dart';
import '../services/calendar_export.dart';
import 'them_sua_su_kien_screen.dart';

class NhacSuKienScreen extends StatelessWidget {
  const NhacSuKienScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhắc lịch'),
        centerTitle: true,
      ),
      body: Consumer<SuKienProvider>(
        builder: (context, provider, _) {
          final ds = provider.danhSachSuKien;

          if (ds.isEmpty) {
            return _EmptyState();
          }

          // Sắp xếp theo ngày sắp tới gần nhất
          final dsSapXep = List<SuKien>.from(ds);
          dsSapXep.sort((a, b) {
            final na = CalendarExport.tinhNgaySuKien(a);
            final nb = CalendarExport.tinhNgaySuKien(b);
            if (na == null && nb == null) return 0;
            if (na == null) return 1;
            if (nb == null) return -1;
            return na.compareTo(nb);
          });

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 88),
            itemCount: dsSapXep.length,
            itemBuilder: (context, index) {
              return _ItemSuKien(suKien: dsSapXep[index]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ThemSuaSuKienScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Thêm sự kiện'),
      ),
    );
  }
}

/// ===== EMPTY STATE =====
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
            Icon(
              Icons.notifications_none,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có sự kiện nào',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nhấn nút "Thêm sự kiện" bên dưới để tạo nhắc ngày giỗ, lễ theo âm lịch.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===== ITEM SỰ KIỆN =====
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
      final fmt = DateFormat('dd/MM/yyyy', 'vi');
      ngayText += '  •  ${fmt.format(ngaySuKien)}';
    }

    final gio = suKien.gioNhac.toString().padLeft(2, '0');
    final phut = suKien.phutNhac.toString().padLeft(2, '0');
    final gioText = 'Nhắc lúc $gio:$phut';

    String baoText = suKien.baoTruoc == 0
        ? 'Không báo trước'
        : 'Báo trước ${suKien.baoTruoc} ngày';
    if (ngayBao != null) {
      final fmt = DateFormat('dd/MM', 'vi');
      baoText += '  •  ${fmt.format(ngayBao)}';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: _AvatarSuKien(duongDanAnh: suKien.duongDanAnh),
        title: Row(
          children: [
            Expanded(
              child: Text(
                suKien.ten,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (suKien.daXuatLich)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.event_available,
                  size: 16,
                  color: Colors.green.shade600,
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ngayText,
                style: const TextStyle(fontSize: 13, color: Colors.red),
              ),
              const SizedBox(height: 2),
              Text(
                '$gioText  •  $baoText',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                ),
              ),
              if (suKien.ghiChu != null && suKien.ghiChu!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  suKien.ghiChu!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ThemSuaSuKienScreen(suKien: suKien),
            ),
          );
        },
      ),
    );
  }
}

/// ===== AVATAR SỰ KIỆN =====
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
        child: Image.file(
          File(duongDanAnh!),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(theme),
        ),
      );
    } else {
      child = _placeholder(theme);
    }

    return SizedBox(width: 48, height: 48, child: child);
  }

  Widget _placeholder(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.event,
        color: theme.colorScheme.primary,
      ),
    );
  }
}
