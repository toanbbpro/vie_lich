import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Bổ sung thư viện này để dùng Clipboard
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hive_ce/hive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import '../providers/su_kien_provider.dart';
import '../services/backup_service.dart';
import '../models/su_kien.dart';
import '../services/github_update_service.dart';
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
  bool _dangPhat = false;

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _cauHinhAudioPlayer();
    _loadVersion();
    _loadSoundSetting();
  }

  void _cauHinhAudioPlayer() {
    _audioPlayer.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
      ),
    );

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _dangPhat = false);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
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

  /// ===== PHÁT / DỪNG ÂM THANH TÙY CHỈNH =====
  Future<void> _togglePhatThu() async {
    if (_dangPhat) {
      await _audioPlayer.stop();
      if (mounted) setState(() => _dangPhat = false);
      return;
    }

    try {
      // Phát từ file local trong app (không cần permission)
      final localPath = await SoundSettings.getCustomSoundLocalPath();
      if (localPath == null) {
        _thongBao('Chưa có file âm thanh');
        return;
      }

      final file = File(localPath);
      if (!file.existsSync()) {
        _thongBao('File âm thanh không tồn tại');
        return;
      }

      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(localPath));
      if (mounted) setState(() => _dangPhat = true);
    } catch (e) {
      if (mounted) setState(() => _dangPhat = false);
      _thongBao('Không phát được âm thanh: $e');
    }
  }

  Future<void> _dungAudio() async {
    if (_dangPhat) {
      await _audioPlayer.stop();
      if (mounted) setState(() => _dangPhat = false);
    }
  }

  /// ===== TAP RADIO "ÂM TÙY CHỈNH" =====
  Future<void> _xuLyChonAmTuChinh() async {
    // Đang ở custom + có file → toggle phát/dừng
    if (_soundType == SoundType.custom && _customFileName != null) {
      await _togglePhatThu();
      return;
    }

    // Có file sẵn → chuyển sang custom + phát
    if (_customFileName != null) {
      await SoundSettings.setType(SoundType.custom);

      final box = Hive.box<SuKien>('suKienBox');
      await NotificationService.khoiPhucSauDoiAm(box.values.toList());

      if (!mounted) return;
      setState(() => _soundType = SoundType.custom);

      await _togglePhatThu();
      return;
    }

    // Chưa có file → mở picker
    final daChon = await _chonFileAmThanh();
    if (!mounted) return;
    if (!daChon) {
      setState(() => _soundType = SoundType.system);
    } else {
      await _togglePhatThu();
    }
  }

  /// ===== CHỌN FILE ÂM THANH (dùng MediaStore) =====
  Future<bool> _chonFileAmThanh() async {
    await _dungAudio();

    try {
      // Xin quyền đọc audio trên Android 13+
      if (Platform.isAndroid) {
        final status = await Permission.audio.status;
        if (!status.isGranted) {
          final req = await Permission.audio.request();
          if (!req.isGranted) {
            if (!mounted) return false;
            _thongBao('Cần quyền truy cập âm thanh để chọn file');
            return false;
          }
        }
      }

      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'ogg', 'aac'],
        dialogTitle: 'Chọn file âm thanh thông báo',
      );

      if (files.isEmpty) return false;
      final sourcePath = files.first.path;
      if (sourcePath == null) {
        if (!mounted) return false;
        _thongBao('Không đọc được đường dẫn file');
        return false;
      }

      final originalName = sourcePath.split('/').last;

      // Lưu vào MediaStore qua SoundSettings
      final success =
          await SoundSettings.saveCustomSound(sourcePath, originalName);
      if (!success) {
        if (!mounted) return false;
        _thongBao('Lỗi lưu file âm thanh vào MediaStore');
        return false;
      }

      await SoundSettings.setType(SoundType.custom);

      // Tạo lại channel custom với URI mới
      await NotificationService.recreateCustomChannel();

      // Khôi phục lịch để dùng âm mới
      final box = Hive.box<SuKien>('suKienBox');
      await NotificationService.khoiPhucSauDoiAm(box.values.toList());

      final name = await SoundSettings.getCustomFileName();
      if (!mounted) return false;
      setState(() {
        _soundType = SoundType.custom;
        _customFileName = name;
      });
      _thongBao('Đã chọn file: $name');
      return true;
    } catch (e) {
      if (!mounted) return false;
      _thongBao('Lỗi chọn file: $e');
      return false;
    }
  }

  /// ===== CHUYỂN SANG ÂM HỆ THỐNG =====
  Future<void> _dungAmHeThong() async {
    await _dungAudio();

    await SoundSettings.setType(SoundType.system);
    // KHÔNG xóa file custom — giữ lại để dùng sau

    final box = Hive.box<SuKien>('suKienBox');
    await NotificationService.khoiPhucSauDoiAm(box.values.toList());

    if (!mounted) return;
    setState(() => _soundType = SoundType.system);
    _thongBao('Đã chuyển sang âm hệ thống (file tùy chỉnh vẫn được giữ)');
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

  /// ===== HIỂN THỊ DIALOG ỦNG HỘ (BUY ME A COFFEE) =====
  void _hienThiDialogUngHo() {
    const bankId = 'tpbank';
    const accountNo = '91196797979';
    const accountName = 'LE THANH TOAN';
    const content = 'VIE Lich supporter';

    final qrUrl =
        'https://img.vietqr.io/image/$bankId-$accountNo-compact2.png?&addInfo=${Uri.encodeComponent(content)}&accountName=${Uri.encodeComponent(accountName)}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.coffee, size: 28, color: Colors.brown),
                const SizedBox(width: 8),
                const Text(
                  'Ủng hộ tác giả',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Nếu bạn thấy ứng dụng hữu ích, hãy mời mình một ly cà phê nhé! Cảm ơn bạn rất nhiều.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // Mã QR Code
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                    color: Colors
                        .grey.shade200), // Làm viền nhạt đi cho tiệp màu nền
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  qrUrl,
                  height: 250,
                  width: 250,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const SizedBox(
                      height: 250,
                      width: 250,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 250,
                    width: 250,
                    child: Center(
                      child: Text('Lỗi tải mã QR.\nVui lòng kiểm tra mạng.',
                          textAlign: TextAlign.center),
                    ),
                  ),
                ),
              ),
            ),

            // Nút Copy Số tài khoản
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: accountNo));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép số tài khoản')),
                );
              },
              icon: const Icon(Icons.copy, size: 14),
              label: const Text('Copy STK: $accountNo'),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFF5EBE1),
                minimumSize: const Size(double.infinity, 30),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
                  _xuLyChonAmTuChinh();
                }
              },
              child: Column(
                children: [
                  // ====== ÂM HỆ THỐNG ======
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

                  // ====== ÂM TÙY CHỈNH ======
                  _OCaiDatAmTuChinh(
                    theme: theme,
                    laChon: _soundType == SoundType.custom,
                    dangPhat: _dangPhat,
                    tenFile: _customFileName,
                    onChonRadio: _xuLyChonAmTuChinh,
                    onChonFile: () async {
                      final daChon = await _chonFileAmThanh();
                      if (daChon && mounted) {
                        await _togglePhatThu();
                      }
                    },
                    onTogglePhat:
                        _customFileName != null ? _togglePhatThu : null,
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Nhấn vào "Âm tùy chỉnh" để nghe thử hoặc dừng. '
              'Khi chuyển sang "Âm hệ thống", file tùy chỉnh vẫn được giữ lại. '
              'File âm thanh được lưu trữ an toàn để thông báo hoạt động ngay cả khi '
              'ứng dụng bị tắt.',
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
          // KHỐI SAO LƯU VÀ KHÔI PHỤC
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined,
                      color: Colors.blue),
                  title: const Text('Sao lưu dữ liệu'),
                  subtitle: const Text(
                      'Đóng gói toàn bộ nhắc lịch và cấu hình cài đặt'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final provider =
                        Provider.of<SuKienProvider>(context, listen: false);
                    final ok = await BackupService.taoBanSaoLuu(
                        provider.danhSachSuKien);
                    if (ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Đã tạo bản sao lưu hoàn tất')),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_download_outlined,
                      color: Colors.green),
                  title: const Text('Khôi phục dữ liệu'),
                  subtitle: const Text('Phục hồi dữ liệu từ file sao lưu JSON'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final data = await BackupService.khoiPhucSaoLuu();
                    if (data == null) {
                      return;
                    }

                    if (data.containsKey('events') && context.mounted) {
                      final provider =
                          Provider.of<SuKienProvider>(context, listen: false);
                      final List<dynamic> eventsRaw = data['events'];
                      int count = 0;
                      for (var item in eventsRaw) {
                        final sk =
                            SuKien.fromJson(item as Map<String, dynamic>);
                        await provider.capNhatSuKien(sk);
                        count++;
                      }

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Đã khôi phục thành công $count nhắc lịch và cài đặt!')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          // ===== PHẦN: THÔNG TIN =====
          const _TieuDeSection(text: 'Thông tin ứng dụng'),
          _ItemCaiDat(
            icon: Icons.info_outline,
            title: 'Phiên bản',
            subtitle: _buildNumber.isEmpty
                ? _version
                : '$_version build $_buildNumber',
            onTap: null,
          ),
          _ItemCaiDat(
            icon: Icons.person_outline,
            title: 'Tác giả',
            subtitle: 'ToanBB',
            onTap: null,
          ),
          _ItemCaiDat(
            icon: Icons.system_update_outlined,
            title: 'Kiểm tra cập nhật',
            subtitle: 'Tìm bản cập nhật mới trên GitHub',
            onTap: () {
              GithubUpdateService.checkUpdate(context, showNoUpdate: true);
            },
          ),

          const Divider(height: 32),

          // ===== PHẦN: LIÊN HỆ =====
          const _TieuDeSection(text: 'Liên hệ & Hỗ trợ'),
          _ItemCaiDat(
            icon: Icons.email_outlined,
            title: 'Gửi email góp ý',
            subtitle: 'toanbb.dev@gmail.com',
            onTap: () => _moUrl(
                'mailto:toanbb.dev@gmail.com?subject=Góp ý ứng dụng Âm lịch'),
          ),
          _ItemCaiDat(
            icon: Icons.code,
            title: 'Mã nguồn',
            subtitle: 'github.com/toanbbpro/vie_lich',
            onTap: () => _moUrl('https://github.com/toanbbpro/vie_lich'),
          ),

          const Divider(height: 1),
          // NÚT BUY ME A COFFEE
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.brown.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.coffee, color: Colors.brown),
            ),
            title: const Text(
              'Buy me a coffee',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.brown),
            ),
            subtitle: const Text('Mời mình một ly cà phê nhé'),
            trailing: const Icon(Icons.favorite, color: Colors.red),
            onTap: _hienThiDialogUngHo,
          ),

          const SizedBox(height: 24),

          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Image.asset(
                    'assets/icon/vie_lich_logo.png',
                    width: 40,
                    height: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'VIE Lịch - Ứng dụng Âm lịch Việt Nam',
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
                      fontSize: 10,
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

/// ===== TILE "ÂM TÙY CHỈNH" =====
class _OCaiDatAmTuChinh extends StatelessWidget {
  final ThemeData theme;
  final bool laChon;
  final bool dangPhat;
  final String? tenFile;
  final VoidCallback onChonRadio;
  final VoidCallback onChonFile;
  final VoidCallback? onTogglePhat;

  const _OCaiDatAmTuChinh({
    required this.theme,
    required this.laChon,
    required this.dangPhat,
    required this.tenFile,
    required this.onChonRadio,
    required this.onChonFile,
    required this.onTogglePhat,
  });

  @override
  Widget build(BuildContext context) {
    final coFile = tenFile != null;

    return SizedBox(
      height: 72,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onChonRadio,
          child: Row(
            children: [
              const SizedBox(width: 12),
              IgnorePointer(
                child: Radio<SoundType>(value: SoundType.custom),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Âm tùy chỉnh',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tenFile ?? (dangPhat ? 'Đang phát...' : 'Chưa chọn file'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: coFile
                            ? theme.colorScheme.primary
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 52,
                height: double.infinity,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onChonFile,
                    child: Icon(
                      Icons.folder_open,
                      size: 24,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 52,
                height: double.infinity,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTogglePhat,
                    child: Icon(
                      dangPhat ? Icons.stop_circle : Icons.play_circle_outline,
                      size: 30,
                      color: coFile
                          ? (dangPhat ? Colors.red : theme.colorScheme.primary)
                          : Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
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
