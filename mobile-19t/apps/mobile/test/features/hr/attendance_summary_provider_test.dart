import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nineteen_tech_app/features/hr/data/hr_models.dart';
import 'package:nineteen_tech_app/features/hr/data/hr_repository.dart';
import 'package:nineteen_tech_app/features/hr/providers/hr_providers.dart';

void main() {
  group('buildPayrollMonthSummaryRange', () {
    test('uses payroll boundary from previous month to selected month', () {
      final range = buildPayrollMonthSummaryRange('2026-03', 25);

      expect(range.from, '2026-02-25');
      expect(range.to, '2026-03-24');
    });

    test('handles next payroll month boundary consistently', () {
      final range = buildPayrollMonthSummaryRange('2026-04', 25);

      expect(range.from, '2026-03-25');
      expect(range.to, '2026-04-24');
    });
  });

  group('attendanceSummaryProvider', () {
    test('requests summary using payroll cycle from config', () async {
      final repo = _FakeHrRepository(config: const {'payroll_start_day': 25});
      final container = ProviderContainer(
        overrides: [hrRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        attendanceSummaryProvider('2026-04').future,
      );

      expect(result.totalDays, 12);
      expect(repo.summaryRequests, [('2026-03-25', '2026-04-24')]);
    });

    test(
      'falls back to calendar start when payroll config is unavailable',
      () async {
        final repo = _FakeHrRepository(configError: Exception('config failed'));
        final container = ProviderContainer(
          overrides: [hrRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        await container.read(attendanceSummaryProvider('2026-04').future);

        expect(repo.summaryRequests, [('2026-03-01', '2026-03-31')]);
      },
    );
  });

  group('resolvePayrollStartDay', () {
    test('defaults to 1 for null or out-of-range config', () {
      expect(resolvePayrollStartDay(null), 1);
      expect(resolvePayrollStartDay(const {'payroll_start_day': 0}), 1);
      expect(resolvePayrollStartDay(const {'payroll_start_day': 29}), 1);
      expect(resolvePayrollStartDay(const {'payroll_start_day': 'abc'}), 1);
    });

    test('parses string values from config payloads', () {
      expect(resolvePayrollStartDay(const {'payroll_start_day': '25'}), 25);
    });
  });

  group('resolveCurrentPayrollMonth', () {
    test('keeps the calendar month before the payroll boundary', () {
      final month = resolveCurrentPayrollMonth(25, now: DateTime(2026, 7, 24));

      expect(month, DateTime(2026, 7));
    });

    test('moves to the next month on the payroll boundary', () {
      final month = resolveCurrentPayrollMonth(25, now: DateTime(2026, 7, 25));

      expect(month, DateTime(2026, 8));
    });

    test('moves to January of the next year after December boundary', () {
      final month = resolveCurrentPayrollMonth(25, now: DateTime(2026, 12, 25));

      expect(month, DateTime(2027, 1));
    });
  });
}

class _FakeHrRepository extends HrRepository {
  _FakeHrRepository({this.config, this.configError}) : super(Dio());

  static const _summary = AttendanceSummary(
    totalDays: 12,
    totalHours: 96,
    totalOt: 4,
    daysLate: 1,
    paidLeaveDays: 1,
    unpaidLeaveDays: 0,
    absentWithoutLeaveDays: 0,
    daysAbsent: 0,
  );

  final Map<String, dynamic>? config;
  final Object? configError;
  final List<(String from, String to)> summaryRequests = [];

  @override
  Future<Map<String, dynamic>> getConfig() async {
    if (configError != null) {
      throw configError!;
    }

    return config ?? const {'payroll_start_day': 1};
  }

  @override
  Future<AttendanceSummary> getSummary(String from, String to) async {
    summaryRequests.add((from, to));
    return _summary;
  }
}
