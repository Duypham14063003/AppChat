import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/features/hr/data/vietqr.dart';

void main() {
  group('VietQrPayloadBuilder', () {
    test('builds deterministic dynamic recipient payload with valid CRC', () {
      final payload = const VietQrPayloadBuilder().build(
        bankCode: 'VCB',
        accountNumber: ' 123456789 ',
      );

      expect(payload, startsWith('000201010211'));
      expect(payload, contains('970436'));
      expect(payload, contains('123456789'));
      expect(payload, contains('QRIBFTTA'));
      expect(payload, isNot(contains('540'))); // no amount field
      expect(payload, isNot(contains('620'))); // no additional-message template
      expect(RegExp(r'[0-9A-F]{4}$').hasMatch(payload), isTrue);
      expect(_crc16(payload.substring(0, payload.length - 4)), '5330');
      expect(
        payload,
        '00020101021138530010A0000007270123000697043601091234567890208QRIBFTTA53037045802VN63045330',
      );
      expect(
        const VietQrPayloadBuilder().build(
          bankCode: 'VCB',
          accountNumber: '123456789',
        ),
        payload,
      );
    });

    test('supports known bank BINs', () {
      expect(VietQrBanks.byCode('MB')?.bin, '970422');
      expect(VietQrBanks.byCode('tcb')?.bin, '970407');
      expect(VietQrBanks.version, '2026-08-12');
    });

    test('rejects unsupported banks and invalid accounts', () {
      expect(
        () => const VietQrPayloadBuilder().build(
          bankCode: 'UNKNOWN',
          accountNumber: '123',
        ),
        throwsArgumentError,
      );
      expect(
        () => const VietQrPayloadBuilder().build(
          bankCode: 'VCB',
          accountNumber: '',
        ),
        throwsArgumentError,
      );
      expect(
        () => const VietQrPayloadBuilder().build(
          bankCode: 'VCB',
          accountNumber: 'tài-khoản',
        ),
        throwsArgumentError,
      );
      expect(
        () => const VietQrPayloadBuilder().build(
          bankCode: 'VCB',
          accountNumber: '12345',
        ),
        throwsArgumentError,
      );
      expect(
        () => const VietQrPayloadBuilder().build(
          bankCode: 'VCB',
          accountNumber: '12345678901234567890',
        ),
        throwsArgumentError,
      );
    });

    test(
      'encodes byte lengths and normalizes whitespace deterministically',
      () {
        final payload = const VietQrPayloadBuilder().build(
          bankCode: ' vcb ',
          accountNumber: '12 3456\n789',
        );
        final root = _parseTlv(payload.substring(0, payload.length - 8));
        final merchant = _parseTlv(root['38']!);
        final beneficiary = _parseTlv(merchant['01']!);

        expect(root['00'], '01');
        expect(root['01'], '11');
        expect(root['53'], '704');
        expect(root['58'], 'VN');
        expect(merchant['00'], 'A000000727');
        expect(merchant['02'], 'QRIBFTTA');
        expect(beneficiary, {'00': '970436', '01': '123456789'});
      },
    );
  });
}

Map<String, String> _parseTlv(String payload) {
  final fields = <String, String>{};
  var offset = 0;
  while (offset < payload.length) {
    final id = payload.substring(offset, offset + 2);
    final length = int.parse(payload.substring(offset + 2, offset + 4));
    final valueStart = offset + 4;
    final valueEnd = valueStart + length;
    fields[id] = payload.substring(valueStart, valueEnd);
    offset = valueEnd;
  }
  expect(offset, payload.length);
  return fields;
}

String _crc16(String input) {
  var crc = 0xffff;
  for (final byte in utf8.encode(input)) {
    crc ^= byte << 8;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 0x8000) != 0
          ? ((crc << 1) ^ 0x1021) & 0xffff
          : (crc << 1) & 0xffff;
    }
  }
  return crc.toRadixString(16).padLeft(4, '0').toUpperCase();
}
