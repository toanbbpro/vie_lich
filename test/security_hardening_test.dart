import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vie_lich/models/su_kien.dart';
import 'package:vie_lich/services/deep_link_service.dart';

void main() {
  group('SuKien.fromJson input clamping & media stripping', () {
    test('clamps out-of-range dates/times and drops local media paths', () {
      final sk = SuKien.fromJson({
        'id': 'fixed-attacker-id',
        'ten': '  ${'A' * 300}  ',
        'ngayAm': 99,
        'thangAm': -4,
        'namAm': 99999,
        'baoTruoc': 5000,
        'gioNhac': 75,
        'phutNhac': -10,
        'ghiChu': 'B' * 1500,
        'duongDanAnh': '/etc/passwd',
        'dsMedia': ['/etc/shadow'],
      });

      expect(sk.ten.length, 200);
      expect(sk.ngayAm, 30);
      expect(sk.thangAm, 1);
      expect(sk.namAm, isNull);
      expect(sk.baoTruoc, 365);
      expect(sk.gioNhac, 23);
      expect(sk.phutNhac, 0);
      expect(sk.ghiChu?.length, 1000);
      expect(sk.duongDanAnh, isNull);
      expect(sk.dsMedia, isNull);
    });
  });

  group('DeepLinkService.parseSharedEvents hardening', () {
    test('parses valid gzip payload and regenerates unique UUIDs', () {
      final raw = jsonEncode([
        {'id': 'collide-id', 'ten': 'Giỗ Tổ', 'ngayAm': 10, 'thangAm': 3},
      ]);
      final encoded = base64UrlEncode(gzip.encode(utf8.encode(raw)));

      final events = DeepLinkService.parseSharedEvents(
        encoded,
        allowUncompressed: false,
      );

      expect(events, hasLength(1));
      expect(events.first.ten, 'Giỗ Tổ');
      expect(events.first.id, isNot('collide-id'));
    });

    test('blocks gzip decompression bomb exceeding 256 KB', () {
      final bombBytes = List<int>.filled(1024 * 1024, 65); // 1 MB uncompressed
      final encoded = base64UrlEncode(gzip.encode(bombBytes));
      expect(encoded.length, lessThan(65536));

      expect(
        () => DeepLinkService.parseSharedEvents(
          encoded,
          allowUncompressed: false,
        ),
        throwsFormatException,
      );
    });

    test('caps event array length to 100 entries', () {
      final many = List.generate(
        150,
        (i) => {'ten': 'E$i', 'ngayAm': 1, 'thangAm': 1},
      );
      final encoded = base64UrlEncode(gzip.encode(utf8.encode(jsonEncode(many))));

      final events = DeepLinkService.parseSharedEvents(encoded);
      expect(events.length, 100);
    });
  });
}
