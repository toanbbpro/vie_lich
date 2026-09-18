import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import 'models/su_kien.dart';
import 'providers/lich_provider.dart';
import 'providers/su_kien_provider.dart';
import 'services/notification_service.dart';
import 'screens/lich_ngay_screen.dart';
import 'screens/lich_thang_screen.dart';
import 'screens/nhac_su_kien_screen.dart';
import 'screens/cai_dat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Nạp dữ liệu ngôn ngữ Việt cho intl
  await initializeDateFormatting('vi', null);

  // Khởi tạo Hive CE
  await Hive.initFlutter();
  Hive.registerAdapter(SuKienAdapter());
  final box = await Hive.openBox<SuKien>('suKienBox');

  // Khởi tạo AndroidAlarmManager
  await AndroidAlarmManager.initialize();

  // Khởi tạo dịch vụ thông báo
  await NotificationService.init();

  // Khôi phục lịch thông báo
  final dsSuKien = box.values.toList();
  await NotificationService.khoiPhucLich(dsSuKien);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LichProvider()),
        ChangeNotifierProvider(create: (_) => SuKienProvider()),
      ],
      child: MaterialApp(
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
        home: const MainScreen(),
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

  static const List<Widget> _screens = [
    LichNgayScreen(),
    LichThangScreen(),
    NhacSuKienScreen(),
    CaiDatScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
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
      ),
    );
  }
}
