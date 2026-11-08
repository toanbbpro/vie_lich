import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, pid, Process, ProcessSignal, ProcessStartMode, File, Directory;
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart' hide Image;
import 'package:tray_manager/tray_manager.dart' as tray show Image;
import 'package:in_app_update/in_app_update.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import 'models/su_kien.dart';
import 'providers/lich_provider.dart';
import 'providers/su_kien_provider.dart';
import 'providers/theme_provider.dart';
import 'services/app_update_service.dart';
import 'services/github_update_service.dart';
import 'services/windows_update_service.dart';
import 'services/notification_service.dart';
import 'services/deep_link_service.dart';
import 'services/schedule_writer.dart';
import 'services/auto_start_service.dart';
import 'screens/lich_ngay_screen.dart';
import 'screens/lich_thang_screen.dart';
import 'screens/nhac_su_kien_screen.dart';
import 'screens/cai_dat_screen.dart';
import 'services/linux_desktop_widget_service.dart';
import 'services/widget_service.dart';
import 'utils/am_lich_helper.dart';
import 'widgets/home_screen_widget_windows.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

const Size kWidgetSize = Size(420, 190);
const Size kMainSize = Size(1000, 700);
const double kSnapThreshold = 60.0;
const double kSnapMargin = 20.0;

// BIẾN TOÀN CỤC MỚI: Lắng nghe sự kiện chuyển tab từ Widget
final ValueNotifier<int> tabNotifier = ValueNotifier<int>(0);

const int kDailyAlarmId = 0;
const int kPeriodicAlarmId = 1;

const String kPrefLastUpdate = 'widget_last_update_date';
const String kPrefPermissionAsked = 'permission_asked_v1';

const String kStateFile = 'widget_state.json';
const String kEventsFile = 'widget_events.json';

String _formatDate(DateTime d) {
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ============================================================
// FILE-BASED IPC — giữa main window ↔ widget window
// ============================================================
String? _getDataDir() {
  if (Platform.isWindows) {
    final appData = Platform.environment['APPDATA'];
    if (appData != null) return '$appData\\vie_lich';
  } else if (Platform.isMacOS) {
    final home = Platform.environment['HOME'];
    if (home != null) return '$home/Library/Application Support/vie_lich';
  }
  return null;
}

Future<Map<String, dynamic>> _readState() async {
  final dir = _getDataDir();
  if (dir == null) return {};
  final file = File('$dir/$kStateFile');
  for (int attempt = 0; attempt < 3; attempt++) {
    try {
      if (!await file.exists()) return {};
      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        if (attempt < 2) {
          await Future.delayed(const Duration(milliseconds: 40));
          continue;
        }
        return {};
      }
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      if (attempt < 2) {
        await Future.delayed(const Duration(milliseconds: 40));
      }
    }
  }
  return {};
}

Future<void> _writeState(Map<String, dynamic> state) async {
  final dir = _getDataDir();
  if (dir == null) return;
  try {
    final dirObj = Directory(dir);
    if (!await dirObj.exists()) await dirObj.create(recursive: true);
    final file = File('$dir/$kStateFile');
    final tmpFile = File('$dir/$kStateFile.tmp.$pid');
    await tmpFile.writeAsString(jsonEncode(state), flush: true);
    try {
      await tmpFile.rename(file.path);
    } catch (_) {
      await file.writeAsString(jsonEncode(state), flush: true);
      try {
        if (await tmpFile.exists()) await tmpFile.delete();
      } catch (_) {}
    }
  } catch (_) {}
}

Future<void> _stateWriteChain = Future.value();

Future<void> _updateState(Map<String, dynamic> patch) {
  _stateWriteChain = _stateWriteChain.then((_) async {
    final state = await _readState();
    state.addAll(patch);
    await _writeState(state);
  }).catchError((_) {});
  return _stateWriteChain;
}

Future<List<Map<String, dynamic>>> _readEvents() async {
  final dir = _getDataDir();
  if (dir == null) return [];
  final file = File('$dir/$kEventsFile');
  for (int attempt = 0; attempt < 3; attempt++) {
    try {
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        if (attempt < 2) {
          await Future.delayed(const Duration(milliseconds: 40));
          continue;
        }
        return [];
      }
      final list = jsonDecode(content) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      if (attempt < 2) {
        await Future.delayed(const Duration(milliseconds: 40));
      }
    }
  }
  return [];
}

Future<void> _writeEvents(List<Map<String, dynamic>> events) async {
  final dir = _getDataDir();
  if (dir == null) return;
  try {
    final dirObj = Directory(dir);
    if (!await dirObj.exists()) await dirObj.create(recursive: true);
    final file = File('$dir/$kEventsFile');
    final tmpFile = File('$dir/$kEventsFile.tmp.$pid');
    await tmpFile.writeAsString(jsonEncode(events), flush: true);
    try {
      await tmpFile.rename(file.path);
    } catch (_) {
      await file.writeAsString(jsonEncode(events), flush: true);
      try {
        if (await tmpFile.exists()) await tmpFile.delete();
      } catch (_) {}
    }
  } catch (_) {}
}

void _forceExit() {
  debugPrint('👋 Force exit ngay...');
  try {
    Process.killPid(pid, ProcessSignal.sigterm);
  } catch (_) {
    Process.killPid(pid);
  }
}

// ============================================================
// ANDROID PERMISSIONS & ALARM HELPERS
// ============================================================
Future<void> _requestPermissionsFirstLaunch() async {
  if (!Platform.isAndroid && !Platform.isIOS) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    final asked = prefs.getBool(kPrefPermissionAsked) ?? false;
    if (asked) return;
    await Future.delayed(const Duration(milliseconds: 900));
    await Permission.notification.request();
    await prefs.setBool(kPrefPermissionAsked, true);
  } catch (e) {
    debugPrint('❌ [Permission] Lỗi: $e');
  }
}

Future<void> _scheduleWidgetDailyUpdate() async {
  if (!Platform.isAndroid) return;
  try {
    final now = DateTime.now();
    DateTime nextMidnight;
    if (now.hour == 0 && now.minute < 1) {
      nextMidnight = DateTime(now.year, now.month, now.day, 0, 1);
    } else {
      nextMidnight = DateTime(now.year, now.month, now.day + 1, 0, 1);
    }
    await AndroidAlarmManager.cancel(kDailyAlarmId);
    await AndroidAlarmManager.oneShotAt(
      nextMidnight,
      kDailyAlarmId,
      widgetUpdateCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
    debugPrint('⏰ [Widget] Daily scheduled: $nextMidnight');
  } catch (e) {
    debugPrint('❌ [Widget] Schedule daily lỗi: $e');
  }
}

Future<void> _scheduleWidgetPeriodicBackup() async {
  if (!Platform.isAndroid) return;
  try {
    await AndroidAlarmManager.cancel(kPeriodicAlarmId);
    await AndroidAlarmManager.periodic(
      const Duration(hours: 6),
      kPeriodicAlarmId,
      widgetUpdateCallback,
      exact: false,
      wakeup: true,
      rescheduleOnReboot: true,
    );
    debugPrint('⏰ [Widget] Backup scheduled: every 6h');
  } catch (e) {
    debugPrint('❌ [Widget] Schedule backup lỗi: $e');
  }
}

Future<void> scheduleWidgetUpdates() async {
  if (!Platform.isAndroid) return;
  await _scheduleWidgetDailyUpdate();
  await _scheduleWidgetPeriodicBackup();
}

// ============================================================
// MAIN ENTRY POINT
// ============================================================
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final bool isAutostart = args.contains('--autostart');

  if (Platform.isAndroid || Platform.isIOS) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }

  // Widget window? → chạy mode widget riêng
  final windowController = await WindowController.fromCurrentEngine();
  final windowArgs = windowController.arguments;

  if (windowArgs.isNotEmpty) {
    runApp(WidgetWindowApp(
      windowController: windowController,
      argData: windowArgs,
    ));
    return;
  }

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    const windowOptions = WindowOptions(
      size: kMainSize,
      minimumSize: Size(800, 600),
      center: true,
      title: 'VIE Lịch',
      titleBarStyle: TitleBarStyle.normal,
    );
    final isAutoStart = args.contains(AutoStartService.startupArg);
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      if (isAutoStart) {
        debugPrint('🚀 [AutoStart] Launch từ shortcut → ẩn main window');
        await windowManager.hide();
      } else {
        await windowManager.show();
        await windowManager.focus();
      }
    });
  } else if (Platform.isMacOS) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1000, 700),
      minimumSize: Size(600, 700),
      center: true,
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  } else if (Platform.isLinux) {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1000, 700),
      minimumSize: Size(600, 700),
      center: true,
      titleBarStyle: TitleBarStyle.normal,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      if (!isAutostart) {
        await windowManager.show();
        await windowManager.focus();
      } else {
        await windowManager.hide();
      }
    });
  }

  await initializeDateFormatting('vi', null);
  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(SuKienAdapter());
  }

  final box = await Hive.openBox<SuKien>('suKienBox');

  if (Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isLinux) {
    try {
      await NotificationService.init();
      final dsSuKien = box.values.toList();
      await NotificationService.khoiPhucLich(dsSuKien);
    } catch (e, st) {
      debugPrint('❌ [Notification] Init/Khôi phục lỗi: $e\n$st');
    }
  }

  DeepLinkService.init(args);

  if (Platform.isAndroid) {
    try {
      await AndroidAlarmManager.initialize();
      await scheduleWidgetUpdates();
    } catch (e, st) {
      debugPrint('❌ [Alarm] Init/Schedule lỗi: $e\n$st');
    }
  }

  runApp(const MainApp());

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    const bool isPlayStore = bool.fromEnvironment('PLAY_STORE', defaultValue: false);
    if (isPlayStore && Platform.isAndroid) {
      await AppUpdateService.autoUpdateFlow();
    }
  });
}

// ============================================================
// MAIN APP
// ============================================================
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LichProvider()),
        ChangeNotifierProvider(create: (_) => SuKienProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const _MainAppContent(),
    );
  }
}

class _MainAppContent extends StatefulWidget {
  const _MainAppContent();

  @override
  State<_MainAppContent> createState() => _MainAppContentState();
}

class _MainAppContentState extends State<_MainAppContent>
    with WindowListener, WidgetsBindingObserver {
  TrayIcon? _trayIcon;
  Menu? _trayMenu;
  final List<MenuItem> _trayMenuItems = [];
  final List<Menu> _traySubmenus = [];

  WindowController? _widgetController;
  bool _widgetEnabled = true;
  bool _widgetLocked = false;
  bool _autoStartEnabled = false;

  double _savedWidgetX = 100.0;
  double _savedWidgetY = 100.0;

  SuKienProvider? _suKienProvider;
  List<String> _lastEventHash = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      windowManager.addListener(this);
    }

    _bootstrap();
    _kiemTraFlexibleUpdateDaTai();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && Platform.isAndroid) {
      _scheduleWidgetDailyUpdate();
    }
  }

  Future<void> _bootstrap() async {
    if (Platform.isWindows) {
      try {
        await _loadSavedState();
        await _updateState({
          'visible': true,
          'locked': _widgetLocked,
          'widgetReady': false,
        });
        _widgetEnabled = true;
        debugPrint('📝 Reset visible=true khi khởi động');
      } catch (e) {
        debugPrint('❌ Load state lỗi: $e');
      }

      try {
        await _initSystemTray();
      } catch (e) {
        debugPrint('❌ Init tray lỗi: $e');
      }

      // QUAN TRỌNG: Gọi trực tiếp _createWidgetWindow() ngay tại đây,
      // KHÔNG bọc trong addPostFrameCallback (vì khi khởi động cùng Windows
      // ở chế độ ẩn main window SW_HIDE, Flutter có thể không pump thêm frame
      // sau các tác vụ async, khiến addPostFrameCallback không bao giờ chạy).
      try {
        await _createWidgetWindow();
      } catch (e) {
        debugPrint('❌ Widget init lỗi: $e');
      }

      try {
        _autoStartEnabled = await AutoStartService.isEnabled();
        debugPrint('🚀 [AutoStart] Trạng thái: $_autoStartEnabled');
        await _rebuildTrayMenu();

        if (_autoStartEnabled) {
          await AutoStartService.refreshIfStale();
        }
      } catch (e) {
        debugPrint('⚠️ AutoStart check/refresh lỗi: $e');
      }

      try {
        await Future.delayed(const Duration(milliseconds: 500));
        await ScheduleWriter.writeAll();
        debugPrint('📝 schedule.json đã ghi lần đầu');
      } catch (e) {
        debugPrint('⚠️ Ghi schedule lỗi: $e');
      }
      await _startHelperIfNotRunning();
      return;
    }

    try {
      if (Platform.isMacOS || Platform.isLinux) {
        await _initSystemTray();
      }
    } catch (e) {
      debugPrint('❌ Init tray lỗi: $e');
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _requestPermissionsFirstLaunch();

      try {
        if (Platform.isLinux) {
          await LinuxDesktopWidgetService.init();
          await _capNhatWidgetVoiRetry();
        } else if (Platform.isMacOS) {
          debugPrint('⏳ [Flutter] Đợi MainFlutterWindow register MethodChannel...');
          await Future.delayed(const Duration(milliseconds: 1500));
          await _capNhatWidgetVoiRetry();
        } else if (Platform.isAndroid || Platform.isIOS) {
          await WidgetService.capNhatWidget();
          if (Platform.isAndroid) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(kPrefLastUpdate, _formatDate(DateTime.now()));
          }
        }
      } catch (e) {
        debugPrint('❌ Widget init lỗi: $e');
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!Platform.isWindows) return;

    final newProvider = context.read<SuKienProvider>();
    if (_suKienProvider != newProvider) {
      _suKienProvider?.removeListener(_onDataChanged);
      _suKienProvider = newProvider;
      _suKienProvider!.addListener(_onDataChanged);
      WidgetsBinding.instance.addPostFrameCallback((_) => _onDataChanged());
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      windowManager.removeListener(this);
    }
    WidgetsBinding.instance.removeObserver(this);
    _trayIcon?.dispose();
    _suKienProvider?.removeListener(_onDataChanged);
    super.dispose();
  }

  Future<void> _startHelperIfNotRunning() async {
    if (!Platform.isWindows) return;
    try {
      final result = await Process.run(
        'tasklist',
        ['/FI', 'IMAGENAME eq vie_lich_helper.exe', '/NH'],
        runInShell: true,
      );
      final output = result.stdout.toString().toLowerCase();
      if (output.contains('vie_lich_helper.exe')) {
        debugPrint('✅ Helper đang chạy, không cần start');
        return;
      }

      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final helperPath = '$exeDir\\vie_lich_helper.exe';

      if (!File(helperPath).existsSync()) {
        debugPrint('⚠️ Không tìm thấy helper: $helperPath');
        return;
      }

      await Process.start(
        helperPath,
        [],
        mode: ProcessStartMode.detached,
        workingDirectory: exeDir,
      );
      debugPrint('🚀 Đã start helper: $helperPath');
    } catch (e) {
      debugPrint('❌ Start helper lỗi: $e');
    }
  }

  Future<void> _loadSavedState() async {
    final state = await _readState();
    _widgetLocked = state['locked'] as bool? ?? false;
    _savedWidgetX = (state['x'] as num?)?.toDouble() ?? 100.0;
    _savedWidgetY = (state['y'] as num?)?.toDouble() ?? 100.0;
    debugPrint('📝 Loaded state: pos=($_savedWidgetX, $_savedWidgetY) locked=$_widgetLocked');
    if (mounted) setState(() {});
  }

  Future<void> _toggleWidgetLock() async {
    final newState = !_widgetLocked;
    debugPrint('🔒 Toggle lock: $_widgetLocked → $newState');
    setState(() => _widgetLocked = newState);
    await _updateState({'locked': newState});
    await _rebuildTrayMenu();
  }

  Future<void> _toggleAutoStart() async {
    final newState = !_autoStartEnabled;
    debugPrint('🚀 [AutoStart] Toggle: $_autoStartEnabled → $newState');

    final ok = newState
        ? await AutoStartService.enable()
        : await AutoStartService.disable();

    if (!ok) {
      debugPrint('❌ [AutoStart] Thao tác thất bại, giữ nguyên state');
      return;
    }

    final actual = await AutoStartService.isEnabled();
    setState(() => _autoStartEnabled = actual);
    await _rebuildTrayMenu();

    debugPrint('${actual ? "✅" : "⏹️"} [AutoStart] Enabled=$actual');
  }

  void _onDataChanged() {
    if (!Platform.isWindows) return;

    final events = _suKienProvider?.danhSachSuKien ?? [];
    final newHash = events.map((e) => '${e.id}:${e.ten}').toList();
    if (_listEquals(newHash, _lastEventHash)) return;
    _lastEventHash = newHash;

    final jsonList = events.map((e) => e.toJson()).toList();
    _writeEvents(jsonList);

    ScheduleWriter.writeAll();
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _createWidgetWindow() async {
    await _loadSavedState();
    debugPrint('📝 Tạo widget tại ($_savedWidgetX, $_savedWidgetY) locked=$_widgetLocked');

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        await _updateState({
          'locked': _widgetLocked,
          'visible': true,
          'widgetReady': false,
        });

        final controller = await WindowController.create(
          WindowConfiguration(
            hiddenAtLaunch: true,
            arguments: jsonEncode({
              'width': kWidgetSize.width,
              'height': kWidgetSize.height,
              'x': _savedWidgetX,
              'y': _savedWidgetY,
              'locked': _widgetLocked,
            }),
          ),
        );
        _widgetController = controller;
        _widgetEnabled = true;
        debugPrint('✅ Đã tạo widget (id=${controller.windowId}, lần $attempt)');

        _lastEventHash = [];
        _onDataChanged();

        // Chờ xác nhận widget sub-window đã khởi tạo và hiển thị thành công
        bool ready = false;
        for (int waitIdx = 0; waitIdx < 15; waitIdx++) {
          await Future.delayed(const Duration(milliseconds: 250));
          final st = await _readState();
          if (st['widgetReady'] == true) {
            ready = true;
            break;
          }
        }

        if (ready) {
          debugPrint('✅ Widget sub-window đã xác nhận hiển thị (widgetReady=true)');
          return;
        }
        debugPrint('⚠️ Chưa nhận được widgetReady sau lần thử $attempt, nhưng đã tạo controller');
        return;
      } catch (e) {
        debugPrint('❌ Lỗi tạo widget (lần $attempt): $e');
        if (attempt < 3) {
          await Future.delayed(const Duration(milliseconds: 600));
        }
      }
    }
  }

  Future<void> _showWidgetWindow() async {
    if (_widgetController == null) {
      await _createWidgetWindow();
      return;
    }
    await _updateState({'visible': true});
    _widgetEnabled = true;
  }

  Future<void> _hideWidgetWindow() async {
    if (_widgetController == null) return;
    await _updateState({'visible': false});
    _widgetEnabled = false;
  }

  @override
  void onWindowClose() async {
    if (Platform.isLinux) {
      await LinuxDesktopWidgetService.hideMainWindow();
      await windowManager.hide();
      return;
    }
    if (!Platform.isWindows) return;
    debugPrint('🚪 Main window X → ẩn main');
    await windowManager.hide();
  }

  Future<void> _kiemTraFlexibleUpdateDaTai() async {
    if (!Platform.isAndroid) return;
    const bool isPlayStore = bool.fromEnvironment('PLAY_STORE', defaultValue: false);
    if (!isPlayStore) return;
    final info = await AppUpdateService.checkForUpdate();
    if (info?.installStatus == InstallStatus.downloaded) {
      await AppUpdateService.completeFlexibleUpdate();
    }
  }

  Future<void> _capNhatWidgetVoiRetry() async {
    const int maxRetries = 5;
    const Duration retryDelay = Duration(milliseconds: 800);
    for (int i = 0; i < maxRetries; i++) {
      try {
        await WidgetService.capNhatWidget();
        return;
      } catch (e) {
        debugPrint('⚠️ [Flutter] capNhatWidget lỗi lần ${i + 1}: $e');
        if (i < maxRetries - 1) await Future.delayed(retryDelay);
      }
    }
    debugPrint('❌ [Flutter] capNhatWidget thất bại sau $maxRetries lần thử');
  }

  Future<void> _initSystemTray() async {
    try {
      String iconPath = '';
      if (Platform.isWindows) {
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        final candidates = [
          '$exeDir\\app_icon.ico',
          '$exeDir\\data\\flutter_assets\\assets\\icon\\vie_lich_tray.ico',
        ];
        for (final p in candidates) {
          if (File(p).existsSync()) {
            iconPath = p;
            debugPrint('✅ Tray icon (Windows): $p');
            break;
          }
        }
      } else if (Platform.isMacOS) {
        final exeFile = File(Platform.resolvedExecutable);
        final appDir = exeFile.parent.parent.parent.path;
        final candidates = [
          '$appDir/Frameworks/App.framework/Resources/flutter_assets/assets/icon/tray_mac.png',
          '$appDir/Frameworks/App.framework/Resources/flutter_assets/assets/icon/vie_lich_logo.png',
        ];
        for (final p in candidates) {
          if (File(p).existsSync()) {
            iconPath = p;
            debugPrint('✅ Tray icon (macOS): $p');
            break;
          }
        }
      } else if (Platform.isLinux) {
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        final candidates = [
          '$exeDir/data/flutter_assets/assets/icon/tray_mac.png',
          '$exeDir/data/flutter_assets/assets/icon/vie_lich_logo.png',
          'assets/icon/vie_lich_logo.png',
        ];
        for (final p in candidates) {
          if (File(p).existsSync()) {
            iconPath = p;
            break;
          }
        }
      }

      if (iconPath.isEmpty) {
        debugPrint('⚠️ Không tìm thấy icon tray');
        return;
      }

      _trayIcon = TrayIcon.create();
      if (_trayIcon == null) {
        debugPrint('❌ Không tạo được TrayIcon');
        return;
      }

      _trayIcon!.icon = Platform.isLinux
          ? (tray.Image.fromFile(iconPath) ?? ImageAsset.fromAsset(iconPath))
          : ImageAsset.fromAsset(iconPath);
      _trayIcon!.setTooltip('VIE Lịch');
      await _rebuildTrayMenu();

      _trayIcon!.addListener((event) {
        if (Platform.isLinux) {
          if (event is TrayIconClickedEvent) _trayIcon?.openContextMenu();
          return;
        }
        if (event is TrayIconClickedEvent) {
          _openMainWindow();
        } else if (event is TrayIconRightClickedEvent) {
          _trayIcon?.openContextMenu();
        } else if (event is TrayIconDoubleClickedEvent) {
          _openMainWindow();
        }
      });

      _trayIcon!.setVisible(true);
      debugPrint('✅ System tray khởi tạo thành công');
    } catch (e, st) {
      debugPrint('❌ Init system tray lỗi: $e\n$st');
    }
  }

  Future<void> _rebuildTrayMenu() async {
    _trayMenu = Menu.create();
    if (_trayMenu == null) {
      return;
    }
    _trayMenuItems.clear();
    _traySubmenus.clear();

    if (Platform.isWindows) {
      final toggleWidgetItem = MenuItem.createWithLabelAndType(
        'Hiện Widget Lịch',
        MenuItemType.checkbox,
      );
      toggleWidgetItem?.state = _widgetEnabled
          ? MenuItemState.checked
          : MenuItemState.unchecked;
      toggleWidgetItem?.addListener((event) {
        if (event is MenuItemClickedEvent) {
          if (_widgetEnabled) {
            _hideWidgetWindow();
          } else {
            _showWidgetWindow();
          }
          _rebuildTrayMenu();
        }
      });
      _trayMenu!.addItem(toggleWidgetItem!);

      final toggleLockItem = MenuItem.createWithLabelAndType(
        'Khóa vị trí Widget',
        MenuItemType.checkbox,
      );
      toggleLockItem?.state = _widgetLocked
          ? MenuItemState.checked
          : MenuItemState.unchecked;
      toggleLockItem?.addListener((event) {
        if (event is MenuItemClickedEvent) {
          _toggleWidgetLock();
        }
      });
      _trayMenu!.addItem(toggleLockItem!);

      final toggleAutoStartItem = MenuItem.createWithLabelAndType(
        'Khởi động cùng Windows',
        MenuItemType.checkbox,
      );
      toggleAutoStartItem?.state = _autoStartEnabled
          ? MenuItemState.checked
          : MenuItemState.unchecked;
      toggleAutoStartItem?.addListener((event) {
        if (event is MenuItemClickedEvent) {
          _toggleAutoStart();
        }
      });
      _trayMenu!.addItem(toggleAutoStartItem!);

      final openMainItem = MenuItem.createWithLabelAndType(
        'Mở cửa sổ quản lý',
        MenuItemType.normal,
      );
      openMainItem?.addListener((event) {
        if (event is MenuItemClickedEvent) {
          _openMainWindow();
        }
      });
      _trayMenu!.addItem(openMainItem!);

      _trayMenu!.addSeparator();

      final exitItem = MenuItem.createWithLabelAndType(
        'Thoát ứng dụng',
        MenuItemType.normal,
      );
      exitItem?.addListener((event) {
        if (event is MenuItemClickedEvent) {
          _forceExit();
        }
      });
      _trayMenu!.addItem(exitItem!);
    } else if (Platform.isMacOS) {
      final openMainItem = MenuItem.createWithLabelAndType(
        'Mở cửa sổ Lịch',
        MenuItemType.normal,
      );
      openMainItem?.addListener((event) {
        if (event is MenuItemClickedEvent) {
          windowManager.show();
          windowManager.focus();
        }
      });
      _trayMenu!.addItem(openMainItem!);

      _trayMenu!.addSeparator();

      final exitItem = MenuItem.createWithLabelAndType(
        'Thoát ứng dụng',
        MenuItemType.normal,
      );
      exitItem?.addListener((event) {
        if (event is MenuItemClickedEvent) {
          _forceExit();
        }
      });
      _trayMenu!.addItem(exitItem!);
    } else if (Platform.isLinux) {
      await _buildLinuxTrayMenu();
    }

    if (Platform.isLinux) {
      _trayIcon?.setContextMenuTrigger(ContextMenuTrigger.clicked);
    }
    _trayIcon?.setContextMenu(_trayMenu!);
  }

  Future<void> _buildLinuxTrayMenu() async {
    final openItem =
        MenuItem.createWithLabelAndType('Mở cửa sổ Lịch', MenuItemType.normal);
    openItem?.addListener((event) {
      if (event is MenuItemClickedEvent) {
        LinuxDesktopWidgetService.showMainWindow();
      }
    });
    if (openItem != null) {
      _trayMenuItems.add(openItem);
      _trayMenu!.addItem(openItem);
    }
    _trayMenu!.addSeparator();

    // 1. Bật / Tắt Widget ngoài Desktop
    final toggleWidgetItem = MenuItem.createWithLabelAndType(
        'Hiện Widget ngoài Desktop', MenuItemType.checkbox);
    if (toggleWidgetItem != null) {
      toggleWidgetItem.state = LinuxDesktopWidgetService.isVisible
          ? MenuItemState.checked
          : MenuItemState.unchecked;
      toggleWidgetItem.addListener((event) async {
        if (event is MenuItemClickedEvent) {
          final visible = await LinuxDesktopWidgetService.toggleVisible();
          toggleWidgetItem.state =
              visible ? MenuItemState.checked : MenuItemState.unchecked;
          _trayIcon?.setContextMenu(_trayMenu!);
        }
      });
      _trayMenuItems.add(toggleWidgetItem);
      _trayMenu!.addItem(toggleWidgetItem);
    }

    // 2. Khóa vị trí Widget trên màn hình
    final lockWidgetItem = MenuItem.createWithLabelAndType(
        'Khóa vị trí Widget', MenuItemType.checkbox);
    if (lockWidgetItem != null) {
      lockWidgetItem.state = LinuxDesktopWidgetService.isLocked
          ? MenuItemState.checked
          : MenuItemState.unchecked;
      lockWidgetItem.addListener((event) async {
        if (event is MenuItemClickedEvent) {
          final locked = await LinuxDesktopWidgetService.toggleLocked();
          lockWidgetItem.state =
              locked ? MenuItemState.checked : MenuItemState.unchecked;
          _trayIcon?.setContextMenu(_trayMenu!);
        }
      });
      _trayMenuItems.add(lockWidgetItem);
      _trayMenu!.addItem(lockWidgetItem);
    }

    // 3. Kích thước Widget
    final sizeSubmenu = Menu.create();
    final sizeMenuItem = MenuItem.createWithLabelAndType(
        'Kích thước Widget', MenuItemType.submenu);
    if (sizeSubmenu != null && sizeMenuItem != null) {
      _traySubmenus.add(sizeSubmenu);
      final sizes = <String, String>{
        'small': 'Nhỏ (Small)',
        'medium': 'Vừa (Medium)',
        'large': 'Lớn (Large - Mặc định)',
        'extraLarge': 'Rất lớn (Extra Large)',
      };
      final Map<String, MenuItem> sizeItems = {};
      for (final entry in sizes.entries) {
        final item =
            MenuItem.createWithLabelAndType(entry.value, MenuItemType.checkbox);
        if (item != null) {
          item.state = (LinuxDesktopWidgetService.sizeMode == entry.key)
              ? MenuItemState.checked
              : MenuItemState.unchecked;
          item.addListener((event) async {
            if (event is MenuItemClickedEvent) {
              await LinuxDesktopWidgetService.setSizeMode(entry.key);
              for (final kv in sizeItems.entries) {
                kv.value.state = (kv.key == entry.key)
                    ? MenuItemState.checked
                    : MenuItemState.unchecked;
              }
              _trayIcon?.setContextMenu(_trayMenu!);
            }
          });
          sizeItems[entry.key] = item;
          _trayMenuItems.add(item);
          sizeSubmenu.addItem(item);
        }
      }
      sizeMenuItem.submenu = sizeSubmenu;
      _trayMenuItems.add(sizeMenuItem);
      _trayMenu!.addItem(sizeMenuItem);
    }

    _trayMenu!.addSeparator();

    // 4. Khởi động cùng hệ thống (Autostart khi boot)
    final isAutostart = await LinuxDesktopWidgetService.isAutostartEnabled();
    final autostartItem = MenuItem.createWithLabelAndType(
        'Khởi động khi bật máy', MenuItemType.checkbox);
    if (autostartItem != null) {
      autostartItem.state =
          isAutostart ? MenuItemState.checked : MenuItemState.unchecked;
      autostartItem.addListener((event) async {
        if (event is MenuItemClickedEvent) {
          final enabled = await LinuxDesktopWidgetService.toggleAutostart();
          autostartItem.state =
              enabled ? MenuItemState.checked : MenuItemState.unchecked;
          _trayIcon?.setContextMenu(_trayMenu!);
        }
      });
      _trayMenuItems.add(autostartItem);
      _trayMenu!.addItem(autostartItem);
    }

    _trayMenu!.addSeparator();

    final exitItem =
        MenuItem.createWithLabelAndType('Thoát ứng dụng', MenuItemType.normal);
    exitItem?.addListener((event) {
      if (event is MenuItemClickedEvent) LinuxDesktopWidgetService.quitApp();
    });
    if (exitItem != null) {
      _trayMenuItems.add(exitItem);
      _trayMenu!.addItem(exitItem);
    }
  }

  Future<void> _openMainWindow() async {
    await windowManager.setSkipTaskbar(false);
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        if (Platform.isLinux) {
          final isDark = themeProvider.themeMode == ThemeMode.dark ||
              (themeProvider.themeMode == ThemeMode.system &&
                  MediaQuery.platformBrightnessOf(context) == Brightness.dark);
          LinuxDesktopWidgetService.setDarkMode(isDark);
        }
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Âm lịch Việt Nam',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.red, brightness: Brightness.light),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.red, brightness: Brightness.dark),
            useMaterial3: true,
          ),
          themeMode: themeProvider.themeMode,
          locale: const Locale('vi', 'VN'),
          supportedLocales: const [Locale('vi', 'VN'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const MainScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

// ============================================================
// WINDOWS WIDGET MULTI-MONITOR GEOMETRY & DPI HELPERS
// ============================================================
class WindowsWidgetGeometry {
  static double scaleOf(Display d) {
    final s = (d.scaleFactor ?? 1.0).toDouble();
    return s <= 0 ? 1.0 : s;
  }

  /// Trả về vùng làm việc thực tế (rcWork) tính bằng Win32 physical pixels.
  /// (screen_retriever_windows trả về visiblePosition & visibleSize đã chia cho scaleFactor của màn đó).
  static Rect getDisplayPhysicalWorkArea(Display d) {
    final scale = scaleOf(d);
    final vPos = d.visiblePosition ?? Offset.zero;
    final vSize = d.visibleSize ?? d.size;
    return Rect.fromLTWH(
      (vPos.dx * scale).roundToDouble(),
      (vPos.dy * scale).roundToDouble(),
      (vSize.width * scale).roundToDouble(),
      (vSize.height * scale).roundToDouble(),
    );
  }

  static Offset logicalToPhysicalOffset(Offset logicalPos, double dpr) {
    final safeDpr = dpr <= 0 ? 1.0 : dpr;
    return Offset(
      (logicalPos.dx * safeDpr).roundToDouble(),
      (logicalPos.dy * safeDpr).roundToDouble(),
    );
  }

  static Size logicalToPhysicalSize(Size logicalSize, double dpr) {
    final safeDpr = dpr <= 0 ? 1.0 : dpr;
    return Size(
      (logicalSize.width * safeDpr).roundToDouble(),
      (logicalSize.height * safeDpr).roundToDouble(),
    );
  }

  /// Chuyển tọa độ Win32 physical pixel sang tham số truyền vào windowManager.setPosition
  /// sao cho khi C++ nhân ngược lại với currentWindowDpr và ép kiểu int sẽ ra đúng pixel vật lý.
  static Offset physicalToWindowManagerOffset(
    Offset physPos,
    double currentWindowDpr,
  ) {
    final safeDpr = currentWindowDpr <= 0 ? 1.0 : currentWindowDpr;
    final targetX = physPos.dx.roundToDouble();
    final targetY = physPos.dy.roundToDouble();
    final epsX = targetX >= 0 ? 0.01 : -0.01;
    final epsY = targetY >= 0 ? 0.01 : -0.01;
    return Offset((targetX + epsX) / safeDpr, (targetY + epsY) / safeDpr);
  }

  /// Chuyển kích thước Win32 physical pixel sang tham số truyền vào windowManager.setSize.
  static Size physicalToWindowManagerSize(
    Size physSize,
    double currentWindowDpr,
  ) {
    final safeDpr = currentWindowDpr <= 0 ? 1.0 : currentWindowDpr;
    final targetW = physSize.width.roundToDouble();
    final targetH = physSize.height.roundToDouble();
    return Size((targetW + 0.01) / safeDpr, (targetH + 0.01) / safeDpr);
  }

  /// Tìm màn hình chứa điểm physical (hoặc màn hình gần nhất nếu điểm hơi tràn ra ngoài mép/taskbar).
  static Display findDisplayForPhysicalPoint(
    Offset pointPhysical,
    List<Display> displays,
    Display primaryDisplay,
  ) {
    for (final d in displays) {
      final r = getDisplayPhysicalWorkArea(d);
      if (r.contains(pointPhysical)) {
        return d;
      }
    }
    Display? bestDisplay;
    double bestDist = double.infinity;
    for (final d in displays) {
      final r = getDisplayPhysicalWorkArea(d);
      final clampedX = pointPhysical.dx.clamp(r.left, r.right);
      final clampedY = pointPhysical.dy.clamp(r.top, r.bottom);
      final dist = (pointPhysical - Offset(clampedX, clampedY)).distanceSquared;
      if (dist < bestDist) {
        bestDist = dist;
        bestDisplay = d;
      }
    }
    return bestDisplay ?? primaryDisplay;
  }

  /// Tính toán hình chữ nhật vật lý (physical Rect) khi khởi tạo widget từ vị trí đã lưu.
  static Rect resolveInitialPhysicalRect({
    required Offset savedPhysPos,
    required Size logicalWidgetSize,
    required List<Display> displays,
    required Display primaryDisplay,
  }) {
    Display targetDisplay = findDisplayForPhysicalPoint(
      savedPhysPos,
      displays,
      primaryDisplay,
    );
    double targetScale = scaleOf(targetDisplay);
    double physW = (logicalWidgetSize.width * targetScale).roundToDouble();
    double physH = (logicalWidgetSize.height * targetScale).roundToDouble();

    // Xác định lại theo tâm của widget trên màn hình đích
    targetDisplay = findDisplayForPhysicalPoint(
      Offset(savedPhysPos.dx + physW / 2, savedPhysPos.dy + physH / 2),
      displays,
      primaryDisplay,
    );
    targetScale = scaleOf(targetDisplay);
    physW = (logicalWidgetSize.width * targetScale).roundToDouble();
    physH = (logicalWidgetSize.height * targetScale).roundToDouble();

    final workArea = getDisplayPhysicalWorkArea(targetDisplay);
    double resolvedX = savedPhysPos.dx.roundToDouble();
    double resolvedY = savedPhysPos.dy.roundToDouble();
    final windowRect = Rect.fromLTWH(resolvedX, resolvedY, physW, physH);
    final intersect = workArea.intersect(windowRect);

    // Chỉ kẹp lại vị trí nếu màn hình phụ đã bị rút ra làm widget nằm hẳn ngoài màn hình
    if (intersect.isEmpty || intersect.width < 40 || intersect.height < 40) {
      final maxX = workArea.right - physW >= workArea.left
          ? workArea.right - physW
          : workArea.left;
      final maxY = workArea.bottom - physH >= workArea.top
          ? workArea.bottom - physH
          : workArea.top;
      resolvedX = resolvedX.clamp(workArea.left, maxX).roundToDouble();
      resolvedY = resolvedY.clamp(workArea.top, maxY).roundToDouble();
    }

    return Rect.fromLTWH(resolvedX, resolvedY, physW, physH);
  }

  /// Tính toán vị trí snap cạnh màn hình và kích thước vật lý chuẩn theo màn hình hiện tại.
  static ({Offset physPos, Size physSize, bool snapped, bool resized})
      computeSnapPhysical({
    required Offset currentPhysPos,
    required Size currentPhysSize,
    required Size logicalWidgetSize,
    required List<Display> displays,
    required Display primaryDisplay,
    double snapThreshold = kSnapThreshold,
    double snapMargin = kSnapMargin,
  }) {
    final centerPhysical = Offset(
      currentPhysPos.dx + currentPhysSize.width / 2,
      currentPhysPos.dy + currentPhysSize.height / 2,
    );

    final currentDisplay = findDisplayForPhysicalPoint(
      centerPhysical,
      displays,
      primaryDisplay,
    );

    final displayScale = scaleOf(currentDisplay);
    final workArea = getDisplayPhysicalWorkArea(currentDisplay);

    final expectedPhysW =
        (logicalWidgetSize.width * displayScale).roundToDouble();
    final expectedPhysH =
        (logicalWidgetSize.height * displayScale).roundToDouble();
    double curW = currentPhysSize.width;
    double curH = currentPhysSize.height;
    bool resized = false;
    if ((curW - expectedPhysW).abs() > 2 || (curH - expectedPhysH).abs() > 2) {
      curW = expectedPhysW;
      curH = expectedPhysH;
      resized = true;
    }

    final thresholdPhys = snapThreshold * displayScale;
    final marginPhys = snapMargin * displayScale;

    double newPhysX = currentPhysPos.dx;
    double newPhysY = currentPhysPos.dy;
    bool snapped = false;

    if (currentPhysPos.dx <= workArea.left + thresholdPhys) {
      newPhysX = (workArea.left + marginPhys).roundToDouble();
      snapped = true;
    } else if (currentPhysPos.dx + curW >= workArea.right - thresholdPhys) {
      newPhysX = (workArea.right - curW - marginPhys).roundToDouble();
      snapped = true;
    }
    if (currentPhysPos.dy <= workArea.top + thresholdPhys) {
      newPhysY = (workArea.top + marginPhys).roundToDouble();
      snapped = true;
    } else if (currentPhysPos.dy + curH >= workArea.bottom - thresholdPhys) {
      newPhysY = (workArea.bottom - curH - marginPhys).roundToDouble();
      snapped = true;
    }

    return (
      physPos: Offset(newPhysX, newPhysY),
      physSize: Size(curW, curH),
      snapped: snapped,
      resized: resized,
    );
  }
}

// ============================================================
// WIDGET WINDOW APP (Windows — cửa sổ Flutter riêng)
// ============================================================
class WidgetWindowApp extends StatefulWidget {
  final WindowController windowController;
  final String argData;

  const WidgetWindowApp({
    super.key,
    required this.windowController,
    required this.argData,
  });

  @override
  State<WidgetWindowApp> createState() => _WidgetWindowAppState();
}

class _WidgetWindowAppState extends State<WidgetWindowApp>
    with WindowListener {
  List<SuKien> _events = [];
  double _width = 420;
  double _height = 190;
  double _x = 100;
  double _y = 100;
  bool _ready = false;

  bool _isLocked = false;
  bool _isVisible = true;
  Timer? _snapTimer;
  Timer? _pollTimer;
  bool _snapping = false;
  bool _initializingWindow = true;
  int _visibilityCheckTick = 0;

  // Lưu ngày hiện tại để phát hiện khi qua ngày mới (00:00)
  int _lastKnownDay = DateTime.now().day;
  int _lastKnownMonth = DateTime.now().month;
  int _lastKnownYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();

    try {
      final config = jsonDecode(widget.argData) as Map<String, dynamic>;
      _width = (config['width'] as num?)?.toDouble() ?? 420;
      _height = (config['height'] as num?)?.toDouble() ?? 190;
      _x = (config['x'] as num?)?.toDouble() ?? 100;
      _y = (config['y'] as num?)?.toDouble() ?? 100;
      _isLocked = (config['locked'] as bool?) ?? false;
    } catch (_) {}

    debugPrint('🔧 Widget init: locked=$_isLocked pos=($_x, $_y)');
    _init();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(milliseconds: 300), (_) async {
      await _pollState();
      await _pollEvents();
      _checkDayChange();
    });
  }

  void _checkDayChange() {
    final now = DateTime.now();
    if (now.day != _lastKnownDay ||
        now.month != _lastKnownMonth ||
        now.year != _lastKnownYear) {
      _lastKnownDay = now.day;
      _lastKnownMonth = now.month;
      _lastKnownYear = now.year;

      if (mounted) {
        setState(() {});
        debugPrint('📅 Widget tự động cập nhật sang ngày mới: ${now.day}/${now.month}/${now.year}');
      }
    }
  }

  Future<void> _pollState() async {
    final state = await _readState();
    if (state.isEmpty) return;

    final locked = state['locked'] as bool? ?? false;
    if (locked != _isLocked) {
      debugPrint('🔒 Widget nhận lock = $locked (từ file)');
      if (mounted) setState(() => _isLocked = locked);
    }

    final visible = state['visible'] as bool? ?? true;
    if (visible != _isVisible) {
      _isVisible = visible;
      try {
        if (visible) {
          await windowManager.show();
          await _setPhysicalPosition(Offset(_x, _y));
        } else {
          await windowManager.hide();
        }
      } catch (_) {}
    } else if (_ready && !_initializingWindow && _isVisible && Platform.isWindows) {
      // Định kỳ mỗi ~1.5s kiểm tra xem HWND thực sự đã hiển thị chưa
      // (phòng trường hợp Windows vừa boot lên Explorer/DWM nuốt lệnh ShowWindowAsync)
      _visibilityCheckTick = (_visibilityCheckTick + 1) % 5;
      if (_visibilityCheckTick == 0) {
        try {
          final actualVisible = await windowManager.isVisible();
          if (!actualVisible) {
            debugPrint('👁️ Phát hiện widget đang bị ẩn dù _isVisible=true → gọi lại show()');
            _initializingWindow = true;
            await windowManager.show();
            await _setPhysicalPosition(Offset(_x, _y));
            await Future.delayed(const Duration(milliseconds: 150));
            _initializingWindow = false;
          }
        } catch (_) {
          _initializingWindow = false;
        }
      }
    }
  }

  Future<void> _pollEvents() async {
    final rawEvents = await _readEvents();
    if (rawEvents.isEmpty) return;

    try {
      final events = rawEvents.map((e) => SuKien.fromJson(e)).toList();
      bool needsUpdate = events.length != _events.length;
      if (!needsUpdate && events.isNotEmpty && _events.isNotEmpty) {
        needsUpdate = events.first.id != _events.first.id ||
            events.last.id != _events.last.id;
      }
      if (needsUpdate && mounted) {
        setState(() => _events = events);
        debugPrint('📅 Widget cập nhật ${events.length} events');
      }
    } catch (_) {}
  }

  Future<void> _init() async {
    await _setupWindow();
  }

  @override
  void dispose() {
    _snapTimer?.cancel();
    _pollTimer?.cancel();
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  // ============================================================
  // WIN32 PHYSICAL COORDINATE HELPERS (đa màn hình khác DPI/size)
  // ============================================================
  // Lưu ý:
  // - window_manager trên Windows luôn chia GetWindowRect cho window.devicePixelRatio
  //   (DPI của màn hình mà cửa sổ ĐANG đứng) và nhân lại với window.devicePixelRatio
  //   khi gọi SetWindowPos.
  // - screen_retriever_windows trả về visiblePosition và visibleSize đã chia cho
  //   scaleFactor của chính màn hình đó.
  // Do đó nếu quy toàn bộ về tọa độ pixel vật lý (Win32 virtual screen physical pixels)
  // và triệt tiêu hệ số devicePixelRatio khi gọi qua window_manager, vị trí & kích thước
  // sẽ chính xác tuyệt đối trên mọi tổ hợp màn hình (ví dụ 1080p + 4K).

  double _currentDpr() {
    final dpr = windowManager.getDevicePixelRatio();
    return dpr <= 0 ? 1.0 : dpr;
  }

  Future<Offset> _getPhysicalPosition() async {
    final pos = await windowManager.getPosition();
    return WindowsWidgetGeometry.logicalToPhysicalOffset(pos, _currentDpr());
  }

  Future<Size> _getPhysicalSize() async {
    final size = await windowManager.getSize();
    return WindowsWidgetGeometry.logicalToPhysicalSize(size, _currentDpr());
  }

  Future<void> _setPhysicalPosition(Offset physPos) async {
    await windowManager.setPosition(
      WindowsWidgetGeometry.physicalToWindowManagerOffset(
        physPos,
        _currentDpr(),
      ),
    );
  }

  Future<void> _setPhysicalSize(Size physSize) async {
    await windowManager.setSize(
      WindowsWidgetGeometry.physicalToWindowManagerSize(
        physSize,
        _currentDpr(),
      ),
    );
  }

  Future<void> _applyInitialGeometry() async {
    final primaryDisplay = await ScreenRetriever.instance.getPrimaryDisplay();
    final displays = await ScreenRetriever.instance.getAllDisplays();

    final resolvedRect = WindowsWidgetGeometry.resolveInitialPhysicalRect(
      savedPhysPos: Offset(_x, _y),
      logicalWidgetSize: Size(_width, _height),
      displays: displays,
      primaryDisplay: primaryDisplay,
    );

    _x = resolvedRect.left;
    _y = resolvedRect.top;

    // 1. Di chuyển cửa sổ sang màn hình đích trước để kích hoạt WM_DPICHANGED (nếu khác DPI)
    await _setPhysicalPosition(Offset(_x, _y));
    await Future.delayed(const Duration(milliseconds: 60));

    // 2. Đặt kích thước vật lý chuẩn theo DPI của màn hình đích rồi khóa lại vị trí (_x, _y)
    //    (tránh việc WM_DPICHANGED hoặc setSize ở màn hình chính làm lệch tọa độ sang giữa màn 4K)
    await _setPhysicalSize(resolvedRect.size);
    await _setPhysicalPosition(Offset(_x, _y));
  }

  Future<void> _setupWindow() async {
    if (!Platform.isWindows) {
      _initializingWindow = false;
      if (mounted) setState(() => _ready = true);
      return;
    }

    _initializingWindow = true;

    for (int attempt = 1; attempt <= 5; attempt++) {
      try {
        await windowManager.ensureInitialized();

        final opts = WindowOptions(
          size: Size(_width, _height),
          backgroundColor: Colors.transparent,
          skipTaskbar: true,
          titleBarStyle: TitleBarStyle.hidden,
          windowButtonVisibility: false,
        );

        await windowManager.waitUntilReadyToShow(opts);
        await windowManager.setAsFrameless();
        await windowManager.setHasShadow(false);
        await windowManager.setResizable(false);
        await windowManager.setSkipTaskbar(true);
        await windowManager.setTitle('VIE Lịch Widget');

        await _applyInitialGeometry();

        if (_isVisible) {
          await windowManager.show();
          // Đảm bảo vị trí không bị lệch sau khi show()
          await _setPhysicalPosition(Offset(_x, _y));
          final actualVisible = await windowManager.isVisible();
          if (!actualVisible) {
            await Future.delayed(const Duration(milliseconds: 150));
            await windowManager.show();
            await _setPhysicalPosition(Offset(_x, _y));
          }
        }

        if (mounted) setState(() => _ready = true);
        await _updateState({'widgetReady': true});

        // Chờ các sự kiện WM_MOVE phát sinh trong lúc khởi tạo trôi qua hết rồi mới gắn listener
        await Future.delayed(const Duration(milliseconds: 350));
        windowManager.addListener(this);
        _initializingWindow = false;
        debugPrint('✅ Setup widget thành công tại physical=($_x, $_y) (lần $attempt)');
        return;
      } catch (e) {
        debugPrint('⚠️ Setup widget lỗi (lần $attempt): $e');
        if (attempt < 5) {
          await Future.delayed(const Duration(milliseconds: 250));
        }
      }
    }

    // Fallback nếu sau 5 lần vẫn gặp ngoại lệ
    try {
      await windowManager.show();
    } catch (_) {}
    windowManager.addListener(this);
    _initializingWindow = false;
    if (mounted) setState(() => _ready = true);
  }

  @override
  void onWindowMove() {
    if (_isLocked || _snapping || _initializingWindow) return;
    _snapTimer?.cancel();
    _snapTimer = Timer(const Duration(milliseconds: 300), () async {
      if (_isLocked || _snapping || _initializingWindow) return;
      await _snapToEdge();
      try {
        final physPos = await _getPhysicalPosition();
        _x = physPos.dx;
        _y = physPos.dy;
        await _updateState({'x': physPos.dx, 'y': physPos.dy});
        debugPrint('💾 Widget ghi vị trí physical: (${physPos.dx.toInt()}, ${physPos.dy.toInt()})');
      } catch (e) {
        debugPrint('⚠️ Ghi vị trí lỗi: $e');
      }
    });
  }

  Future<void> _snapToEdge() async {
    if (!Platform.isWindows || _isLocked || _snapping || _initializingWindow) {
      return;
    }
    _snapping = true;
    try {
      final physPos = await _getPhysicalPosition();
      final physSize = await _getPhysicalSize();
      final primaryDisplay = await ScreenRetriever.instance.getPrimaryDisplay();
      final displays = await ScreenRetriever.instance.getAllDisplays();

      final snapResult = WindowsWidgetGeometry.computeSnapPhysical(
        currentPhysPos: physPos,
        currentPhysSize: physSize,
        logicalWidgetSize: Size(_width, _height),
        displays: displays,
        primaryDisplay: primaryDisplay,
      );

      if (snapResult.resized) {
        await _setPhysicalSize(snapResult.physSize);
      }

      if (snapResult.snapped) {
        await _setPhysicalPosition(snapResult.physPos);
        debugPrint(
          '📐 Snap physical → (${snapResult.physPos.dx.toInt()}, ${snapResult.physPos.dy.toInt()})',
        );
      }
    } catch (e) {
      debugPrint('⚠️ Snap lỗi: $e');
    } finally {
      _snapping = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: _ready
            ? GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _isLocked
                    ? null
                    : (_) {
                        try {
                          windowManager.startDragging();
                        } catch (_) {}
                      },
                child: _buildWidget(),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildWidget() {
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);

    final amHienTai = AmLichHelper.duongSangAm(now);
    final int namAmHienTai = amHienTai != null ? amHienTai.getYear() : now.year;

    final dsDaChuyenDoi = <Map<String, dynamic>>[];
    final ngayCoSuKien = <int>[];

    for (var sk in _events) {
      int namAmTinhToan = sk.namAm ?? namAmHienTai;
      DateTime? ngayDuong =
          AmLichHelper.amSangDuong(namAmTinhToan, sk.thangAm, sk.ngayAm);

      if (sk.namAm == null && ngayDuong != null) {
        final dateOnly = DateTime(ngayDuong.year, ngayDuong.month, ngayDuong.day);
        if (dateOnly.isBefore(todayOnly)) {
          ngayDuong = AmLichHelper.amSangDuong(namAmHienTai + 1, sk.thangAm, sk.ngayAm);
        }
      }

      if (ngayDuong != null) {
        dsDaChuyenDoi.add({
          'ten': sk.ten,
          'ngayDuong': ngayDuong,
          'tag': sk.tag ?? 'event',
        });
        if (ngayDuong.month == now.month && ngayDuong.year == now.year) {
          ngayCoSuKien.add(ngayDuong.day);
        }
      }
    }

    String tenSK = 'Không có sự kiện sắp tới';
    String thoiGianSK = '';
    String loaiSK = 'event';

    final suKienSapToi = dsDaChuyenDoi.where((sk) {
      final d = sk['ngayDuong'] as DateTime;
      final dateOnly = DateTime(d.year, d.month, d.day);
      return !dateOnly.isBefore(todayOnly);
    }).toList();

    if (suKienSapToi.isNotEmpty) {
      suKienSapToi.sort((a, b) => (a['ngayDuong'] as DateTime).compareTo(b['ngayDuong'] as DateTime));
      final skGanNhat = suKienSapToi.first;
      final dateSK = skGanNhat['ngayDuong'] as DateTime;
      tenSK = skGanNhat['ten'] as String;
      loaiSK = skGanNhat['tag'] as String;

      final soNgay = DateTime(dateSK.year, dateSK.month, dateSK.day)
          .difference(todayOnly)
          .inDays;
      final ngayText =
          '${dateSK.day.toString().padLeft(2, '0')}/${dateSK.month.toString().padLeft(2, '0')}/${dateSK.year}';
      if (soNgay == 0) {
        thoiGianSK = 'Hôm nay - $ngayText';
      } else if (soNgay == 1) {
        thoiGianSK = 'Ngày mai - $ngayText';
      } else {
        thoiGianSK = 'Còn $soNgay ngày - $ngayText';
      }
    }

    return HomeScreenWidgetWindows(
      thangDuyet: now.month,
      namDuyet: now.year,
      tenSuKien: tenSK,
      thoiGianSuKien: thoiGianSK,
      loaiSuKien: loaiSK,
      ngayCoSuKien: ngayCoSuKien.toSet().toList(),
    );
  }
}

// ============================================================
// MAIN SCREEN
// ============================================================
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final _screens = const [
    LichNgayScreen(),
    LichThangScreen(),
    NhacSuKienScreen(),
    CaiDatScreen(),
  ];

  @override
  void initState() {
    super.initState();
    tabNotifier.addListener(_onTabChanged);

    const bool isPlayStore = bool.fromEnvironment('PLAY_STORE', defaultValue: false);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (Platform.isWindows) {
        await WindowsUpdateService.checkUpdate(context, respectSkip: true);
      } else if (!isPlayStore) {
        GithubUpdateService.checkUpdate(context);
      }
    });
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() {
        _selectedIndex = tabNotifier.value;
      });
    }
  }

  @override
  void dispose() {
    tabNotifier.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth >= 600;

    return Scaffold(
      extendBody: false,
      body: isDesktop || isWideScreen
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) => setState(() => _selectedIndex = index),
                  labelType: NavigationRailLabelType.all,
                  selectedIconTheme: const IconThemeData(color: Colors.red),
                  selectedLabelTextStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: Text('Lịch ngày')),
                    NavigationRailDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: Text('Lịch tháng')),
                    NavigationRailDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: Text('Nhắc lịch')),
                    NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Cài đặt')),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: IndexedStack(index: _selectedIndex, children: _screens)),
              ],
            )
          : IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: !isDesktop && !isWideScreen
          ? NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) => setState(() => _selectedIndex = index),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.today), label: 'Lịch ngày'),
                NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Lịch tháng'),
                NavigationDestination(icon: Icon(Icons.notifications), label: 'Nhắc lịch'),
                NavigationDestination(icon: Icon(Icons.settings), label: 'Cài đặt'),
              ],
            )
          : null,
    );
  }
}