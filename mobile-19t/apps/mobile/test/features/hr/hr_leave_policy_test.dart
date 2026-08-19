import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nineteen_tech_app/core/theme/app_theme.dart';
import 'package:nineteen_tech_app/core/theme/theme_color_presets.dart';
import 'package:nineteen_tech_app/features/auth/data/auth_repository.dart';
import 'package:nineteen_tech_app/features/auth/providers/auth_notifier.dart';
import 'package:nineteen_tech_app/features/hr/data/hr_models.dart';
import 'package:nineteen_tech_app/features/hr/data/hr_repository.dart';
import 'package:nineteen_tech_app/features/hr/screens/attendance_screen.dart';
import 'package:nineteen_tech_app/features/hr/screens/leave_create_screen.dart';
import 'package:nineteen_tech_app/features/hr/screens/leave_detail_screen.dart';
import 'package:nineteen_tech_app/features/hr/providers/hr_providers.dart';

void main() {
  group('leave request validation', () {
    test('allows regular leave for a single full day', () {
      expect(
        validateLeaveRequestInput(
          type: 'annual',
          isHalfDay: false,
          startDate: DateTime(2026, 4, 20),
          endDate: DateTime(2026, 4, 20),
        ),
        isNull,
      );
    });

    test('rejects half-day leave spanning multiple days', () {
      expect(
        validateLeaveRequestInput(
          type: 'annual',
          isHalfDay: true,
          startDate: DateTime(2026, 4, 20),
          endDate: DateTime(2026, 4, 21),
          halfDayPart: 'morning',
        ),
        'Nghỉ nửa ngày chỉ được phép trong cùng 1 ngày',
      );
    });

    test('rejects ot when end time is not after start time', () {
      expect(
        validateLeaveRequestInput(
          type: 'ot',
          isHalfDay: false,
          startDate: DateTime(2026, 4, 20),
          endDate: DateTime(2026, 4, 20),
          startTime: const TimeOfDay(hour: 21, minute: 0),
          endTime: const TimeOfDay(hour: 20, minute: 30),
        ),
        'Giờ kết thúc phải sau giờ bắt đầu',
      );
    });

    test('allows overnight ot when end datetime is after start datetime', () {
      expect(
        validateLeaveRequestInput(
          type: 'ot',
          isHalfDay: false,
          startDate: DateTime(2026, 6, 5),
          endDate: DateTime(2026, 6, 6),
          startTime: const TimeOfDay(hour: 18, minute: 0),
          endTime: const TimeOfDay(hour: 0, minute: 0),
        ),
        isNull,
      );
    });

    test('calculates overnight ot hours from continuous datetime range', () {
      expect(
        calculateOtHours(
          startDate: DateTime(2026, 6, 5),
          endDate: DateTime(2026, 6, 6),
          startTime: const TimeOfDay(hour: 18, minute: 0),
          endTime: const TimeOfDay(hour: 0, minute: 0),
        ),
        6,
      );
    });
  });

  group('leave create screen', () {
    testWidgets('shows regular leave controls by default', (tester) async {
      await tester.pumpWidget(_buildTestApp(const LeaveCreateScreen()));

      expect(find.text('Loại đơn'), findsOneWidget);
      expect(find.text('OFF'), findsOneWidget);
      expect(find.text('WFH'), findsOneWidget);
      expect(find.text('OT'), findsOneWidget);
      expect(find.text('Loại nghỉ phép'), findsOneWidget);
      expect(find.text('Phép năm'), findsOneWidget);
      expect(find.text('Thời lượng nghỉ'), findsOneWidget);
      expect(find.text('Bắt đầu'), findsNothing);
      expect(find.text('Kết thúc'), findsNothing);
      expect(find.text('Tổng thời gian OT (giờ)'), findsNothing);
    });

    testWidgets('switches to ot fields and hides half-day controls', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(const LeaveCreateScreen()));

      await tester.tap(find.text('OT'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Loại nghỉ phép'), findsNothing);
      expect(find.text('Thời lượng nghỉ'), findsNothing);
      expect(find.text('Bắt đầu'), findsOneWidget);
      expect(find.text('Kết thúc'), findsOneWidget);
      expect(find.text('Tổng thời gian OT (giờ)'), findsOneWidget);
    });
  });

  group('leave display', () {
    testWidgets('renders paid and unpaid leave information clearly', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          const LeaveDetailScreen(
            leaveId: 'leave-1',
            leaveData: LeaveRequest(
              id: 'leave-1',
              type: 'annual',
              startDate: '2026-04-20',
              endDate: '2026-04-20',
              reason: 'Việc gia đình',
              isHalfDay: true,
              halfDayPart: 'morning',
              requestedDays: 1,
              paidDays: 0.5,
              unpaidDays: 0.5,
              status: 'approved',
            ),
          ),
        ),
      );

      expect(find.text('Số ngày nghỉ có lương'), findsOneWidget);
      expect(find.text('Số ngày nghỉ không lương'), findsOneWidget);
      expect(find.text('0.5'), findsWidgets);
    });

    testWidgets('shows approval and cancellation activity details', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          LeaveDetailScreen(
            leaveId: 'leave-cancelled',
            leaveData: LeaveRequest(
              id: 'leave-cancelled',
              userId: 'employee-1',
              type: 'annual',
              startDate: '2026-07-28',
              endDate: '2026-07-28',
              isHalfDay: false,
              status: 'cancelled',
              approvedAt: DateTime(2026, 7, 20, 9),
              approverName: 'Manager A',
              cancelledAt: DateTime(2026, 7, 21, 10),
              cancellerName: 'Admin B',
              cancelReason: 'Nhân viên thay đổi lịch nghỉ',
            ),
          ),
          roles: const ['manager'],
        ),
      );

      expect(find.text('Lịch sử hoạt động'), findsOneWidget);
      expect(find.text('Manager A'), findsOneWidget);
      expect(find.text('Admin B'), findsOneWidget);
      expect(find.text('Nhân viên thay đổi lịch nghỉ'), findsOneWidget);
      expect(find.text('Hủy đơn đã duyệt'), findsNothing);
    });

    testWidgets('allows manager to cancel an approved leave with a reason', (
      tester,
    ) async {
      final repository = _FakeHrRepository();
      await tester.pumpWidget(
        _buildTestApp(
          LeaveDetailScreen(
            leaveId: 'leave-approved',
            leaveData: LeaveRequest(
              id: 'leave-approved',
              userId: 'employee-1',
              type: 'annual',
              startDate: '2026-07-28',
              endDate: '2026-07-28',
              isHalfDay: false,
              status: 'approved',
              approvedAt: DateTime(2026, 7, 20, 9),
              approverName: 'Manager A',
            ),
          ),
          roles: const ['manager'],
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Hủy đơn đã duyệt'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(find.text('Hủy đơn đã duyệt'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Nhân viên thay đổi lịch nghỉ',
      );
      await tester.tap(find.text('Xác nhận hủy'));
      await tester.pumpAndSettle();

      expect(repository.cancelledLeaveId, 'leave-approved');
      expect(repository.cancelReason, 'Nhân viên thay đổi lịch nghỉ');
    });

    testWidgets('renders monthly summary breakdown with new fields', (
      tester,
    ) async {
      await tester.pumpWidget(
        _plainMaterialApp(
          AttendanceMonthlySummarySection(
            summary: const AttendanceSummary(
              totalDays: 20,
              totalHours: 160,
              totalOt: 8,
              daysLate: 2,
              paidLeaveDays: 1,
              unpaidLeaveDays: 0.5,
              absentWithoutLeaveDays: 0.5,
              daysAbsent: 1,
            ),
            palette: AppThemePreset.noirGold.palette,
            isWide: false,
          ),
        ),
      );

      expect(find.text('Nghỉ có lương'), findsOneWidget);
      expect(find.text('Nghỉ không lương'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
      expect(find.text('0.5'), findsWidgets);
    });
  });
}

Widget _buildTestApp(
  Widget child, {
  List<String> roles = const [],
  _FakeHrRepository? repository,
}) {
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(() => _FakeAuthNotifier(roles)),
      hrRepositoryProvider.overrideWithValue(repository ?? _FakeHrRepository()),
    ],
    child: _plainMaterialApp(child),
  );
}

Widget _plainMaterialApp(Widget child) {
  return MaterialApp(theme: AppTheme.dark(), home: child);
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this.roles);

  final List<String> roles;

  @override
  Future<AuthState> build() async {
    return AuthState(
      status: AuthStatus.authenticated,
      user: UserInfo(
        id: 'u1',
        email: 'tester@example.com',
        name: 'Tester',
        employmentStatus: 'official',
        roles: roles,
      ),
    );
  }
}

class _FakeHrRepository extends HrRepository {
  _FakeHrRepository() : super(Dio());

  String? cancelledLeaveId;
  String? cancelReason;

  @override
  Future<LeaveRequest> cancelApprovedLeave(String id, String reason) async {
    cancelledLeaveId = id;
    cancelReason = reason;
    return LeaveRequest(
      id: id,
      type: 'annual',
      startDate: '2026-07-28',
      endDate: '2026-07-28',
      isHalfDay: false,
      status: 'cancelled',
      cancelReason: reason,
    );
  }

  @override
  Future<LeaveBalance> getLeaveBalance({int? year, int? month}) async {
    return const LeaveBalance(
      year: 2026,
      employmentStatus: 'official',
      isPaidLeaveEligible: true,
      allocatedDays: 1,
      usedPaidDays: 0.5,
      remainingPaidDays: 0.5,
      hasRemainingPaidLeave: true,
    );
  }

  @override
  Future<WfhBalance> getWfhBalance({int? year}) async {
    return const WfhBalance(
      year: 2026,
      allocatedDays: 12,
      usedDays: 2,
      remainingDays: 10,
      hasRemainingDays: true,
      isOverride: false,
    );
  }
}
