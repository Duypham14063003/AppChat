import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/features/hr/screens/payroll_config_screen.dart';

void main() {
  group('normalizePayrollTimeValue', () {
    test('normalizes PostgreSQL time strings to HH:mm', () {
      expect(normalizePayrollTimeValue('08:00:00'), '08:00');
      expect(normalizePayrollTimeValue('9:5:00'), '09:05');
    });

    test('falls back for invalid values', () {
      expect(normalizePayrollTimeValue(''), '');
      expect(normalizePayrollTimeValue('invalid', fallback: '23:59'), '23:59');
    });
  });

  group('validatePayrollTimeValue', () {
    test('allows empty value only for nullable fields', () {
      expect(validatePayrollTimeValue('', allowEmpty: true), isNull);
      expect(
        validatePayrollTimeValue('', allowEmpty: false),
        'Vui lòng chọn giờ',
      );
    });

    test('accepts normalized HH:mm values', () {
      expect(validatePayrollTimeValue('09:30:00', allowEmpty: false), isNull);
    });
  });
}
