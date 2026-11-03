import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'widget_service.dart';

class LinuxDesktopWidgetService {
  static const MethodChannel _channel =
      MethodChannel('com.toanbb.vie_lich/linux_widget');

  static const String _prefVisible = 'linux_widget_visible';
  static const String _prefLocked = 'linux_widget_locked';
  static const String _prefSizeMode = 'linux_widget_size_mode';
  static const String _prefPosX = 'linux_widget_pos_x';
  static const String _prefPosY = 'linux_widget_pos_y';

  static bool _isInitialized = false;
  static bool _isVisible = true;
  static bool _isLocked = false;
  static bool _isDark =
      PlatformDispatcher.instance.platformBrightness == Brightness.dark;
  static String _sizeMode = 'large';
  static int _posX = -1000;
  static int _posY = -1000;
  static Timer? _refreshTimer;
  static Map<String, dynamic>? _lastData;

  static bool get isVisible => _isVisible;
  static bool get isLocked => _isLocked;
  static String get sizeMode => _sizeMode;

  static Future<void> init({bool? isDark}) async {
    if (!Platform.isLinux) return;

    final prefs = await SharedPreferences.getInstance();
    if (isDark != null) {
      _isDark = isDark;
    } else {
      final modeStr = prefs.getString('theme_mode');
      if (modeStr == 'dark') {
        _isDark = true;
      } else if (modeStr == 'light') {
        _isDark = false;
      } else {
        _isDark =
            PlatformDispatcher.instance.platformBrightness == Brightness.dark;
      }
    }

    if (!_isInitialized) {
      _isInitialized = true;
      _channel.setMethodCallHandler(_handleMethodCall);

      _isVisible = prefs.getBool(_prefVisible) ?? true;
      _isLocked = prefs.getBool(_prefLocked) ?? false;
      _sizeMode = prefs.getString(_prefSizeMode) ?? 'large';
      _posX = prefs.getInt(_prefPosX) ?? -1000;
      _posY = prefs.getInt(_prefPosY) ?? -1000;

      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(const Duration(minutes: 15), (_) {
        WidgetService.capNhatWidget();
      });
    }

    final autostart = await isAutostartEnabled();

    try {
      await _channel.invokeMethod('configure', {
        'visible': _isVisible,
        'locked': _isLocked,
        'isDark': _isDark,
        'autostart': autostart,
        'sizeMode': _sizeMode,
        'x': _posX,
        'y': _posY,
      });
    } catch (e) {
      debugPrint('⚠️ [LinuxWidget] Lỗi configure: $e');
    }
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    final args = call.arguments;
    switch (call.method) {
      case 'onPositionChanged':
        if (args is Map) {
          final x = args['x'];
          final y = args['y'];
          if (x is int && y is int) {
            _posX = x;
            _posY = y;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt(_prefPosX, x);
            await prefs.setInt(_prefPosY, y);
          }
        }
        break;
      case 'onVisibleChanged':
        if (args is Map) {
          final visible = args['visible'];
          if (visible is bool) {
            _isVisible = visible;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(_prefVisible, visible);
          }
        }
        break;
      case 'onLockedChanged':
        if (args is Map) {
          final locked = args['locked'];
          if (locked is bool) {
            _isLocked = locked;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(_prefLocked, locked);
          }
        }
        break;
      case 'onSizeModeChanged':
        if (args is Map) {
          final mode = args['sizeMode'];
          if (mode is String) {
            _sizeMode = mode;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_prefSizeMode, mode);
          }
        }
        break;
      case 'onAutostartChanged':
        if (args is Map) {
          final autostart = args['autostart'];
          if (autostart is bool) {
            await setAutostartEnabled(autostart);
          }
        }
        break;
      case 'onShowMainWindow':
        try {
          await windowManager.show();
          await windowManager.focus();
        } catch (_) {}
        break;
    }
  }

  static Future<void> updateWidgetData(Map<String, dynamic> data) async {
    if (!Platform.isLinux) return;
    _lastData = Map<String, dynamic>.from(data);
    _lastData!['isDark'] = _isDark;
    try {
      await _channel.invokeMethod('updateData', _lastData);
    } catch (e) {
      debugPrint('⚠️ [LinuxWidget] Lỗi updateData: $e');
    }
  }

  static Future<void> setDarkMode(bool isDark) async {
    if (!Platform.isLinux) return;
    _isDark = isDark;
    if (_lastData != null) {
      _lastData!['isDark'] = _isDark;
    }
    try {
      await _channel.invokeMethod('setDarkMode', {'isDark': isDark});
    } catch (_) {}
  }

  static Future<void> setVisible(bool visible) async {
    if (!Platform.isLinux) return;
    _isVisible = visible;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefVisible, visible);
    try {
      await _channel.invokeMethod('setVisible', {'visible': visible});
    } catch (e) {
      debugPrint('⚠️ [LinuxWidget] Lỗi setVisible: $e');
    }
  }

  static Future<bool> toggleVisible() async {
    await setVisible(!_isVisible);
    return _isVisible;
  }

  static Future<void> setLocked(bool locked) async {
    if (!Platform.isLinux) return;
    _isLocked = locked;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefLocked, locked);
    try {
      await _channel.invokeMethod('setLocked', {'locked': locked});
    } catch (e) {
      debugPrint('⚠️ [LinuxWidget] Lỗi setLocked: $e');
    }
  }

  static Future<bool> toggleLocked() async {
    await setLocked(!_isLocked);
    return _isLocked;
  }

  static Future<void> setSizeMode(String mode) async {
    if (!Platform.isLinux) return;
    _sizeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefSizeMode, mode);
    try {
      await _channel.invokeMethod('setSizeMode', {'sizeMode': mode});
    } catch (e) {
      debugPrint('⚠️ [LinuxWidget] Lỗi setSizeMode: $e');
    }
  }

  static Future<void> showMainWindow() async {
    if (!Platform.isLinux) return;
    try {
      await _channel.invokeMethod('showMainWindow');
    } catch (_) {}
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
  }

  static Future<void> hideMainWindow() async {
    if (!Platform.isLinux) return;
    try {
      await _channel.invokeMethod('hideMainWindow');
    } catch (_) {}
  }

  static Future<void> quitApp() async {
    if (!Platform.isLinux) return;
    try {
      await _channel.invokeMethod('quitApp');
    } catch (_) {}
    exit(0);
  }

  // ============================================================
  // AUTOSTART KHI BOOT (~/.config/autostart/vie_lich.desktop)
  // ============================================================
  static File _getAutostartFile() {
    final home = Platform.environment['HOME'] ?? '/home/user';
    final configHome =
        Platform.environment['XDG_CONFIG_HOME'] ?? '$home/.config';
    return File('$configHome/autostart/vie_lich.desktop');
  }

  static Future<bool> isAutostartEnabled() async {
    if (!Platform.isLinux) return false;
    try {
      final file = _getAutostartFile();
      if (!await file.exists()) return false;
      final content = await file.readAsString();
      return !content.contains('X-GNOME-Autostart-enabled=false') &&
          !content.contains('Hidden=true');
    } catch (_) {
      return false;
    }
  }

  static Future<void> setAutostartEnabled(bool enabled) async {
    if (!Platform.isLinux) return;
    try {
      final file = _getAutostartFile();
      if (!enabled) {
        if (await file.exists()) {
          await file.delete();
        }
        return;
      }

      await file.parent.create(recursive: true);
      final exePath = Platform.resolvedExecutable;
      final exeDir = File(exePath).parent.path;
      String iconPath =
          '$exeDir/data/flutter_assets/assets/icon/vie_lich_logo.png';
      if (!File(iconPath).existsSync()) {
        iconPath = 'vie_lich';
      }

      final desktopContent = '''[Desktop Entry]
Type=Application
Name=VIE Lịch
Comment=Ứng dụng Lịch Âm Dương Việt Nam
Exec="$exePath" --autostart
Icon=$iconPath
Terminal=false
Categories=Utility;Calendar;
StartupWMClass=com.toanbb.vie_lich
X-GNOME-Autostart-enabled=true
''';
      await file.writeAsString(desktopContent);
    } catch (e) {
      debugPrint('⚠️ [LinuxWidget] Lỗi cấu hình autostart: $e');
    }
  }

  static Future<bool> toggleAutostart() async {
    final current = await isAutostartEnabled();
    final next = !current;
    await setAutostartEnabled(next);
    return next;
  }
}

