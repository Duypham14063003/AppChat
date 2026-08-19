import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/core/theme/app_theme.dart';
import 'package:nineteen_tech_app/features/auth/data/auth_repository.dart';
import 'package:nineteen_tech_app/features/auth/providers/auth_notifier.dart';
import 'package:nineteen_tech_app/features/hr/data/hr_models.dart';
import 'package:nineteen_tech_app/features/hr/data/hr_repository.dart';
import 'package:nineteen_tech_app/features/hr/data/payroll_export_file_service.dart';
import 'package:nineteen_tech_app/features/hr/providers/hr_providers.dart';
import 'package:nineteen_tech_app/features/hr/screens/leave_list_screen.dart';

void main() {
  group('LeaveListScreen payroll export', () {
    testWidgets('hides export button for non-approver roles', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          repository: _FakeHrRepository(),
          fileService: _FakePayrollExportFileService(),
          roles: const ['employee'],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('leave-list-export-payroll')),
        findsNothing,
      );
    });

    testWidgets('exports selected payroll month for approvers', (tester) async {
      final repository = _FakeHrRepository();
      final fileService = _FakePayrollExportFileService();

      await tester.pumpWidget(
        _buildTestApp(
          repository: repository,
          fileService: fileService,
          roles: const ['manager'],
        ),
      );
      await tester.pumpAndSettle();

      final payrollMonth = resolveCurrentPayrollMonth(25);
      expect(repository.requestedYear, payrollMonth.year);
      expect(repository.requestedMonth, payrollMonth.month);

      await tester.tap(find.byType(DropdownButtonFormField<int>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tháng 6').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('leave-list-export-payroll')));
      await tester.pumpAndSettle();

      final expectedMonth = '${DateTime.now().year}-06';
      expect(repository.exportedMonth, expectedMonth);
      expect(fileService.savedFilename, 'bang-cong-luong-$expectedMonth.xlsx');
    });
  });

  group('LeaveListScreen employee filter and working days', () {
    testWidgets(
      'keeps all employee options, filters by ID, shows zero, and retains selection across months',
      (tester) async {
        final repository = _FakeHrRepository(
          employees: const [
            HrEmployeeSummary(
              id: 'emp-a',
              name: 'Trùng Tên',
              email: 'a@19t.vn',
            ),
            HrEmployeeSummary(
              id: 'emp-b',
              name: 'Trùng Tên',
              email: 'b@19t.vn',
            ),
            HrEmployeeSummary(
              id: 'emp-old',
              name: 'Nhân viên cũ',
              email: 'old@19t.vn',
              isActive: false,
            ),
          ],
          leaves: const [
            LeaveRequest(
              id: 'leave-a',
              userId: 'emp-a',
              type: 'annual',
              startDate: '2026-08-01',
              endDate: '2026-08-01',
              isHalfDay: false,
              userName: 'Trùng Tên',
            ),
          ],
          actualWorkingDays: 0,
        );
        await tester.pumpWidget(
          _buildTestApp(
            repository: repository,
            fileService: _FakePayrollExportFileService(),
            roles: const ['manager'],
          ),
        );
        await tester.pumpAndSettle();

        final employeeDropdown = find.byWidgetPredicate(
          (widget) => widget is DropdownButtonFormField<String?>,
        );
        await tester.tap(employeeDropdown);
        await tester.pumpAndSettle();
        expect(find.text('Trùng Tên • a@19t.vn'), findsOneWidget);
        expect(find.text('Trùng Tên • b@19t.vn'), findsOneWidget);
        expect(find.text('Nhân viên cũ (đã nghỉ)'), findsOneWidget);

        await tester.tap(find.text('Trùng Tên • b@19t.vn'));
        await tester.pumpAndSettle();

        expect(repository.requestedUserIds.last, 'emp-b');
        expect(find.text('0 ngày'), findsOneWidget);
        expect(find.text('Không tìm thấy đơn phù hợp'), findsOneWidget);

        await tester.tap(employeeDropdown);
        await tester.pumpAndSettle();
        expect(find.text('Trùng Tên • a@19t.vn'), findsOneWidget);
        expect(find.text('Trùng Tên • b@19t.vn'), findsWidgets);
        await tester.tap(find.text('Trùng Tên • b@19t.vn').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DropdownButtonFormField<int>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tháng 6').last);
        await tester.pumpAndSettle();

        expect(repository.requestedUserIds.last, 'emp-b');
        expect(repository.summaryRequests.last, (
          '${DateTime.now().year}-06',
          'emp-b',
        ));

        await tester.tap(employeeDropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tất cả nhân viên').last);
        await tester.pumpAndSettle();

        expect(repository.requestedUserIds.last, isNull);
        expect(find.text('Ngày công thực tế'), findsNothing);
      },
    );

    testWidgets('shows unavailable attendance as non-numeric status', (
      tester,
    ) async {
      final repository = _FakeHrRepository(
        employees: const [
          HrEmployeeSummary(id: 'emp-a', name: 'Employee A', email: 'a@19t.vn'),
        ],
        attendanceStatus: AttendanceDataStatus.unavailable,
      );
      await tester.pumpWidget(
        _buildTestApp(
          repository: repository,
          fileService: _FakePayrollExportFileService(),
          roles: const ['manager'],
        ),
      );
      await tester.pumpAndSettle();

      final employeeDropdown = find.byWidgetPredicate(
        (widget) => widget is DropdownButtonFormField<String?>,
      );
      await tester.tap(employeeDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Employee A'));
      await tester.pumpAndSettle();

      expect(find.text('Không có dữ liệu'), findsOneWidget);
      expect(find.text('0 ngày'), findsNothing);
    });

    testWidgets('opens attendance calendar with counted sessions and orders', (
      tester,
    ) async {
      final repository = _FakeHrRepository(
        employees: const [
          HrEmployeeSummary(id: 'emp-a', name: 'Employee A', email: 'a@19t.vn'),
        ],
        leaves: const [
          LeaveRequest(
            id: 'leave-1',
            userId: 'emp-a',
            type: 'annual',
            startDate: '2026-08-08',
            endDate: '2026-08-08',
            isHalfDay: true,
            halfDayPart: 'morning',
            requestedDays: 0.5,
            status: 'approved',
          ),
        ],
        actualWorkingDays: 0.5,
        attendanceSessions: const [
          EmployeePayrollAttendanceSession(
            id: 101,
            date: '2026-08-08',
            checkIn: null,
            checkOut: null,
            workedHours: 8,
            counted: true,
            dayValue: 0.5,
            exclusionReason: null,
          ),
        ],
      );
      await tester.pumpWidget(
        _buildTestApp(
          repository: repository,
          fileService: _FakePayrollExportFileService(),
          roles: const ['manager'],
        ),
      );
      await tester.pumpAndSettle();

      final employeeDropdown = find.byWidgetPredicate(
        (widget) => widget is DropdownButtonFormField<String?>,
      );
      await tester.tap(employeeDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Employee A'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('leave-list-actual-working-days')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('employee-working-days-detail-dialog')),
        findsOneWidget,
      );
      expect(find.text('Chi tiết ngày công thực tế'), findsOneWidget);
      expect(find.text('0.5 ngày'), findsWidgets);
      expect(find.text('Tính 0.5 công'), findsOneWidget);
      expect(find.text('Chấm công (1 phiên)'), findsOneWidget);
      expect(find.text('Phép năm'), findsOneWidget);
      expect(find.text('Đã duyệt'), findsWidgets);
    });
  });
}

Widget _buildTestApp({
  required HrRepository repository,
  required PayrollExportFileService fileService,
  required List<String> roles,
}) {
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(() => _FakeAuthNotifier(roles: roles)),
      hrRepositoryProvider.overrideWithValue(repository),
      payrollExportFileServiceProvider.overrideWithValue(fileService),
    ],
    child: MaterialApp(theme: AppTheme.dark(), home: const LeaveListScreen()),
  );
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier({required this.roles});

  final List<String> roles;

  @override
  Future<AuthState> build() async {
    return AuthState(
      status: AuthStatus.authenticated,
      user: UserInfo(
        id: 'u1',
        email: 'manager@example.com',
        name: 'Manager',
        employmentStatus: 'official',
        roles: roles,
      ),
      payrollStartConfig: 25,
    );
  }
}

class _FakeHrRepository extends HrRepository {
  _FakeHrRepository({
    this.employees = const [],
    this.leaves = const [],
    this.attendanceStatus = AttendanceDataStatus.available,
    this.actualWorkingDays = 0,
    this.attendanceSessions = const [],
  }) : super(Dio());

  String? exportedMonth;
  int? requestedYear;
  int? requestedMonth;
  final List<HrEmployeeSummary> employees;
  final List<LeaveRequest> leaves;
  final AttendanceDataStatus attendanceStatus;
  final double? actualWorkingDays;
  final List<EmployeePayrollAttendanceSession> attendanceSessions;
  final List<String?> requestedUserIds = [];
  final List<(String, String)> summaryRequests = [];

  @override
  Future<LeaveListResponse> getLeaves({
    String? status,
    String? userId,
    int? year,
    int? month,
  }) async {
    requestedYear = year;
    requestedMonth = month;
    requestedUserIds.add(userId);
    final filteredLeaves = userId == null
        ? leaves
        : leaves.where((leave) => leave.userId == userId).toList();
    return LeaveListResponse(
      leaves: filteredLeaves,
      otHours: 0,
      leaveDays: 0,
      wfhDays: 0,
    );
  }

  @override
  Future<List<HrEmployeeSummary>> getAllEmployees({int pageSize = 100}) async {
    return employees;
  }

  @override
  Future<EmployeePayrollSummary> getEmployeePayrollSummary({
    required String month,
    required String userId,
  }) async {
    summaryRequests.add((month, userId));
    return EmployeePayrollSummary(
      userId: userId,
      month: month,
      cycleFrom: '2026-07-25',
      cycleToExclusive: '2026-08-25',
      attendanceStatus: attendanceStatus,
      actualWorkingDays: actualWorkingDays,
      attendanceSessions: attendanceSessions,
      leaveOrders: leaves,
    );
  }

  @override
  Future<PayrollWorkbookDownload> exportPayrollWorkbook({
    required String month,
  }) async {
    exportedMonth = month;
    return PayrollWorkbookDownload(
      bytes: Uint8List.fromList(const [1, 2, 3]),
      filename: 'bang-cong-luong-$month.xlsx',
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }
}

class _FakePayrollExportFileService extends PayrollExportFileService {
  String? savedFilename;

  @override
  Future<void> save(PayrollWorkbookDownload workbook) async {
    savedFilename = workbook.filename;
  }
}
