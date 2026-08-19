import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nineteen_tech_app/core/theme/app_theme.dart';
import 'package:nineteen_tech_app/features/hr/data/hr_models.dart';
import 'package:nineteen_tech_app/features/hr/data/hr_repository.dart';
import 'package:nineteen_tech_app/features/hr/providers/hr_providers.dart';
import 'package:nineteen_tech_app/features/hr/screens/attendance_history_screen.dart';

void main() {
  group('AttendanceHistoryScreen navigation', () {
    testWidgets('opens leave detail when tapping a leave-derived row', (
      tester,
    ) async {
      final today = DateTime.now();
      const leave = LeaveRequest(
        id: 'leave-1',
        type: 'annual',
        startDate: '2026-01-01',
        endDate: '2026-01-01',
        isHalfDay: false,
        status: 'approved',
      );
      final datedLeave = LeaveRequest(
        id: leave.id,
        type: leave.type,
        startDate: _dateString(today),
        endDate: _dateString(today),
        isHalfDay: leave.isHalfDay,
        status: leave.status,
      );
      final router = _buildRouter();

      await tester.pumpWidget(
        _buildTestApp(
          router: router,
          repository: _FakeHrRepository(leaves: [datedLeave]),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('attendance-history-leave-leave-1')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('attendance-history-leave-leave-1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('detail:leave-1'), findsOneWidget);
      expect(find.text('extra:leave-1'), findsOneWidget);
    });

    testWidgets('does not navigate when tapping a regular attendance row', (
      tester,
    ) async {
      final today = DateTime.now();
      final checkin = DateTime(today.year, today.month, today.day, 8, 0);
      final router = _buildRouter();

      await tester.pumpWidget(
        _buildTestApp(
          router: router,
          repository: _FakeHrRepository(
            attendanceRecords: [
              {
                'checkin_at': checkin.toIso8601String(),
                'checkout_at': checkin
                    .add(const Duration(hours: 8))
                    .toIso8601String(),
                'total_hours': 8,
              },
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final attendanceKey = ValueKey(
        'attendance-history-attendance-${checkin.millisecondsSinceEpoch}',
      );
      expect(find.byKey(attendanceKey), findsOneWidget);

      await tester.tap(find.byKey(attendanceKey));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/hr/history');
      expect(find.textContaining('detail:'), findsNothing);
    });
  });
}

Widget _buildTestApp({
  required GoRouter router,
  required HrRepository repository,
}) {
  return ProviderScope(
    overrides: [hrRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
  );
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/hr/history',
    routes: [
      GoRoute(
        path: '/hr/history',
        builder: (context, state) => const AttendanceHistoryScreen(),
      ),
      GoRoute(
        path: '/hr/leaves/:id',
        builder: (context, state) => _LeaveDetailProbe(
          leaveId: state.pathParameters['id']!,
          extra: state.extra,
        ),
      ),
    ],
  );
}

String _dateString(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

class _LeaveDetailProbe extends StatelessWidget {
  const _LeaveDetailProbe({required this.leaveId, required this.extra});

  final String leaveId;
  final Object? extra;

  @override
  Widget build(BuildContext context) {
    final leave = extra is LeaveRequest ? extra! as LeaveRequest : null;
    return Scaffold(
      body: Column(
        children: [
          Text('detail:$leaveId'),
          Text('extra:${leave?.id ?? 'missing'}'),
        ],
      ),
    );
  }
}

class _FakeHrRepository extends HrRepository {
  _FakeHrRepository({this.attendanceRecords = const [], this.leaves = const []})
    : super(Dio());

  final List<dynamic> attendanceRecords;
  final List<LeaveRequest> leaves;

  @override
  Future<List<dynamic>> getHistory({String? from, String? to}) async {
    return attendanceRecords;
  }

  @override
  Future<LeaveListResponse> getLeaves({
    String? status,
    String? userId,
    int? year,
    int? month,
  }) async {
    return LeaveListResponse(
      leaves: leaves,
      otHours: 0,
      leaveDays: 0,
      wfhDays: 0,
    );
  }
}
