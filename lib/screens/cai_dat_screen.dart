import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hive_ce/hive.dart';
import 'package:file_picker/file_picker.dart';

import '../models/su_kien.dart';
import '../services/notification_service.dart';
import '../services/sound_settings.dart';

class CaiDatScreen extends StatefulWidget {
  const CaiDatScreen({super.key});

  @override
  State<CaiDatScreen> createState() => _CaiDatScreenState();
}

class _CaiDatScreenState extends State<CaiDatScreen> {
  String _version = '...';
  String _buildNumber = '';
  SoundType _soundType = SoundType.system;
  String? _customFileName;
  bool _loadingSound = true;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadSoundSetting();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = info.version;
        _buildNumber = info.buildNumber;
      });
    } catch (_) {}
  }

  Future<void> _loadSoundSetting() async {
    final type = await SoundSettings.getType();
    final name = await SoundSettings.getCustomFileName();
    if (!mounted) return;
    setState(() {
      _soundType = type;
      _customFileName = name;
      _loadingSound = false;
    });
  }

  /// ===== CHỌN FILE ÂM THANH =====
  Future<void> _chonFileAmThanh() async {
    try {
      // file_picker v13: dùng static method, không có .platform
      // Trả về List<PlatformFile> trực tiếp
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'ogg', 'aac'],
        dialogTitle: 'Chọn file âm thanh thông báo',
      );

      if (files.isEmpty) return;
      final sourcePath = files.first.path;
      if (sourcePath == null) {
        if (!mounted) return;
        _thongBao('Không đọc được đường dẫn file');
        return;
      }

      await SoundSettings.copySoundFile(sourcePath);
      await SoundSettings.setType(SoundType.custom);

      // Tạo lại channel custom với âm mới
      await NotificationService.recreateCustomChannel();

      // Khôi phục lịch để dùng âm mới
      final box = Hive.box<SuKien>('suKienBox');
      await NotificationService.khoiPhucSauDoiAm(box.values.toList());

      final name = await SoundSettings.getCustomFileName();
      if (!mounted) return;
      setState(() {
        _soundType = SoundType.custom;
        _customFileName = name;
      });
      _thongBao('Đã chọn file: $name');
    } catch (e) {
      if (!mounted) return;
      _thongBao('Lỗi chọn file: $e');
    }
  }

  /// ===== ĐỔI SANG ÂM HỆ THỐNG =====
  Future<void> _dungAmHeThong() async {
    await SoundSettings.setType(SoundType.system);
    await SoundSettings.deleteCustomSound();

    final box = Hive.box<SuKien>('suKienBox');
    await NotificationService.khoiPhucSauDoiAm(box.values.toList());

    if (!mounted) return;
    setState(() {
      _soundType = SoundType.system;
      _customFileName = null;
    });
    _thongBao('Đã chuyển sang âm hệ thống');
  }

  /// ===== XIN QUYỀN THÔNG BÁO =====
  Future<void> _xinQuyenThongBao() async {
    final status = await Permission.notification.status;
    if (status.isGranted) {
      _thongBao('Quyền thông báo đã được cấp');
      return;
    }
    final result = await Permission.notification.request();
    if (!mounted) return;
    if (result.isGranted) {
      _thongBao('Đã cấp quyền thông báo');
    } else if (result.isPermanentlyDenied) {
      _hienDialogMoCaiDat(
        'Quyền thông báo bị từ chối vĩnh viễn. Vui lòng mở Cài đặt để bật thủ công.',
      );
    } else {
      _thongBao('Bạn đã từ chối quyền thông báo');
    }
  }

  void _hienDialogMoCaiDat(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cần quyền'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Mở Cài đặt'),
          ),
        ],
      ),
    );
  }

  void _thongBao(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _moUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _thongBao('Không mở được liên kết');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ===== PHẦN: ÂM THANH THÔNG BÁO =====
          const _TieuDeSection(text: 'Âm thanh thông báo'),
          if (_loadingSound)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            RadioGroup<SoundType>(
              groupValue: _soundType,
              onChanged: (v) {
                if (v == SoundType.system) {
                  if (_soundType != SoundType.system) _dungAmHeThong();
                } else if (v == SoundType.custom) {
                  _chonFileAmThanh();
                }
              },
              child: Column(
                children: [
                  RadioListTile<SoundType>(
                    value: SoundType.system,
                    title: const Text('Âm hệ thống'),
                    subtitle: const Text('Dùng âm mặc định của thiết bị'),
                    secondary: Icon(
                      _soundType == SoundType.system
                          ? Icons.volume_up
                          : Icons.volume_off_outlined,
                      color: _soundType == SoundType.system
                          ? theme.colorScheme.primary
                          : null,
                    ),
                  ),
                  RadioListTile<SoundType>(
                    value: SoundType.custom,
                    title: const Text('Âm tùy chỉnh'),
                    subtitle: Text(
                      _customFileName ?? 'Chưa chọn file',
                      style: TextStyle(
                        color: _customFileName != null
                            ? theme.colorScheme.primary
                            : Colors.grey.shade600,
                      ),
                    ),
                    secondary: Icon(
                      _soundType == SoundType.custom
                          ? Icons.music_note
                          : Icons.music_off_outlined,
                      color: _soundType == SoundType.custom
                          ? theme.colorScheme.primary
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          if (!_loadingSound && _soundType == SoundType.custom)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: _chonFileAmThanh,
                icon: const Icon(Icons.folder_open),
                label: Text(
                  _customFileName == null
                      ? 'Chọn file âm thanh'
                      : 'Đổi file âm thanh',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Lưu ý: File âm thanh nên là MP3, WAV, OGG hoặc M4A. '
              'Thông báo đã lên lịch sẽ được tạo lại với âm mới.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
              ),
            ),
          ),

          const Divider(height: 32),

          // ===== PHẦN: QUYỀN =====
          const _TieuDeSection(text: 'Quyền truy cập'),
          _ItemCaiDat(
            icon: Icons.notifications_active_outlined,
            title: 'Quyền thông báo',
            subtitle: 'Nhận nhắc nhở khi tới ngày giỗ, lễ',
            onTap: _xinQuyenThongBao,
          ),

          const Divider(height: 32),

          // ===== PHẦN: THÔNG TIN =====
          const _TieuDeSection(text: 'Thông tin ứng dụng'),
          _ItemCaiDat(
            icon: Icons.info_outline,
            title: 'Phiên bản',
            subtitle: _buildNumber.isEmpty
                ? _version
                : '$_version (build $_buildNumber)',
            onTap: null,
          ),
          _ItemCaiDat(
            icon: Icons.person_outline,
            title: 'Tác giả',
            subtitle: 'ToanBB',
            onTap: null,
          ),

          const Divider(height: 32),

          // ===== PHẦN: LIÊN HỆ =====
          const _TieuDeSection(text: 'Liên hệ & Hỗ trợ'),
          _ItemCaiDat(
            icon: Icons.email_outlined,
            title: 'Gửi email góp ý',
            subtitle: 'your-email@example.com',
            onTap: () => _moUrl(
                'mailto:your-email@example.com?subject=Góp ý ứng dụng Âm lịch'),
          ),
          _ItemCaiDat(
            icon: Icons.code,
            title: 'Mã nguồn',
            subtitle: 'github.com/your-username/vie_lich',
            onTap: () => _moUrl('https://github.com/your-username/vie_lich'),
          ),

          const SizedBox(height: 24),

          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.calendar_month,
                    size: 40,
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ứng dụng Âm lịch Việt Nam',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dùng thuật toán Hồ Ngọc Đức (UTC+7)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _TieuDeSection extends StatelessWidget {
  final String text;
  const _TieuDeSection({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _ItemCaiDat extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ItemCaiDat({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(icon, color: theme.colorScheme.primary, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
      ),
      trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
  }
}
