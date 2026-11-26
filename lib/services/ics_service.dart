import 'dart:convert';
import 'dart:io' show File, Platform;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/su_kien.dart';
import '../utils/am_lich_helper.dart';

class IcsService {
  static const List<int> cacLuaChonSoNam = [1, 3, 5, 10];
  static const int maxIcsBytes = 5 * 1024 * 1024; // 5 MB
  static const int maxImportedEvents = 500;
  static const Uuid _uuid = Uuid();

  /// Quy đổi ngày Âm sang Dương cho một năm Âm cụ thể.
  /// Nếu sự kiện đặt ngày 30 nhưng tháng Âm năm đó chỉ có 29 ngày (tháng thiếu),
  /// tự động lùi về ngày 29 cuối tháng thay vì tràn sang Mùng 1 tháng kế tiếp.
  static DateTime? tinhNgayDuongTheoNamAm(int namAm, int thangAm, int ngayAm) {
    final raw = AmLichHelper.amSangDuong(namAm, thangAm, ngayAm);
    if (raw == null) return null;
    if (ngayAm == 30) {
      final check = AmLichHelper.duongSangAm(raw);
      if (check != null && check.month != thangAm) {
        return raw.subtract(const Duration(days: 1));
      }
    }
    return raw;
  }

  /// Tạo nội dung chuẩn iCalendar (RFC 5545) cho danh sách sự kiện âm lịch trong [soNam] năm tới.
  static String taoNoiDungIcs(
    List<SuKien> dsSuKien, {
    int soNam = 5,
    DateTime? now,
  }) {
    final years = soNam.clamp(1, 20);
    final refNow = now ?? DateTime.now();
    final todayOnly = DateTime(refNow.year, refNow.month, refNow.day);
    final amNow = AmLichHelper.duongSangAm(refNow);
    final int namAmHienTai = amNow?.year ?? refNow.year;
    final dtStamp = _formatUtcTimestamp(refNow.toUtc());

    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//VIE Lich//Vietnamese Lunar Calendar//VI',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'X-WR-CALNAME:VIE Lịch - Sự kiện Âm lịch',
      'X-WR-TIMEZONE:Asia/Ho_Chi_Minh',
    ];

    for (final sk in dsSuKien) {
      final safeId = _sanitizeUid(sk.id);
      if (sk.namAm != null) {
        final ngayDuong =
            tinhNgayDuongTheoNamAm(sk.namAm!, sk.thangAm, sk.ngayAm);
        if (ngayDuong != null) {
          _appendVEvent(
            lines: lines,
            sk: sk,
            safeId: safeId,
            namAm: sk.namAm!,
            ngayDuong: ngayDuong,
            dtStamp: dtStamp,
          );
        }
      } else {
        int startNamAm = namAmHienTai;
        final thuNamNay =
            tinhNgayDuongTheoNamAm(namAmHienTai, sk.thangAm, sk.ngayAm);
        if (thuNamNay != null &&
            DateTime(thuNamNay.year, thuNamNay.month, thuNamNay.day)
                .isBefore(todayOnly)) {
          startNamAm = namAmHienTai + 1;
        }

        for (int k = 0; k < years; k++) {
          final namAm = startNamAm + k;
          final ngayDuong = tinhNgayDuongTheoNamAm(namAm, sk.thangAm, sk.ngayAm);
          if (ngayDuong == null) continue;
          _appendVEvent(
            lines: lines,
            sk: sk,
            safeId: safeId,
            namAm: namAm,
            ngayDuong: ngayDuong,
            dtStamp: dtStamp,
          );
        }
      }
    }

    lines.add('END:VCALENDAR');
    return '${lines.map(_foldIcsLine).join('\r\n')}\r\n';
  }

  static void _appendVEvent({
    required List<String> lines,
    required SuKien sk,
    required String safeId,
    required int namAm,
    required DateTime ngayDuong,
    required String dtStamp,
  }) {
    final dtStart = _formatDate(ngayDuong);
    final dtEnd = _formatDate(ngayDuong.add(const Duration(days: 1)));
    final summary = '${sk.ten} (${sk.ngayAm}/${sk.thangAm} ÂL)';

    final descParts = <String>[];
    if (sk.ghiChu != null && sk.ghiChu!.trim().isNotEmpty) {
      descParts.add(sk.ghiChu!.trim());
    }
    descParts.add(
      'Ngày âm lịch: ${sk.ngayAm}/${sk.thangAm}${sk.namAm != null ? '/${sk.namAm}' : ' (lặp hằng năm)'}',
    );
    if (sk.tag != null && sk.tag!.trim().isNotEmpty) {
      descParts.add('Thẻ: ${sk.tag!.trim()}');
    }

    lines.add('BEGIN:VEVENT');
    lines.add('UID:vielich-$safeId-$namAm@vielich.app');
    lines.add('DTSTAMP:$dtStamp');
    lines.add('DTSTART;VALUE=DATE:$dtStart');
    lines.add('DTEND;VALUE=DATE:$dtEnd');
    lines.add('SUMMARY:${_escapeIcsText(summary)}');
    lines.add('DESCRIPTION:${_escapeIcsText(descParts.join('\n'))}');
    if (sk.tag != null && sk.tag!.trim().isNotEmpty) {
      lines.add('CATEGORIES:${_escapeIcsText(sk.tag!.trim())}');
    }

    // Metadata mở rộng giúp nhập ngược vào VIE Lịch không mất thông tin gốc
    lines.add('X-VIELICH-ID:$safeId');
    lines.add('X-VIELICH-TITLE:${_escapeIcsText(sk.ten)}');
    lines.add('X-VIELICH-LUNAR:${sk.ngayAm}/${sk.thangAm}/${sk.namAm ?? ''}');
    lines.add('X-VIELICH-REMIND:${sk.baoTruoc},${sk.gioNhac},${sk.phutNhac}');
    if (sk.ghiChu != null && sk.ghiChu!.trim().isNotEmpty) {
      lines.add('X-VIELICH-NOTE:${_escapeIcsText(sk.ghiChu!.trim())}');
    }
    if (sk.tag != null && sk.tag!.trim().isNotEmpty) {
      lines.add('X-VIELICH-TAG:${_escapeIcsText(sk.tag!.trim())}');
    }

    lines.add('BEGIN:VALARM');
    lines.add('ACTION:DISPLAY');
    lines.add('DESCRIPTION:${_escapeIcsText('Nhắc lịch: ${sk.ten}')}');
    lines.add(
        'TRIGGER:${_formatTriggerOffset(sk.baoTruoc, sk.gioNhac, sk.phutNhac)}');
    lines.add('END:VALARM');
    lines.add('END:VEVENT');
  }

  /// Đọc nội dung file .ics và chuyển thành danh sách [SuKien] (tự gộp các kỳ lặp nhiều năm).
  static List<SuKien> parseNoiDungIcs(String rawContent) {
    final byteLen = utf8.encode(rawContent).length;
    if (byteLen > maxIcsBytes) {
      throw const FormatException('File .ics vượt quá giới hạn 5 MB');
    }

    final normalized = rawContent
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\n[ \t]'), '');

    final lines = normalized.split('\n');
    final ketQua = <SuKien>[];
    final seenSeriesKeys = <String>{};

    bool inEvent = false;
    bool inAlarm = false;
    Map<String, String> props = {};

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final upper = line.toUpperCase();
      if (upper == 'BEGIN:VEVENT') {
        inEvent = true;
        inAlarm = false;
        props = {};
        continue;
      }
      if (upper == 'END:VEVENT') {
        if (inEvent) {
          final parsed = _parseSingleVEvent(props, seenSeriesKeys);
          if (parsed != null) {
            ketQua.add(parsed);
            if (ketQua.length >= maxImportedEvents) {
              break;
            }
          }
        }
        inEvent = false;
        inAlarm = false;
        continue;
      }
      if (!inEvent) continue;

      if (upper == 'BEGIN:VALARM') {
        inAlarm = true;
        continue;
      }
      if (upper == 'END:VALARM') {
        inAlarm = false;
        continue;
      }
      if (inAlarm) continue;

      final colonIdx = line.indexOf(':');
      if (colonIdx <= 0) continue;
      final fullKey = line.substring(0, colonIdx).trim();
      final value = line.substring(colonIdx + 1);
      final baseKey = fullKey.split(';').first.toUpperCase();
      props[baseKey] = value;
    }

    return ketQua;
  }

  static SuKien? _parseSingleVEvent(
    Map<String, String> props,
    Set<String> seenSeriesKeys,
  ) {
    final vlId = props['X-VIELICH-ID']?.trim();
    final vlLunar = props['X-VIELICH-LUNAR']?.trim();

    if (vlLunar != null && vlLunar.isNotEmpty) {
      if (vlId != null && vlId.isNotEmpty && !seenSeriesKeys.add('vl:$vlId')) {
        return null;
      }
      final parts = vlLunar.split('/');
      if (parts.length < 2) return null;
      final ngayAm = int.tryParse(parts[0]);
      final thangAm = int.tryParse(parts[1]);
      final namAm =
          parts.length >= 3 && parts[2].isNotEmpty ? int.tryParse(parts[2]) : null;
      if (ngayAm == null || thangAm == null) return null;

      int baoTruoc = 3;
      int gioNhac = 11;
      int phutNhac = 30;
      final remindRaw = props['X-VIELICH-REMIND'];
      if (remindRaw != null) {
        final rParts = remindRaw.split(',');
        if (rParts.length >= 3) {
          baoTruoc = int.tryParse(rParts[0]) ?? 3;
          gioNhac = int.tryParse(rParts[1]) ?? 11;
          phutNhac = int.tryParse(rParts[2]) ?? 30;
        }
      }

      final rawTitle = props['X-VIELICH-TITLE'] != null
          ? _unescapeIcsText(props['X-VIELICH-TITLE']!)
          : _stripLunarSuffix(_unescapeIcsText(props['SUMMARY'] ?? ''));
      if (rawTitle.trim().isEmpty) return null;

      return SuKien.fromJson({
        'id': _uuid.v4(),
        'ten': rawTitle.trim(),
        'ngayAm': ngayAm,
        'thangAm': thangAm,
        'namAm': namAm,
        'ghiChu': props['X-VIELICH-NOTE'] != null
            ? _unescapeIcsText(props['X-VIELICH-NOTE']!)
            : null,
        'baoTruoc': baoTruoc,
        'gioNhac': gioNhac,
        'phutNhac': phutNhac,
        'tag': props['X-VIELICH-TAG'] != null
            ? _unescapeIcsText(props['X-VIELICH-TAG']!)
            : null,
      });
    }

    // Sự kiện chuẩn từ ứng dụng lịch bên ngoài (Google Calendar / Apple Calendar...)
    final uid = props['UID']?.trim();
    if (uid != null && uid.isNotEmpty && !seenSeriesKeys.add('uid:$uid')) {
      return null;
    }

    final dtStartRaw = props['DTSTART']?.trim();
    if (dtStartRaw == null || dtStartRaw.isEmpty) return null;
    final solar = _parseIcsDateTime(dtStartRaw);
    if (solar == null) return null;

    final lunar = AmLichHelper.duongSangAm(solar);
    if (lunar == null) return null;

    final summary = _unescapeIcsText(props['SUMMARY'] ?? '').trim();
    if (summary.isEmpty) return null;

    final hasTime = dtStartRaw.contains('T');
    final desc = props['DESCRIPTION'] != null
        ? _unescapeIcsText(props['DESCRIPTION']!).trim()
        : null;
    final categories = props['CATEGORIES'] != null
        ? _unescapeIcsText(props['CATEGORIES']!).trim()
        : null;

    return SuKien.fromJson({
      'id': _uuid.v4(),
      'ten': _stripLunarSuffix(summary),
      'ngayAm': lunar.day,
      'thangAm': lunar.month,
      'namAm': null,
      'ghiChu': (desc != null && desc.isNotEmpty) ? desc : null,
      'baoTruoc': 1,
      'gioNhac': hasTime ? solar.hour : 8,
      'phutNhac': hasTime ? solar.minute : 0,
      'tag': (categories != null && categories.isNotEmpty) ? categories : null,
    });
  }

  /// Xuất file .ics ra thiết bị (Desktop mở hộp thoại Lưu file; Mobile mở Share Sheet).
  static Future<bool> xuatFileIcs(
    List<SuKien> dsSuKien, {
    required int soNam,
    String? fileName,
  }) async {
    if (dsSuKien.isEmpty) return false;

    final icsContent = taoNoiDungIcs(dsSuKien, soNam: soNam);
    final bytes = Uint8List.fromList(utf8.encode(icsContent));
    final safeName = fileName ??
        (dsSuKien.length == 1
            ? 'vielich_${_slugify(dsSuKien.first.ten)}_${soNam}nam.ics'
            : 'vielich_${dsSuKien.length}_su_kien_${soNam}nam.ics');

    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      if (Platform.isMacOS) {
        await FilePicker.skipEntitlementsChecks();
      }
      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'Lưu file lịch (.ics)',
        fileName: safeName,
        bytes: bytes,
        mimeType: 'text/calendar',
      );
      return savedUri != null;
    }

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$safeName');
    await tempFile.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(tempFile.path, mimeType: 'text/calendar')],
        subject: 'Lịch âm VIE Lịch ($soNam năm)',
      ),
    );
    return true;
  }

  /// Chọn và đọc file .ics từ thiết bị. Trả về `null` nếu người dùng hủy chọn.
  static Future<List<SuKien>?> chonVaDocFileIcs() async {
    if (Platform.isMacOS) {
      await FilePicker.skipEntitlementsChecks();
    }
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['ics', 'ical'],
      dialogTitle: 'Chọn file lịch (.ics) để nhập',
    );
    if (files.isEmpty || files.first.path == null) {
      return null;
    }

    final file = File(files.first.path!);
    if (await file.length() > maxIcsBytes) {
      throw const FormatException('File .ics vượt quá giới hạn 5 MB');
    }
    final content = await file.readAsString();
    return parseNoiDungIcs(content);
  }

  // ============================================================
  // HELPERS ĐỊNH DẠNG RFC 5545
  // ============================================================

  static String _sanitizeUid(String id) =>
      id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  static String _slugify(String input) {
    final cleaned = input
        .toLowerCase()
        .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
        .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
        .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
        .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
        .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
        .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y')
        .replaceAll(RegExp(r'đ'), 'd')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (cleaned.isEmpty) return 'su_kien';
    return cleaned.length > 32 ? cleaned.substring(0, 32) : cleaned;
  }

  static String _stripLunarSuffix(String summary) {
    return summary
        .replaceFirst(RegExp(r'\s*\(\d{1,2}/\d{1,2}\s*ÂL\)\s*$'), '')
        .trim();
  }

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  static String _formatUtcTimestamp(DateTime utc) =>
      '${_formatDate(utc)}T${utc.hour.toString().padLeft(2, '0')}${utc.minute.toString().padLeft(2, '0')}${utc.second.toString().padLeft(2, '0')}Z';

  static String _formatTriggerOffset(int baoTruoc, int gioNhac, int phutNhac) {
    final offsetMinutes = (gioNhac * 60 + phutNhac) - (baoTruoc * 1440);
    if (offsetMinutes == 0) return 'PT0M';
    final prefix = offsetMinutes < 0 ? '-' : '';
    int rem = offsetMinutes.abs();
    final days = rem ~/ 1440;
    rem %= 1440;
    final hours = rem ~/ 60;
    final minutes = rem % 60;

    final buf = StringBuffer('${prefix}P');
    if (days > 0) buf.write('${days}D');
    if (hours > 0 || minutes > 0 || days == 0) {
      buf.write('T');
      if (hours > 0) buf.write('${hours}H');
      if (minutes > 0 || (days == 0 && hours == 0)) buf.write('${minutes}M');
    }
    return buf.toString();
  }

  static String _escapeIcsText(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll(';', '\\;')
        .replaceAll(',', '\\,')
        .replaceAll('\r\n', '\\n')
        .replaceAll('\n', '\\n');
  }

  static String _unescapeIcsText(String text) {
    final buf = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (text[i] == '\\' && i + 1 < text.length) {
        final next = text[i + 1];
        if (next == 'n' || next == 'N') {
          buf.write('\n');
          i++;
          continue;
        } else if (next == '\\' || next == ';' || next == ',') {
          buf.write(next);
          i++;
          continue;
        }
      }
      buf.write(text[i]);
    }
    return buf.toString();
  }

  static String _foldIcsLine(String line) {
    if (utf8.encode(line).length <= 75) return line;
    final parts = <String>[];
    var current = StringBuffer();
    int currentBytes = 0;
    int limit = 75;

    for (final rune in line.runes) {
      final ch = String.fromCharCode(rune);
      final chBytes = utf8.encode(ch).length;
      if (currentBytes + chBytes > limit && currentBytes > 0) {
        parts.add(current.toString());
        current = StringBuffer(' ')..write(ch);
        currentBytes = 1 + chBytes;
        limit = 75;
      } else {
        current.write(ch);
        currentBytes += chBytes;
      }
    }
    if (current.isNotEmpty) {
      parts.add(current.toString());
    }
    return parts.join('\r\n');
  }

  static DateTime? _parseIcsDateTime(String raw) {
    final clean = raw.trim();
    if (clean.length < 8) return null;
    final year = int.tryParse(clean.substring(0, 4));
    final month = int.tryParse(clean.substring(4, 6));
    final day = int.tryParse(clean.substring(6, 8));
    if (year == null || month == null || day == null) return null;

    if (clean.length >= 15 && clean[8] == 'T') {
      final hour = int.tryParse(clean.substring(9, 11)) ?? 0;
      final minute = int.tryParse(clean.substring(11, 13)) ?? 0;
      final second = int.tryParse(clean.substring(13, 15)) ?? 0;
      if (clean.endsWith('Z')) {
        return DateTime.utc(year, month, day, hour, minute, second).toLocal();
      }
      return DateTime(year, month, day, hour, minute, second);
    }
    return DateTime(year, month, day);
  }
}
