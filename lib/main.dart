import 'dart:io' show Platform, File;
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
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import 'models/su_kien.dart';
import 'providers/lich_provider.dart';
import 'providers/su_kien_provider.dart';
import 'providers/theme_provider.dart'; // 👈 Thêm import
import 'services/app_update_service.dart';
import 'services/github_update_service.dart';
import 'services/notification_service.dart';
import 'services/deep_link_service.dart';
import 'screens/lich_ngay_screen.dart';
import 'screens/lich_thang_screen.dart';
import 'screens/nhac_su_kien_screen.dart';
import 'screens/cai_dat_screen.dart';
import 'services/widget_service.dart';
import 'utils/am_lich_helper.dart';
import 'widgets/home_screen_widget_ui.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<bool> isWidgetMode = ValueNotifier<bool>(true);

const int kDailyAlarmId = 0;
const int kPeriodicAlarmId = 1;

const String kPrefLastUpdate = 'widget_last_update_date';
const String kPrefPermissionAsked = 'permission_asked_v1';

String _formatDate(DateTime d) {
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

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

@pragma('vm:entry-point')
Future<void> widgetUpdateCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('⏰ [Widget BG] Callback fired — ${DateTime.now()}');

  try {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SuKienAdapter());
    }
    if (!Hive.isBoxOpen('suKienBox')) {
      await Hive.openBox<SuKien>('suKienBox');
    }

    final prefs = await SharedPreferences.getInstance();
    final today = _formatDate(DateTime.now());
    final lastUpdate = prefs.getString(kPrefLastUpdate);

    if (lastUpdate == today) {
      debugPrint('⏭️ [Widget BG] Đã update hôm nay ($today), skip');
    } else {
      await WidgetService.capNhatWidget();
      await prefs.setString(kPrefLastUpdate, today);
      debugPrint('✅ [Widget BG] Đã update widget cho ngày $today');
    }

    await _scheduleWidgetDailyUpdate();
  } catch (e, st) {
    debugPrint('❌ [Widget BG] Lỗi: $e\n$st');
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid || Platform.isIOS) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
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

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(350, 400),
      minimumSize: Size(600, 700),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: true,
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  } else if (Platform.isMacOS) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1000, 700),
      minimumSize: Size(600, 700),
      center: true,
      titleBarStyle: TitleBarStyle.normal,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  await initializeDateFormatting('vi', null);
  await Hive.initFlutter();
  Hive.registerAdapter(SuKienAdapter());
  final box = await Hive.openBox<SuKien>('suKienBox');

  if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
    await NotificationService.init();
    final dsSuKien = box.values.toList();
    await NotificationService.khoiPhucLich(dsSuKien);
  }

  DeepLinkService.init();

  if (Platform.isAndroid) {
    try {
      await AndroidAlarmManager.initialize();
      await scheduleWidgetUpdates();
    } catch (e, st) {
      debugPrint('❌ [Alarm] Init/Schedule lỗi: $e\n$st');
    }
  }

  runApp(const MyApp());

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    const bool isPlayStore = bool.fromEnvironment('PLAY_STORE', defaultValue: false);
    if (isPlayStore && Platform.isAndroid) {
      await AppUpdateService.autoUpdateFlow();
    }
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  TrayIcon? _trayIcon;
  Menu? _trayMenu;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _requestPermissionsFirstLaunch();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (Platform.isMacOS) {
        await Future.delayed(const Duration(milliseconds: 1500));
        await _capNhatWidgetVoiRetry();
      } else if (Platform.isAndroid || Platform.isIOS) {
        await WidgetService.capNhatWidget();
        if (Platform.isAndroid) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(kPrefLastUpdate, _formatDate(DateTime.now()));
        }
      }
    });

    if (Platform.isWindows || Platform.isMacOS) {
      _initSystemTray();
    }
    _kiemTraFlexibleUpdateDaTai();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _trayIcon?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && Platform.isAndroid) {
      _scheduleWidgetDailyUpdate();
    }
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
        if (i < maxRetries - 1) await Future.delayed(retryDelay);
      }
    }
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
          if (File(p).existsSync()) { iconPath = p; break; }
        }
      } else if (Platform.isMacOS) {
        final exeFile = File(Platform.resolvedExecutable);
        final appDir = exeFile.parent.parent.parent.path;
        final candidates = [
          '$appDir/Contents/Frameworks/App.framework/Versions/A/Resources/flutter_assets/assets/icon/tray_mac.png',
          '$appDir/Contents/Frameworks/App.framework/Resources/flutter_assets/assets/icon/vie_lich_logo.png',
        ];
        for (final p in candidates) {
          if (File(p).existsSync()) { iconPath = p; break; }
        }
      }

      if (iconPath.isEmpty) return;
      _trayIcon = TrayIcon.create();
      if (_trayIcon == null) return;

      _trayIcon!.icon = ImageAsset.fromAsset(iconPath);
      _trayIcon!.setTooltip('VIE Lịch');
      await _rebuildTrayMenu();

      _trayIcon!.addListener((event) {
        if (Platform.isMacOS && event is TrayIconClickedEvent) {
          _trayIcon?.openContextMenu();
        } else if (Platform.isWindows) {
          if (event is TrayIconRightClickedEvent) {
            _trayIcon?.openContextMenu();
          } else if (event is TrayIconDoubleClickedEvent) {
            _switchToAppMode();
          }
        }
      });
      _trayIcon!.setVisible(true);
    } catch (e) {
      debugPrint('❌ Init system tray lỗi: $e');
    }
  }

  Future<void> _rebuildTrayMenu() async {
    _trayMenu = Menu.create();
    if (_trayMenu == null) return;

    if (Platform.isWindows) {
      final openAppItem = MenuItem.createWithLabelAndType('Mở ứng dụng quản lý', MenuItemType.normal);
      openAppItem?.addListener((event) { if (event is MenuItemClickedEvent) _switchToAppMode(); });
      _trayMenu!.addItem(openAppItem!);

      final openWidgetItem = MenuItem.createWithLabelAndType('Hiện Widget Lịch', MenuItemType.normal);
      openWidgetItem?.addListener((event) { if (event is MenuItemClickedEvent) _switchToWidgetMode(); });
      _trayMenu!.addItem(openWidgetItem!);
      _trayMenu!.addSeparator();
    } else if (Platform.isMacOS) {
      final openItem = MenuItem.createWithLabelAndType('Mở cửa sổ Lịch', MenuItemType.normal);
      openItem?.addListener((event) {
        if (event is MenuItemClickedEvent) { windowManager.show(); windowManager.focus(); }
      });
      _trayMenu!.addItem(openItem!);
      _trayMenu!.addSeparator();
    }

    final exitItem = MenuItem.createWithLabelAndType('Thoát ứng dụng', MenuItemType.normal);
    exitItem?.addListener((event) { if (event is MenuItemClickedEvent) windowManager.destroy(); });
    _trayMenu!.addItem(exitItem!);

    _trayIcon?.setContextMenu(_trayMenu!);
  }

  Future<void> _switchToAppMode() async {
    isWidgetMode.value = false;
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setBackgroundColor(Colors.white);
    await windowManager.setSize(const Size(1000, 700));
    await windowManager.setSkipTaskbar(false);
    await windowManager.center();
  }

  Future<void> _switchToWidgetMode() async {
    isWidgetMode.value = true;
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setSize(const Size(350, 400));
    await windowManager.setSkipTaskbar(true);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LichProvider()),
        ChangeNotifierProvider(create: (_) => SuKienProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()), // 👈 Thêm Provider
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Âm lịch Việt Nam',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.red,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.red,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            themeMode: themeProvider.themeMode, // 👈 Áp dụng ThemeMode
            locale: const Locale('vi', 'VN'),
            supportedLocales: const [Locale('vi', 'VN'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Platform.isWindows
                ? ValueListenableBuilder<bool>(
                    valueListenable: isWidgetMode,
                    builder: (context, isWidget, child) {
                      return isWidget ? const DesktopWidgetScreen() : const MainScreen();
                    },
                  )
                : const MainScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    const bool isPlayStore = bool.fromEnvironment('PLAY_STORE', defaultValue: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isPlayStore) GithubUpdateService.checkUpdate(context);
    });
  }

  static const List<Widget> _screens = [
    LichNgayScreen(),
    LichThangScreen(),
    NhacSuKienScreen(),
    CaiDatScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth >= 600;

    return Scaffold(
      extendBody: false,
      body: isWideScreen
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
      bottomNavigationBar: !isWideScreen
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

class DesktopWidgetScreen extends StatelessWidget {
  const DesktopWidgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SuKienProvider>(
      builder: (context, suKienProvider, child) {
        final danhSachSuKien = suKienProvider.danhSachSuKien;
        final now = DateTime.now();
        final todayOnly = DateTime(now.year, now.month, now.day);

        List<Map<String, dynamic>> dsDaChuyenDoi = [];
        List<int> ngayCoSuKienHienTai = [];

        final amHienTai = AmLichHelper.duongSangAm(now);
        final int namAmHienTai = amHienTai != null ? amHienTai.getYear() : now.year;

        for (var sk in danhSachSuKien) {
          int namAmTinhToan = sk.namAm ?? namAmHienTai;
          DateTime? ngayDuong = AmLichHelper.amSangDuong(namAmTinhToan, sk.thangAm, sk.ngayAm);

          if (sk.namAm == null && ngayDuong != null) {
            DateTime dateOnly = DateTime(ngayDuong.year, ngayDuong.month, ngayDuong.day);
            if (dateOnly.isBefore(todayOnly)) {
              ngayDuong = AmLichHelper.amSangDuong(namAmHienTai + 1, sk.thangAm, sk.ngayAm);
            }
          }

          if (ngayDuong != null) {
            dsDaChuyenDoi.add({'ten': sk.ten, 'ngayDuong': ngayDuong, 'tag': sk.tag ?? 'event'});
            if (ngayDuong.month == now.month && ngayDuong.year == now.year) {
              ngayCoSuKienHienTai.add(ngayDuong.day);
            }
          }
        }

        String tenSuKienGanNhat = "Không có sự kiện sắp tới";
        String thoiGianSuKienGanNhat = "";
        String loaiSuKienGanNhat = "event";

        List<Map<String, dynamic>> suKienSapToi = dsDaChuyenDoi.where((sk) {
          DateTime dateOnly = DateTime(sk['ngayDuong'].year, sk['ngayDuong'].month, sk['ngayDuong'].day);
          return dateOnly.isAfter(todayOnly) || dateOnly.isAtSameMomentAs(todayOnly);
        }).toList();

        if (suKienSapToi.isNotEmpty) {
          suKienSapToi.sort((a, b) => (a['ngayDuong'] as DateTime).compareTo(b['ngayDuong'] as DateTime));
          var skGanNhat = suKienSapToi.first;
          DateTime dateSK = skGanNhat['ngayDuong'];

          tenSuKienGanNhat = skGanNhat['ten'];
          loaiSuKienGanNhat = skGanNhat['tag'];

          int soNgayConLai = DateTime(dateSK.year, dateSK.month, dateSK.day).difference(todayOnly).inDays;
          String ngayText = '${dateSK.day.toString().padLeft(2, '0')}/${dateSK.month.toString().padLeft(2, '0')}/${dateSK.year}';

          if (soNgayConLai == 0) {
            thoiGianSuKienGanNhat = 'Hôm nay - $ngayText';
          } else if (soNgayConLai == 1) {
            thoiGianSuKienGanNhat = 'Ngày mai - $ngayText';
          } else {
            thoiGianSuKienGanNhat = 'Còn $soNgayConLai ngày - $ngayText';
          }
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: GestureDetector(
              onPanStart: (details) => windowManager.startDragging(),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: HomeScreenWidgetUI(
                  thangDuyet: now.month,
                  namDuyet: now.year,
                  tenSuKien: tenSuKienGanNhat,
                  thoiGianSuKien: thoiGianSuKienGanNhat,
                  loaiSuKien: loaiSuKienGanNhat,
                  ngayCoSuKien: ngayCoSuKienHienTai.toSet().toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}