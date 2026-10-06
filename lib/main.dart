import 'dart:io' show Platform, File;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:in_app_update/in_app_update.dart';

import 'models/su_kien.dart';
import 'providers/lich_provider.dart';
import 'providers/su_kien_provider.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cấu hình window cho Windows
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(350, 400),
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
    // Cấu hình window cho macOS
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1000, 700),
      minimumSize: Size(800, 600),
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

  runApp(const MyApp());

  // Sau khi app render xong, kiểm tra update (chỉ bản Play Store)
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    const bool isPlayStore =
        bool.fromEnvironment('PLAY_STORE', defaultValue: false);
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

class _MyAppState extends State<MyApp> {
  TrayIcon? _trayIcon;
  Menu? _trayMenu;

  @override
  void initState() {
    super.initState();

    // Widget service với retry cho macOS
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (Platform.isMacOS) {
        debugPrint(
            '⏳ [Flutter] Đợi MainFlutterWindow register MethodChannel...');
        await Future.delayed(const Duration(milliseconds: 1500));
        await _capNhatWidgetVoiRetry();
      } else if (Platform.isAndroid || Platform.isIOS) {
        await WidgetService.capNhatWidget();
      }
    });

    if (Platform.isWindows || Platform.isMacOS) {
      _initSystemTray();
    }

    // Kiểm tra xem có flexible update đã tải xong chưa
    _kiemTraFlexibleUpdateDaTai();
  }

  @override
  void dispose() {
    _trayIcon?.dispose();
    super.dispose();
  }

  /// Nếu user đã tải xong flexible update ở lần chạy trước, giờ cài đặt
  Future<void> _kiemTraFlexibleUpdateDaTai() async {
    if (!Platform.isAndroid) return;

    const bool isPlayStore =
        bool.fromEnvironment('PLAY_STORE', defaultValue: false);
    if (!isPlayStore) return;

    final info = await AppUpdateService.checkForUpdate();
    if (info?.installStatus == InstallStatus.downloaded) {
      debugPrint(
          '📦 [Update] Phát hiện flexible update đã tải xong, cài đặt...');
      await AppUpdateService.completeFlexibleUpdate();
    }
  }

  /// Gọi capNhatWidget với retry cho macOS
  Future<void> _capNhatWidgetVoiRetry() async {
    const int maxRetries = 5;
    const Duration retryDelay = Duration(milliseconds: 800);

    for (int i = 0; i < maxRetries; i++) {
      try {
        debugPrint('📱 [Flutter] Gọi capNhatWidget lần ${i + 1}/$maxRetries');
        await WidgetService.capNhatWidget();
        debugPrint('✅ [Flutter] capNhatWidget thành công');
        return;
      } catch (e) {
        debugPrint('⚠️ [Flutter] capNhatWidget lỗi lần ${i + 1}: $e');
        if (i < maxRetries - 1) {
          await Future.delayed(retryDelay);
        }
      }
    }
    debugPrint('❌ [Flutter] capNhatWidget thất bại sau $maxRetries lần thử');
  }

  // ============================================================
  // SYSTEM TRAY — tray_manager 0.7.0 (native API)
  // ============================================================
  Future<void> _initSystemTray() async {
    try {
      String iconPath = '';

      if (Platform.isWindows) {
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        final candidates = [
          '$exeDir\\app_icon.ico',
          '$exeDir\\data\\flutter_assets\\assets\\icon\\vie_lich_tray.ico',
          '$exeDir\\data\\flutter_assets\\assets\\icon\\vie_lich_logo_v2.ico',
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
          // exeFile = .../VIE Lich.app/Contents/MacOS/vie_lich
          // .parent = Contents/MacOS
          // .parent.parent = Contents
          // .parent.parent.parent = VIE Lich.app
          final appDir = exeFile.parent.parent.parent.path;

          final candidates = [
            // Path chuẩn macOS bundle — đúng theo output find
            '$appDir/Contents/Frameworks/App.framework/Versions/A/Resources/flutter_assets/assets/icon/tray_mac.png',
            '$appDir/Contents/Frameworks/App.framework/Versions/A/Resources/flutter_assets/assets/icon/vie_lich_logo.png',
            // Fallback cho trường hợp bundle khác cấu trúc
            '$appDir/Contents/Frameworks/App.framework/Resources/flutter_assets/assets/icon/vie_lich_logo.png',
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
      debugPrint('✅ setIcon + setTooltip OK');

      await _rebuildTrayMenu();

      _trayIcon!.addListener((event) {
        if (Platform.isMacOS) {
          // macOS: click trái hiện menu (theo convention của menu bar app)
          if (event is TrayIconClickedEvent) {
            debugPrint('🖱️ Tray icon LEFT click (macOS) → menu');
            _trayIcon?.openContextMenu();
          }
        } else if (Platform.isWindows) {
          // Windows: right click hiện menu, double-click mở main window
          if (event is TrayIconRightClickedEvent) {
            debugPrint('🖱️ Tray icon RIGHT click (Windows) → menu');
            _trayIcon?.openContextMenu();
          } else if (event is TrayIconDoubleClickedEvent) {
            debugPrint('🖱️ Tray icon DOUBLE click (Windows) → app mode');
            _switchToAppMode();
          }
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
      debugPrint('⚠️ Không tạo được Menu');
      return;
    }

    if (Platform.isWindows) {
      // Item 1: Mở app mode
      final openAppItem = MenuItem.createWithLabelAndType(
        'Mở ứng dụng quản lý',
        MenuItemType.normal,
      );
      openAppItem?.addListener((event) {
        if (event is MenuItemClickedEvent) {
          _switchToAppMode();
        }
      });
      _trayMenu!.addItem(openAppItem!);

      // Item 2: Widget mode
      final openWidgetItem = MenuItem.createWithLabelAndType(
        'Hiện Widget Lịch',
        MenuItemType.normal,
      );
      openWidgetItem?.addListener((event) {
        if (event is MenuItemClickedEvent) {
          _switchToWidgetMode();
        }
      });
      _trayMenu!.addItem(openWidgetItem!);

      _trayMenu!.addSeparator();

      // Item 3: Thoát
      final exitItem = MenuItem.createWithLabelAndType(
        'Thoát ứng dụng',
        MenuItemType.normal,
      );
      exitItem?.addListener((event) {
        if (event is MenuItemClickedEvent) {
          windowManager.destroy();
        }
      });
      _trayMenu!.addItem(exitItem!);
    } else if (Platform.isMacOS) {
      // Item 1: Mở cửa sổ
      final openItem = MenuItem.createWithLabelAndType(
        'Mở cửa sổ Lịch',
        MenuItemType.normal,
      );
      openItem?.addListener((event) {
        if (event is MenuItemClickedEvent) {
          windowManager.show();
          windowManager.focus();
        }
      });
      _trayMenu!.addItem(openItem!);

      _trayMenu!.addSeparator();

      // Item 2: Thoát
      final exitItem = MenuItem.createWithLabelAndType(
        'Thoát ứng dụng',
        MenuItemType.normal,
      );
      exitItem?.addListener((event) {
        if (event is MenuItemClickedEvent) {
          windowManager.destroy();
        }
      });
      _trayMenu!.addItem(exitItem!);
    }

    _trayIcon?.setContextMenu(_trayMenu!);
    debugPrint('✅ setContextMenu OK');
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
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Âm lịch Việt Nam',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
          useMaterial3: true,
        ),
        locale: const Locale('vi', 'VN'),
        supportedLocales: const [
          Locale('vi', 'VN'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Platform.isWindows
            ? ValueListenableBuilder<bool>(
                valueListenable: isWidgetMode,
                builder: (context, isWidget, child) {
                  return isWidget
                      ? const DesktopWidgetScreen()
                      : const MainScreen();
                },
              )
            : const MainScreen(),
        debugShowCheckedModeBanner: false,
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
    const bool isPlayStore =
        bool.fromEnvironment('PLAY_STORE', defaultValue: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isPlayStore) {
        GithubUpdateService.checkUpdate(context);
      }
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
    final isDesktop =
        Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    return Scaffold(
      body: isDesktop
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() => _selectedIndex = index);
                  },
                  labelType: NavigationRailLabelType.all,
                  selectedIconTheme: const IconThemeData(color: Colors.red),
                  selectedLabelTextStyle: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.today_outlined),
                      selectedIcon: Icon(Icons.today),
                      label: Text('Lịch ngày'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.calendar_month_outlined),
                      selectedIcon: Icon(Icons.calendar_month),
                      label: Text('Lịch tháng'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.notifications_outlined),
                      selectedIcon: Icon(Icons.notifications),
                      label: Text('Nhắc lịch'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('Cài đặt'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: _screens,
                  ),
                ),
              ],
            )
          : IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: !isDesktop
          ? NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.today),
                  label: 'Lịch ngày',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month),
                  label: 'Lịch tháng',
                ),
                NavigationDestination(
                  icon: Icon(Icons.notifications),
                  label: 'Nhắc lịch',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings),
                  label: 'Cài đặt',
                ),
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
        final int namAmHienTai =
            amHienTai != null ? amHienTai.getYear() : now.year;

        for (var sk in danhSachSuKien) {
          int namAmTinhToan = sk.namAm ?? namAmHienTai;
          DateTime? ngayDuong =
              AmLichHelper.amSangDuong(namAmTinhToan, sk.thangAm, sk.ngayAm);

          if (sk.namAm == null && ngayDuong != null) {
            DateTime dateOnly =
                DateTime(ngayDuong.year, ngayDuong.month, ngayDuong.day);
            if (dateOnly.isBefore(todayOnly)) {
              ngayDuong = AmLichHelper.amSangDuong(
                  namAmHienTai + 1, sk.thangAm, sk.ngayAm);
            }
          }

          if (ngayDuong != null) {
            dsDaChuyenDoi.add({
              'ten': sk.ten,
              'ngayDuong': ngayDuong,
              'tag': sk.tag ?? 'event',
            });
            if (ngayDuong.month == now.month && ngayDuong.year == now.year) {
              ngayCoSuKienHienTai.add(ngayDuong.day);
            }
          }
        }

        String tenSuKienGanNhat = "Không có sự kiện sắp tới";
        String thoiGianSuKienGanNhat = "";
        String loaiSuKienGanNhat = "event";

        List<Map<String, dynamic>> suKienSapToi = dsDaChuyenDoi.where((sk) {
          DateTime ngayDuong = sk['ngayDuong'];
          DateTime dateOnly =
              DateTime(ngayDuong.year, ngayDuong.month, ngayDuong.day);
          return dateOnly.isAfter(todayOnly) ||
              dateOnly.isAtSameMomentAs(todayOnly);
        }).toList();

        if (suKienSapToi.isNotEmpty) {
          suKienSapToi.sort((a, b) => (a['ngayDuong'] as DateTime)
              .compareTo(b['ngayDuong'] as DateTime));
          var skGanNhat = suKienSapToi.first;
          DateTime dateSK = skGanNhat['ngayDuong'];

          tenSuKienGanNhat = skGanNhat['ten'];
          loaiSuKienGanNhat = skGanNhat['tag'];

          int soNgayConLai = DateTime(dateSK.year, dateSK.month, dateSK.day)
              .difference(todayOnly)
              .inDays;
          String ngayText =
              '${dateSK.day.toString().padLeft(2, '0')}/${dateSK.month.toString().padLeft(2, '0')}/${dateSK.year}';

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
              onPanStart: (details) {
                windowManager.startDragging();
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
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