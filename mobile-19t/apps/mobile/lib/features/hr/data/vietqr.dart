import 'dart:convert';

class VietQrBank {
  const VietQrBank({required this.code, required this.name, required this.bin});

  final String code;
  final String name;
  final String bin;
}

class VietQrBanks {
  VietQrBanks._();

  // Versioned 2026-08-12 from the VietQR supported-bank registry. Only
  // transferSupported institutions are included in the first app release.
  static const version = '2026-08-12';
  static const values = <VietQrBank>[
    VietQrBank(code: 'ICB', name: 'VietinBank', bin: '970415'),
    VietQrBank(code: 'VCB', name: 'Vietcombank', bin: '970436'),
    VietQrBank(code: 'BIDV', name: 'BIDV', bin: '970418'),
    VietQrBank(code: 'VBA', name: 'Agribank', bin: '970405'),
    VietQrBank(code: 'OCB', name: 'OCB', bin: '970448'),
    VietQrBank(code: 'MB', name: 'MBBank', bin: '970422'),
    VietQrBank(code: 'TCB', name: 'Techcombank', bin: '970407'),
    VietQrBank(code: 'ACB', name: 'ACB', bin: '970416'),
    VietQrBank(code: 'VPB', name: 'VPBank', bin: '970432'),
    VietQrBank(code: 'TPB', name: 'TPBank', bin: '970423'),
    VietQrBank(code: 'STB', name: 'Sacombank', bin: '970403'),
    VietQrBank(code: 'HDB', name: 'HDBank', bin: '970437'),
    VietQrBank(code: 'VIB', name: 'VIB', bin: '970441'),
    VietQrBank(code: 'SHB', name: 'SHB', bin: '970443'),
    VietQrBank(code: 'EIB', name: 'Eximbank', bin: '970431'),
    VietQrBank(code: 'MSB', name: 'MSB', bin: '970426'),
    VietQrBank(code: 'SCB', name: 'SCB', bin: '970429'),
    VietQrBank(code: 'ABB', name: 'ABBANK', bin: '970425'),
    VietQrBank(code: 'BAB', name: 'BacABank', bin: '970409'),
    VietQrBank(code: 'PVCB', name: 'PVcomBank', bin: '970412'),
    VietQrBank(code: 'NCB', name: 'NCB', bin: '970419'),
    VietQrBank(code: 'SHBVN', name: 'ShinhanBank', bin: '970424'),
    VietQrBank(code: 'VAB', name: 'VietABank', bin: '970427'),
    VietQrBank(code: 'NAB', name: 'NamABank', bin: '970428'),
    VietQrBank(code: 'PGB', name: 'PGBank', bin: '970430'),
    VietQrBank(code: 'VIETBANK', name: 'VietBank', bin: '970433'),
    VietQrBank(code: 'BVB', name: 'BaoVietBank', bin: '970438'),
    VietQrBank(code: 'SEAB', name: 'SeABank', bin: '970440'),
    VietQrBank(code: 'LPB', name: 'LPBank', bin: '970449'),
    VietQrBank(code: 'KLB', name: 'KienLongBank', bin: '970452'),
    VietQrBank(code: 'COOPBANK', name: 'Co-opBank', bin: '970446'),
    VietQrBank(code: 'SGICB', name: 'SaigonBank', bin: '970400'),
    VietQrBank(code: 'MBV', name: 'MBV', bin: '970414'),
    VietQrBank(code: 'WVN', name: 'Woori', bin: '970457'),
  ];

  static VietQrBank? byCode(String? code) {
    if (code == null) return null;
    final normalized = code.trim().toUpperCase();
    for (final bank in values) {
      if (bank.code.toUpperCase() == normalized) return bank;
    }
    return null;
  }
}

class VietQrPayloadBuilder {
  const VietQrPayloadBuilder();

  String build({required String bankCode, required String accountNumber}) {
    final bank = VietQrBanks.byCode(bankCode);
    if (bank == null) throw ArgumentError.value(bankCode, 'bankCode');
    final account = accountNumber.replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^[A-Za-z0-9]{6,19}$').hasMatch(account)) {
      throw ArgumentError.value(accountNumber, 'accountNumber');
    }

    final beneficiary = '${_field('00', bank.bin)}${_field('01', account)}';
    final merchantAccount =
        '${_field('00', 'A000000727')}'
        '${_field('01', beneficiary)}'
        '${_field('02', 'QRIBFTTA')}';
    final body =
        '${_field('00', '01')}'
        '${_field('01', '11')}'
        '${_field('38', merchantAccount)}'
        '${_field('53', '704')}'
        '${_field('58', 'VN')}'
        '6304';
    return '$body${_crc16(body).toRadixString(16).padLeft(4, '0').toUpperCase()}';
  }

  String _field(String id, String value) {
    final length = utf8.encode(value).length;
    if (length > 99) throw ArgumentError('VietQR field exceeds 99 bytes');
    return '$id${length.toString().padLeft(2, '0')}$value';
  }

  int _crc16(String input) {
    var crc = 0xffff;
    for (final byte in utf8.encode(input)) {
      crc ^= byte << 8;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc & 0x8000) != 0
            ? ((crc << 1) ^ 0x1021) & 0xffff
            : (crc << 1) & 0xffff;
      }
    }
    return crc;
  }
}
