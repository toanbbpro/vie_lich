import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hive_ce/hive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:in_app_update/in_app_update.dart';
import 'dart:io';

import '../models/su_kien.dart';
import '../providers/su_kien_provider.dart';
import '../services/app_update_service.dart';
import '../services/backup_service.dart';
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

  Future<void> _togglePhatThu() async {
    if (_dangPhat) {
      await _audioPlayer.stop();
      if (mounted) setState(() => _dangPhat = false);
      return;
    }

    try {
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

  Future<void> _xuLyChonAmTuChinh() async {
    if (_soundType == SoundType.custom && _customFileName != null) {
      await _togglePhatThu();
      return;
    }

    if (_customFileName != null) {
      await SoundSettings.setType(SoundType.custom);
      final box = Hive.box<SuKien>('suKienBox');
      await NotificationService.khoiPhucSauDoiAm(box.values.toList());
      if (!mounted) return;
      setState(() => _soundType = SoundType.custom);
      await _togglePhatThu();
      return;
    }

    final daChon = await _chonFileAmThanh();
    if (!mounted) return;
    if (!daChon) {
      setState(() => _soundType = SoundType.system);
    } else {
      await _togglePhatThu();
    }
  }

  Future<bool> _chonFileAmThanh() async {
    await _dungAudio();

    try {
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
      final success =
          await SoundSettings.saveCustomSound(sourcePath, originalName);
      if (!success) {
        if (!mounted) return false;
        _thongBao('Lỗi lưu file âm thanh');
        return false;
      }

      await SoundSettings.setType(SoundType.custom);
      await NotificationService.recreateCustomChannel();

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

  Future<void> _dungAmHeThong() async {
    await _dungAudio();
    await SoundSettings.setType(SoundType.system);

    final box = Hive.box<SuKien>('suKienBox');
    await NotificationService.khoiPhucSauDoiAm(box.values.toList());

    if (!mounted) return;
    setState(() => _soundType = SoundType.system);
    _thongBao('Đã chuyển sang âm hệ thống');
  }

  Future<void> _xinQuyenThongBao() async {
    if (Platform.isMacOS) {
      final macOSPlugin = FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>();

      final granted = await macOSPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      if (mounted) {
        _thongBao(granted == true
            ? 'Đã cấp quyền thông báo trên Mac!'
            : 'Chưa cấp quyền. Vui lòng mở System Settings.');
      }
      return;
    }
    if (Platform.isWindows) {
      _thongBao('Windows không cần cấp quyền thông báo');
      return;
    }
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

  /// ===== SAO LƯU =====
  Future<void> _saoLuuDuLieu() async {
    final provider = Provider.of<SuKienProvider>(context, listen: false);
    final ok = await BackupService.taoBanSaoLuu(provider.danhSachSuKien);
    if (ok && mounted) {
      _thongBao('Đã tạo bản sao lưu hoàn tất');
    }
  }

  /// ===== KHÔI PHỤC =====
  Future<void> _khoiPhucDuLieu() async {
    final data = await BackupService.khoiPhucSaoLuu();
    if (data == null) return;
    if (data.containsKey('events') && mounted) {
      final provider = Provider.of<SuKienProvider>(context, listen: false);
      final List<dynamic> eventsRaw = data['events'];
      int count = 0;
      for (var item in eventsRaw) {
        final sk = SuKien.fromJson(item as Map<String, dynamic>);
        await provider.capNhatSuKien(sk);
        count++;
      }
      if (mounted) {
        _thongBao('Đã khôi phục $count lịch!');
      }
    }
  }

  // ============================================================
  // IN-APP UPDATE (PLAY STORE)
  // ============================================================
  Future<void> _kiemTraCapNhatPlayStore() async {
    final info = await AppUpdateService.checkForUpdate();

    if (!mounted) return;
    if (info == null) {
      _thongBao('Không thể kiểm tra cập nhật');
      return;
    }

    if (info.updateAvailability == UpdateAvailability.updateAvailable) {
      await _hienThiDialogCapNhat(info);
    } else {
      if (!mounted) return;
      _thongBao('Bạn đang dùng bản mới nhất');
    }
  }

  Future<void> _hienThiDialogCapNhat(AppUpdateInfo info) async {
    if (!mounted) return;

    final luaChon = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Có bản cập nhật mới'),
        content: const Text(
          'Phiên bản mới đã có sẵn trên Google Play.\n\n'
          '• Cập nhật ngay: Tải ngầm, bạn tiếp tục dùng app.\n'
          '• Cập nhật buộc: Khởi động lại app để áp dụng ngay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'later'),
            child: const Text('Để sau'),
          ),
          if (info.flexibleUpdateAllowed)
            TextButton(
              onPressed: () => Navigator.pop(context, 'flexible'),
              child: const Text('Cập nhật ngay'),
            ),
          if (info.immediateUpdateAllowed)
            FilledButton(
              onPressed: () => Navigator.pop(context, 'immediate'),
              child: const Text('Cập nhật buộc'),
            ),
        ],
      ),
    );

    if (!mounted) return;
    if (luaChon == null || luaChon == 'later') return;

    if (luaChon == 'flexible') {
      final ok = await AppUpdateService.startFlexibleUpdate();
      if (!mounted) return;
      if (ok) {
        _thongBao('Đang tải bản cập nhật ở chế độ nền...');
      }
    } else if (luaChon == 'immediate') {
      await AppUpdateService.startImmediateUpdate();
    }
  }

  // ============================================================
  // DIALOG ỦNG HỘ
  // ============================================================
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
              children: const [
                Icon(Icons.coffee, size: 28, color: Colors.brown),
                SizedBox(width: 8),
                Text(
                  'Ủng hộ tác giả',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Nếu bạn thấy ứng dụng hữu ích, hãy mời mình một ly cà phê nhé!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
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

  // ============================================================
  // DIALOG THÔNG TIN THÊM
  // ============================================================
  void _hienThiDialogThongTin() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/icon/vie_lich_logo.png',
                width: 60,
                height: 60,
              ),
              const SizedBox(height: 10),
              const Text(
                'VIE Lịch',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'App lịch Việt cho người Việt',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Dùng thuật toán Hồ Ngọc Đức (UTC+7)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _moUrl('https://www.facebook.com/toanbb.pro/'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person, size: 18, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'Tác giả: Toàn BB',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade700,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () => _moUrl(
                        'mailto:toanbb.dev@gmail.com?subject=Góp ý ứng dụng VIE Lịch'),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      child: Row(
                        children: [
                          Icon(Icons.email_outlined,
                              size: 18, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            'Email',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade700,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () =>
                        _moUrl('https://github.com/toanbbpro/vie_lich'),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      child: Row(
                        children: [
                          Icon(Icons.code,
                              size: 18, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            'Github',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade700,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Vibe code cùng Gemini và Deepseek chat',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const bool isPlayStore =
        bool.fromEnvironment('PLAY_STORE', defaultValue: false);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
          children: [
            // ===================== ÂM THANH THÔNG BÁO =====================
            _SectionCard(
              title: 'Âm thanh thông báo',
              child: _loadingSound
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : RadioGroup<SoundType>(
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
                          _AmHeThongTile(
                            theme: theme,
                            laChon: _soundType == SoundType.system,
                            onTap: () {
                              if (_soundType != SoundType.system) {
                                _dungAmHeThong();
                              }
                            },
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
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
            ),

            const SizedBox(height: 16),

            // ===================== CẤU HÌNH =====================
            _SectionCard(
              title: 'Cấu hình',
              topPadding: 20,
              child: Column(
                children: [
                  _ItemCauHinh(
                    icon: Icons.notifications_active_outlined,
                    iconBg: Colors.pink.shade50,
                    iconColor: Colors.pink.shade300,
                    title: 'Cấp quyền thông báo',
                    onTap: _xinQuyenThongBao,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _ItemCauHinh(
                    icon: Icons.cloud_upload_outlined,
                    iconBg: Colors.blue.shade50,
                    iconColor: Colors.blue,
                    title: 'Sao lưu dữ liệu',
                    onTap: _saoLuuDuLieu,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _ItemCauHinh(
                    icon: Icons.cloud_download_outlined,
                    iconBg: Colors.green.shade50,
                    iconColor: Colors.green,
                    title: 'Khôi phục dữ liệu',
                    onTap: _khoiPhucDuLieu,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ===================== THÔNG TIN =====================
            _SectionCard(
              title: 'Thông tin',
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/icon/vie_lich_logo.png',
                          width: 50,
                          height: 50,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'VIE Lịch',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Phiên bản v$_version',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          if (isPlayStore) {
                            await _kiemTraCapNhatPlayStore();
                          } else {
                            if (!mounted) return;
                            GithubUpdateService.checkUpdate(
                              context,
                              showNoUpdate: true,
                            );
                          }
                        },
                        icon:
                            const Icon(Icons.system_update_outlined, size: 16),
                        label: const Text(
                          'Kiểm tra cập nhật',
                          style: TextStyle(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _hienThiDialogUngHo,
                          icon: const Icon(Icons.coffee, size: 16),
                          label: const Text(
                            'Ủng hộ',
                            style: TextStyle(fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _hienThiDialogThongTin,
                          icon: const Icon(Icons.info_outline, size: 16),
                          label: const Text(
                            'Thông tin',
                            style: TextStyle(fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// SECTION CARD
/// ============================================================
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final double topPadding;

  const _SectionCard({
    required this.title,
    required this.child,
    this.topPadding = 8,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: EdgeInsets.only(top: topPadding),
              child: child,
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ===== TILE ÂM HỆ THỐNG =====
class _AmHeThongTile extends StatelessWidget {
  final ThemeData theme;
  final bool laChon;
  final VoidCallback onTap;

  const _AmHeThongTile({
    required this.theme,
    required this.laChon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              const SizedBox(width: 12),
              IgnorePointer(
                child: Radio<SoundType>(value: SoundType.system),
              ),
              Expanded(
                child: Text(
                  'Âm hệ thống',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              SizedBox(
                width: 52,
                height: double.infinity,
                child: Icon(
                  laChon ? Icons.volume_up : Icons.volume_off_outlined,
                  size: 26,
                  color: laChon ? theme.colorScheme.primary : null,
                ),
              ),
              const SizedBox(width: 52),
              const SizedBox(width: 4),
            ],
          ),
        ),
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
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// ===== ITEM CẤU HÌNH =====
class _ItemCauHinh extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  const _ItemCauHinh({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconBg,
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}