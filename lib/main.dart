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
import 'package:tray_manager/tray_manager.dart';
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
import 'services/widget_service.dart';
import 'utils/am_lich_helper.dart';
import 'widgets/home_screen_widget_windows.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

const Size kWidgetSize = Size(420, 190);
const Size kMainSize = Size(1000, 700);
const double kSnapThreshold = 60.0;
const double kSnapMargin = 20.0;

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
  try {
    final file = File('$dir/$kStateFile');
    if (!await file.exists()) return {};
    final content = await file.readAsString();
    if (content.isEmpty) return {};
    return jsonDecode(content) as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
}

Future<void> _writeState(Map<String, dynamic> state) async {
  final dir = _getDataDir();
  if (dir == null) return;
  try {
    final dirObj = Directory(dir);
    if (!await dirObj.exists()) await dirObj.create(recursive: true);
    final file = File('$dir/$kStateFile');
    await file.writeAsString(jsonEncode(state));
  } catch (_) {}
}

Future<void> _updateState(Map<String, dynamic> patch) async {
  final state = await _readState();
  state.addAll(patch);
  await _writeState(state);
}

Future<List<Map<String, dynamic>>> _readEvents() async {
  final dir = _getDataDir();
  if (dir == null) return [];
  try {
    final file = File('$dir/$kEventsFile');
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    if (content.isEmpty) return [];
    final list = jsonDecode(content) as List;
    return list.cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
}

Future<void> _writeEvents(List<Map<String, dynamic>> events) async {
  final dir = _getDataDir();
  if (dir == null) return;
  try {
    final dirObj = Directory(dir);
    if (!await dirObj.exists()) await dirObj.create(recursive: true);
    final file = File('$dir/$kEventsFile');
    await file.writeAsString(jsonEncode(events));
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
      widgetUpdateCallback, // import từ widget_service.dart
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
      widgetUpdateCallback, // import từ widget_service.dart
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
        // Auto-start: KHÔNG show main window, chỉ widget hiện
        debugPrint('🚀 [AutoStart] Launch từ shortcut → ẩn main window');
      } else {
        await windowManager.show();
        await windowManager.focus();
      }
    });
  }

  await initializeDateFormatting('vi', null);
  await Hive.initFlutter();
  Hive.registerAdapter(SuKienAdapter());
  await Hive.openBox<SuKien>('suKienBox');

  try {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      await NotificationService.init();
    }
  } catch (e) {
    debugPrint('❌ Init notification lỗi: $e');
  }

  DeepLinkService.init();

  // Android: alarm manager để update widget mobile hàng ngày
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

  WindowController? _widgetController;
  bool _widgetEnabled = true;
  bool _widgetLocked = false;
  bool _autoStartEnabled = false;

  double _savedWidgetX = 100.0;
  double _savedWidgetY = 100.0;

  SuKienProvider? _suKienProvider;
  List<String> _lastEventHash = [];

  double _workAreaX = 0;
  double _workAreaY = 0;
  double _workAreaWidth = 0;
  double _workAreaHeight = 0;
  double _scaleFactor = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (Platform.isWindows) {
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
    try {
      if (Platform.isWindows) {
        await _loadSavedState();
        await _updateState({'visible': true});
        _widgetEnabled = true;
        debugPrint('📝 Reset visible=true khi khởi động');

        // Đọc trạng thái auto-start từ filesystem (source-of-truth)
        _autoStartEnabled = await AutoStartService.isEnabled();
        debugPrint('🚀 [AutoStart] Trạng thái: $_autoStartEnabled');

        // Nếu shortcut tồn tại, refresh path (user có thể đã di chuyển folder app)
        if (_autoStartEnabled) {
          await AutoStartService.refreshIfStale();
        }
      }
    } catch (e) {
      debugPrint('❌ Load state lỗi: $e');
    }

    try {
      if (Platform.isWindows || Platform.isMacOS) {
        await _initSystemTray();
      }
    } catch (e) {
      debugPrint('❌ Init tray lỗi: $e');
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Permission (mobile)
      await _requestPermissionsFirstLaunch();

      try {
        if (Platform.isMacOS) {
          debugPrint('⏳ [Flutter] Đợi MainFlutterWindow register MethodChannel...');
          await Future.delayed(const Duration(milliseconds: 1500));
          await _capNhatWidgetVoiRetry();
        } else if (Platform.isAndroid || Platform.isIOS) {
          await WidgetService.capNhatWidget();
          if (Platform.isAndroid) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(kPrefLastUpdate, _formatDate(DateTime.now()));
          }
        } else if (Platform.isWindows) {
          await _loadScreenInfo();
          await _createWidgetWindow();
        }
      } catch (e) {
        debugPrint('❌ Widget init lỗi: $e');
      }

      // Windows: ghi schedule.json + start helper
      if (Platform.isWindows) {
        try {
          await Future.delayed(const Duration(milliseconds: 1000));
          await ScheduleWriter.writeAll();
          debugPrint('📝 schedule.json đã ghi lần đầu');
        } catch (e) {
          debugPrint('⚠️ Ghi schedule lỗi: $e');
        }
        await _startHelperIfNotRunning();
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
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }
    WidgetsBinding.instance.removeObserver(this);
    _trayIcon?.dispose();
    _suKienProvider?.removeListener(_onDataChanged);
    super.dispose();
  }

  // ============================================================
  // HELPER AUTO-START (Windows)
  // ============================================================
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

  // ============================================================
  // LOAD / SAVE STATE
  // ============================================================
  Future<void> _loadSavedState() async {
    final state = await _readState();
    _widgetLocked = state['locked'] as bool? ?? false;
    _savedWidgetX = (state['x'] as num?)?.toDouble() ?? 100.0;
    _savedWidgetY = (state['y'] as num?)?.toDouble() ?? 100.0;
    debugPrint('📝 Loaded state: pos=($_savedWidgetX, $_savedWidgetY) locked=$_widgetLocked');
    if (mounted) setState(() {});
  }

  Future<void> _loadScreenInfo() async {
    if (!Platform.isWindows) return;
    try {
      final display = await ScreenRetriever.instance.getPrimaryDisplay();
      final size = display.size;
      final visiblePos = display.visiblePosition;
      final visibleSize = display.visibleSize;

      _scaleFactor = (display.scaleFactor ?? 1.0).toDouble();

      if (visiblePos != null && visibleSize != null) {
        _workAreaX = visiblePos.dx;
        _workAreaY = visiblePos.dy;
        _workAreaWidth = visibleSize.width;
        _workAreaHeight = visibleSize.height;
      } else {
        _workAreaX = 0;
        _workAreaY = 0;
        _workAreaWidth = size.width;
        _workAreaHeight = size.height;
      }
      debugPrint('🖥 Work area: ${_workAreaWidth.toInt()}x${_workAreaHeight.toInt()}');
    } catch (e) {
      debugPrint('⚠️ Lỗi screen info: $e');
      _workAreaWidth = 1920;
      _workAreaHeight = 1080;
      _scaleFactor = 1.0;
    }
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

    // Đọc lại từ filesystem để chắc chắn
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
    if (_workAreaWidth == 0 || _workAreaHeight == 0) {
      await _loadScreenInfo();
    }
    debugPrint('📝 Tạo widget tại ($_savedWidgetX, $_savedWidgetY) locked=$_widgetLocked');

    try {
      final controller = await WindowController.create(
        WindowConfiguration(
          hiddenAtLaunch: true,
          arguments: jsonEncode({
            'width': kWidgetSize.width,
            'height': kWidgetSize.height,
            'x': _savedWidgetX,
            'y': _savedWidgetY,
            'locked': _widgetLocked,
            'screenX': _workAreaX,
            'screenY': _workAreaY,
            'screenWidth': _workAreaWidth,
            'screenHeight': _workAreaHeight,
            'screenScale': _scaleFactor,
          }),
        ),
      );
      _widgetController = controller;
      _widgetEnabled = true;
      debugPrint('✅ Đã tạo widget (id=${controller.windowId})');

      await Future.delayed(const Duration(milliseconds: 500));
      _lastEventHash = [];
      _onDataChanged();
      await _updateState({
        'x': _savedWidgetX,
        'y': _savedWidgetY,
        'locked': _widgetLocked,
        'visible': true,
      });
    } catch (e) {
      debugPrint('❌ Lỗi tạo widget: $e');
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

  // ============================================================
  // SYSTEM TRAY
  // ============================================================
  Future<void> _initSystemTray() async {
    try {
      String iconPath = '';
      if (Platform.isWindows) {
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        final candidates = [
          '$exeDir\\data\\flutter_assets\\assets\\icon\\vie_lich_tray.ico',
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

      _trayIcon!.icon = ImageAsset.fromAsset(iconPath);
      _trayIcon!.setTooltip('VIE Lịch');
      await _rebuildTrayMenu();

      _trayIcon!.addListener((event) {
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

      // NEW: Khởi động cùng Windows
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
    }

    _trayIcon?.setContextMenu(_trayMenu!);
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

  double _screenX = 0;
  double _screenY = 0;
  double _screenWidth = 1920;
  double _screenHeight = 1080;
  double _scaleFactor = 1.0;

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
      _screenX = (config['screenX'] as num?)?.toDouble() ?? 0;
      _screenY = (config['screenY'] as num?)?.toDouble() ?? 0;
      _screenWidth = (config['screenWidth'] as num?)?.toDouble() ?? 1920;
      _screenHeight = (config['screenHeight'] as num?)?.toDouble() ?? 1080;
      _scaleFactor = (config['screenScale'] as num?)?.toDouble() ?? 1.0;
    } catch (_) {}

    debugPrint('🔧 Widget init: locked=$_isLocked pos=($_x, $_y)');
    _init();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(milliseconds: 300), (_) async {
      await _pollState();
      await _pollEvents();
    });
  }

  Future<void> _pollState() async {
    final state = await _readState();

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
        } else {
          await windowManager.hide();
        }
      } catch (_) {}
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

  Future<void> _setupWindow() async {
    if (!Platform.isWindows) {
      if (mounted) setState(() => _ready = true);
      return;
    }
    try {
      await windowManager.ensureInitialized();
      windowManager.addListener(this);

      final opts = WindowOptions(
        size: Size(_width, _height),
        backgroundColor: Colors.transparent,
        skipTaskbar: true,
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );
      await windowManager.waitUntilReadyToShow(opts, () async {
        await windowManager.setAsFrameless();
        await windowManager.setHasShadow(false);
        await windowManager.setResizable(false);
        await windowManager.setSize(Size(_width, _height));
        await windowManager.setPosition(Offset(_x, _y));
        await windowManager.setTitle('VIE Lịch Widget');
        await windowManager.show();
        if (mounted) setState(() => _ready = true);
      });
    } catch (e) {
      debugPrint('⚠️ Setup widget lỗi: $e');
      if (mounted) setState(() => _ready = true);
    }
  }

  @override
  void onWindowMove() {
    if (_isLocked || _snapping) return;
    _snapTimer?.cancel();
    _snapTimer = Timer(const Duration(milliseconds: 300), () async {
      await _snapToEdge();
      try {
        final pos = await windowManager.getPosition();
        await _updateState({'x': pos.dx, 'y': pos.dy});
        debugPrint('💾 Widget ghi vị trí: (${pos.dx.toInt()}, ${pos.dy.toInt()})');
      } catch (e) {
        debugPrint('⚠️ Ghi vị trí lỗi: $e');
      }
    });
  }

  Future<void> _snapToEdge() async {
    if (!Platform.isWindows || _isLocked || _snapping) return;
    _snapping = true;
    try {
      final position = await windowManager.getPosition();
      final size = await windowManager.getSize();
      final scale = _scaleFactor <= 0 ? 1.0 : _scaleFactor;
      final workArea = Rect.fromLTWH(
        _screenX / scale,
        _screenY / scale,
        _screenWidth / scale,
        _screenHeight / scale,
      );

      double newX = position.dx;
      double newY = position.dy;
      bool changed = false;

      if (position.dx <= workArea.left + kSnapThreshold) {
        newX = workArea.left + kSnapMargin;
        changed = true;
      } else if (position.dx + size.width >= workArea.right - kSnapThreshold) {
        newX = workArea.right - size.width - kSnapMargin;
        changed = true;
      }
      if (position.dy <= workArea.top + kSnapThreshold) {
        newY = workArea.top + kSnapMargin;
        changed = true;
      } else if (position.dy + size.height >= workArea.bottom - kSnapThreshold) {
        newY = workArea.bottom - size.height - kSnapMargin;
        changed = true;
      }

      if (changed) {
        await windowManager.setPosition(Offset(newX, newY));
        debugPrint('📐 Snap → (${newX.toInt()}, ${newY.toInt()})');
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

  @override
  void dispose() {
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