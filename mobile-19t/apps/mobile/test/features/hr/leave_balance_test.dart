import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nineteen_tech_app/core/theme/app_theme.dart';
import 'package:nineteen_tech_app/core/theme/theme_color_presets.dart';
import 'package:nineteen_tech_app/features/hr/data/hr_models.dart';
import 'package:nineteen_tech_app/features/hr/data/hr_repository.dart';
import 'package:nineteen_tech_app/features/hr/providers/hr_providers.dart';
import 'package:nineteen_tech_app/features/hr/screens/leave_create_screen.dart';

void main() {
  group('LeaveBalance.fromJson', () {
    test('parses official balance response', () {
      final balance = LeaveBalance.fromJson(const {
        'year': 2026,
        'month': 4,
        'employment_status': 'official',
        'is_paid_leave_eligible': true,
        'allocated_days': 1,
        'used_paid_days': 0.5,
        'remaining_paid_days': 0.5,
        'has_remaining_paid_leave': true,
      });

      expect(balance.year, 2026);
      expect(balance.month, 4);
      expect(balance.employmentStatus, 'official');
      expect(balance.isPaidLeaveEligible, isTrue);
      expect(balance.allocatedDays, 1);
      expect(balance.usedPaidDays, 0.5);
      expect(balance.remainingPaidDays, 0.5);
      expect(balance.hasRemainingPaidLeave, isTrue);
    });
  });

  group('leaveBalanceProvider', () {
    test('returns success data from repository', () async {
      final container = ProviderContainer(
        overrides: [
          hrRepositoryProvider.overrideWithValue(
            _FakeHrRepository(
              balance: const LeaveBalance(
                year: 2026,
                month: 4,
                employmentStatus: 'official',
                isPaidLeaveEligible: true,
                allocatedDays: 1,
                usedPaidDays: 0.5,
                remainingPaidDays: 0.5,
                hasRemainingPaidLeave: true,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        leaveBalanceProvider(
          const LeaveBalanceQuery(year: 2026, month: 4),
        ).future,
      );

      expect(result.remainingPaidDays, 0.5);
    });

    test('propagates repository error state', () async {
      final container = ProviderContainer(
        overrides: [
          hrRepositoryProvider.overrideWithValue(
            _FakeHrRepository(error: Exception('balance failed')),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(
          leaveBalanceProvider(
            const LeaveBalanceQuery(year: 2026, month: 4),
          ).future,
        ),
        throwsException,
      );
    });

    test('rejects incomplete query before sending request', () async {
      final container = ProviderContainer(
        overrides: [
          hrRepositoryProvider.overrideWithValue(_FakeHrRepository()),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(
          leaveBalanceProvider(const LeaveBalanceQuery(year: 2026)).future,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('buildLeaveBalanceMessage', () {
    test('shows official remaining message', () {
      expect(
        buildLeaveBalanceMessage(
          const LeaveBalance(
            year: 2026,
            month: 4,
            employmentStatus: 'official',
            isPaidLeaveEligible: true,
            allocatedDays: 1,
            usedPaidDays: 0.5,
            remainingPaidDays: 0.5,
            hasRemainingPaidLeave: true,
          ),
        ),
        'Bạn còn 0.5 ngày nghỉ có lương trong tháng này',
      );
    });

    test('shows official exhausted message', () {
      expect(
        buildLeaveBalanceMessage(
          const LeaveBalance(
            year: 2026,
            month: 4,
            employmentStatus: 'official',
            isPaidLeaveEligible: true,
            allocatedDays: 1,
            usedPaidDays: 1,
            remainingPaidDays: 0,
            hasRemainingPaidLeave: false,
          ),
        ),
        'Bạn đã dùng hết phép có lương trong tháng này',
      );
    });

    test('shows probation message', () {
      expect(
        buildLeaveBalanceMessage(
          const LeaveBalance(
            year: 2026,
            month: 4,
            employmentStatus: 'probation',
            isPaidLeaveEligible: false,
            allocatedDays: 0,
            usedPaidDays: 0,
            remainingPaidDays: 0,
            hasRemainingPaidLeave: false,
          ),
        ),
        'Bạn là nhân viên thử việc, nghỉ phép sẽ không tính lương',
      );
    });
  });

  group('LeaveBalanceInfoCard', () {
    testWidgets('renders official remaining message', (tester) async {
      await tester.pumpWidget(
        _materialApp(
          LeaveBalanceInfoCard(
            balanceAsync: const AsyncData(
              LeaveBalance(
                year: 2026,
                month: 4,
                employmentStatus: 'official',
                isPaidLeaveEligible: true,
                allocatedDays: 1,
                usedPaidDays: 0.5,
                remainingPaidDays: 0.5,
                hasRemainingPaidLeave: true,
              ),
            ),
            palette: AppThemePreset.noirGold.palette,
          ),
        ),
      );

      expect(
        find.text('Bạn còn 0.5 ngày nghỉ có lương trong tháng này'),
        findsOneWidget,
      );
    });

    testWidgets('renders probation message', (tester) async {
      await tester.pumpWidget(
        _materialApp(
          LeaveBalanceInfoCard(
            balanceAsync: const AsyncData(
              LeaveBalance(
                year: 2026,
                month: 4,
                employmentStatus: 'probation',
                isPaidLeaveEligible: false,
                allocatedDays: 0,
                usedPaidDays: 0,
                remainingPaidDays: 0,
                hasRemainingPaidLeave: false,
              ),
            ),
            palette: AppThemePreset.noirGold.palette,
          ),
        ),
      );

      expect(
        find.text('Bạn là nhân viên thử việc, nghỉ phép sẽ không tính lương'),
        findsOneWidget,
      );
    });

    testWidgets('renders fallback error state', (tester) async {
      await tester.pumpWidget(
        _materialApp(
          LeaveBalanceInfoCard(
            balanceAsync: AsyncError(Exception('failed'), StackTrace.empty),
            palette: AppThemePreset.noirGold.palette,
          ),
        ),
      );

      expect(
        find.text('Không tải được số phép có lương còn lại.'),
        findsOneWidget,
      );
    });
  });
}

Widget _materialApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(body: child),
  );
}

class _FakeHrRepository extends HrRepository {
  _FakeHrRepository({this.balance, this.error}) : super(Dio());

  final LeaveBalance? balance;
  final Object? error;

  @override
  Future<LeaveBalance> getLeaveBalance({int? year, int? month}) async {
    if (error != null) {
      throw error!;
    }

    return balance ??
        const LeaveBalance(
          year: 2026,
          month: 4,
          employmentStatus: 'official',
          isPaidLeaveEligible: true,
          allocatedDays: 1,
          usedPaidDays: 0,
          remainingPaidDays: 1,
          hasRemainingPaidLeave: true,
        );
  }
}
