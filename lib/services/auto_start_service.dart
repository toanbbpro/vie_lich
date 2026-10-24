import 'dart:io';
import 'package:flutter/foundation.dart';

/// Quản lý "Khởi động cùng Windows" cho app portable.
///
/// Chiến lược: shortcut .lnk trong shell:startup folder.
/// - Không dùng Registry (hỏng nếu user di chuyển folder app).
/// - User có thể disable qua Task Manager.
/// - Shortcut truyền arg `--startup` để app biết được launch từ auto-start.
class AutoStartService {
  static const String _shortcutName = 'VIE Lich.lnk';
  static const String startupArg = '--startup';

  static String? _getStartupDir() {
    if (!Platform.isWindows) return null;
    final appData = Platform.environment['APPDATA'];
    if (appData == null || appData.isEmpty) return null;
    return '$appData\\Microsoft\\Windows\\Start Menu\\Programs\\Startup';
  }

  static String? _getShortcutPath() {
    final dir = _getStartupDir();
    if (dir == null) return null;
    return '$dir\\$_shortcutName';
  }

  /// Shortcut có tồn tại trong shell:startup không? (filesystem = source-of-truth)
  static Future<bool> isEnabled() async {
    if (!Platform.isWindows) return false;
    final path = _getShortcutPath();
    if (path == null) return false;
    return File(path).existsSync();
  }

  /// Tạo shortcut (enable). Ghi đè nếu đã tồn tại (dùng để refresh path).
  static Future<bool> enable() async {
    if (!Platform.isWindows) return false;

    final shortcutPath = _getShortcutPath();
    final startupDirPath = _getStartupDir();
    if (shortcutPath == null || startupDirPath == null) {
      debugPrint('❌ [AutoStart] Không xác định được shell:startup folder');
      return false;
    }

    final startupDir = Directory(startupDirPath);
    if (!startupDir.existsSync()) {
      debugPrint('❌ [AutoStart] shell:startup folder không tồn tại: $startupDirPath');
      return false;
    }

    try {
      final exePath = Platform.resolvedExecutable;
      final exeDir = File(exePath).parent.path;

      final ps = r'''
$ErrorActionPreference = "Stop"
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut('%SHORTCUT%')
$Shortcut.TargetPath = '%EXE%'
$Shortcut.WorkingDirectory = '%DIR%'
$Shortcut.IconLocation = '%EXE%,0'
$Shortcut.Arguments = '%ARGS%'
$Shortcut.Description = 'VIE Lich - App lich Viet'
$Shortcut.Save()
'''
          .replaceAll('%SHORTCUT%', _escPs(shortcutPath))
          .replaceAll('%EXE%', _escPs(exePath))
          .replaceAll('%DIR%', _escPs(exeDir))
          .replaceAll('%ARGS%', startupArg);

      final tempDir = Directory.systemTemp;
      final psFile = File('${tempDir.path}\\create_shortcut_${DateTime.now().millisecondsSinceEpoch}.ps1');
      await psFile.writeAsString(ps);

      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', psFile.path],
      );

      try { await psFile.delete(); } catch (_) {}

      if (result.exitCode != 0) {
        debugPrint('❌ [AutoStart] PowerShell exit ${result.exitCode}');
        debugPrint('   stderr: ${result.stderr}');
        return false;
      }

      final ok = File(shortcutPath).existsSync();
      debugPrint(ok
          ? '✅ [AutoStart] Đã tạo shortcut: $shortcutPath'
          : '❌ [AutoStart] Shortcut không được tạo (PS exit 0)');
      return ok;
    } catch (e, st) {
      debugPrint('❌ [AutoStart] enable lỗi: $e\n$st');
      return false;
    }
  }

  /// Xóa shortcut (disable).
  static Future<bool> disable() async {
    if (!Platform.isWindows) return false;
    final shortcutPath = _getShortcutPath();
    if (shortcutPath == null) return false;

    try {
      final file = File(shortcutPath);
      if (await file.exists()) await file.delete();
      final gone = !await file.exists();
      debugPrint(gone
          ? '✅ [AutoStart] Đã xóa shortcut: $shortcutPath'
          : '❌ [AutoStart] Không xóa được shortcut');
      return gone;
    } catch (e) {
      debugPrint('❌ [AutoStart] disable lỗi: $e');
      return false;
    }
  }

  /// Đọc .TargetPath của shortcut (null nếu không đọc được).
  static Future<String?> getShortcutTarget() async {
    if (!Platform.isWindows) return null;
    final shortcutPath = _getShortcutPath();
    if (shortcutPath == null) return null;
    if (!File(shortcutPath).existsSync()) return null;

    try {
      final ps = '''
\$ErrorActionPreference = "Stop"
\$WshShell = New-Object -ComObject WScript.Shell
\$Shortcut = \$WshShell.CreateShortcut('${_escPs(shortcutPath)}')
Write-Output \$Shortcut.TargetPath
''';
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', ps],
      );
      if (result.exitCode != 0) return null;
      final target = result.stdout.toString().trim();
      return target.isEmpty ? null : target;
    } catch (e) {
      debugPrint('⚠️ [AutoStart] getShortcutTarget lỗi: $e');
      return null;
    }
  }

  /// Nếu shortcut tồn tại nhưng trỏ về path cũ (user đã di chuyển folder app),
  /// tạo lại shortcut để trỏ về exe hiện tại.
  static Future<void> refreshIfStale() async {
    if (!Platform.isWindows) return;
    if (!await isEnabled()) return;

    final currentExe = Platform.resolvedExecutable;
    final target = await getShortcutTarget();

    if (target == null || target.toLowerCase() != currentExe.toLowerCase()) {
      debugPrint('🔄 [AutoStart] Shortcut trỏ về "$target", refresh → "$currentExe"');
      await enable();
    }
  }

  /// Escape single-quote cho PowerShell single-quoted string.
  static String _escPs(String s) => s.replaceAll("'", "''");
}