import 'package:dio/dio.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nineteen_tech_app/core/theme/app_theme.dart';
import 'package:nineteen_tech_app/features/auth/data/auth_repository.dart';
import 'package:nineteen_tech_app/features/auth/providers/auth_notifier.dart';
import 'package:nineteen_tech_app/features/hr/data/hr_models.dart';
import 'package:nineteen_tech_app/features/hr/data/hr_repository.dart';
import 'package:nineteen_tech_app/features/hr/providers/hr_providers.dart';
import 'package:nineteen_tech_app/features/hr/screens/employee_management_screens.dart';

void main() {
  testWidgets(
    'manager sees employee payment card and embedded attendance tab',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _EmployeeDetailRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(
              () => _FakeAuthNotifier(const ['manager']),
            ),
            hrRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const EmployeeDetailScreen(employeeId: 'emp-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chấm công'), findsOneWidget);
      await tester.tap(find.text('Hồ sơ HR'));
      await tester.pumpAndSettle();
      expect(find.text('Thông tin thanh toán'), findsOneWidget);
      expect(find.text('Vietcombank'), findsWidgets);
      expect(find.text('VietQR tự động'), findsOneWidget);

      await tester.tap(find.text('Chấm công'));
      await tester.pumpAndSettle();
      expect(find.textContaining('10 ngày'), findsOneWidget);
      expect(repository.summaryRequests.single.$2, 'emp-1');
      expect(
        find.byKey(const ValueKey('employee-working-days-calendar')),
        findsOneWidget,
      );
      final firstMonth = repository.summaryRequests.single.$1;
      await tester.tap(find.byTooltip('Tháng trước'));
      await tester.pumpAndSettle();
      expect(repository.summaryRequests, hasLength(2));
      expect(repository.summaryRequests.last.$1, isNot(firstMonth));
    },
  );

  testWidgets('attendance initializes to next payroll month on boundary day', (
    tester,
  ) async {
    final repository = _EmployeeDetailRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(
            () => _FakeAuthNotifier(const ['manager'], payrollStartConfig: 25),
          ),
          employeeAttendanceCurrentDateProvider.overrideWithValue(
            DateTime(2026, 7, 25),
          ),
          hrRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const EmployeeDetailScreen(employeeId: 'emp-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chấm công'));
    await tester.pumpAndSettle();

    expect(repository.summaryRequests.single, ('2026-08', 'emp-1'));
    expect(find.text('Chấm công tháng 8/2026'), findsOneWidget);
  });

  testWidgets('regular employee does not receive cross-user attendance tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(
            () => _FakeAuthNotifier(const ['employee']),
          ),
          hrRepositoryProvider.overrideWithValue(_EmployeeDetailRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const EmployeeDetailScreen(employeeId: 'emp-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chấm công'), findsNothing);
  });

  testWidgets('configured HR role ID receives employee attendance access', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(
            () => _FakeAuthNotifier(const [
              '4a5ce6f3-25e9-462a-b161-439a6a4e3e99',
            ]),
          ),
          hrRepositoryProvider.overrideWithValue(_EmployeeDetailRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const EmployeeDetailScreen(employeeId: 'emp-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chấm công'), findsOneWidget);
  });

  testWidgets('job-title config does not grant employee management access', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(
            () => _FakeAuthNotifier(
              const ['employee'],
              configRoles: const ['4a5ce6f3-25e9-462a-b161-439a6a4e3e99'],
            ),
          ),
          hrRepositoryProvider.overrideWithValue(_EmployeeDetailRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const EmployeeDetailScreen(employeeId: 'emp-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chấm công'), findsNothing);
  });

  testWidgets('unconfigured role ID does not receive attendance access', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(
            () => _FakeAuthNotifier(const [
              '80c32170-fcea-494d-8c40-54bfcfad32ec',
            ]),
          ),
          hrRepositoryProvider.overrideWithValue(_EmployeeDetailRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const EmployeeDetailScreen(employeeId: 'emp-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chấm công'), findsNothing);
  });

  testWidgets('attendance distinguishes zero, unmapped and unavailable data', (
    tester,
  ) async {
    Future<void> pumpStatus(
      AttendanceDataStatus status, {
      double? actualWorkingDays,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey('${status.name}-$actualWorkingDays'),
          overrides: [
            authNotifierProvider.overrideWith(
              () => _FakeAuthNotifier(const ['manager']),
            ),
            hrRepositoryProvider.overrideWithValue(
              _EmployeeDetailRepository(
                attendanceStatus: status,
                actualWorkingDays: actualWorkingDays,
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const EmployeeDetailScreen(employeeId: 'emp-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chấm công'));
      await tester.pumpAndSettle();
    }

    await pumpStatus(AttendanceDataStatus.available, actualWorkingDays: 0);
    expect(find.textContaining('0 ngày'), findsOneWidget);

    await pumpStatus(AttendanceDataStatus.unmapped);
    expect(find.text('Chưa liên kết nhân sự Odoo'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('employee-working-days-calendar')),
      findsNothing,
    );

    await pumpStatus(AttendanceDataStatus.unavailable);
    expect(find.text('Chưa tải được dữ liệu chấm công'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('employee-working-days-calendar')),
      findsNothing,
    );
  });

  testWidgets('attendance audits Saturday half-day, exclusions and leave', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _EmployeeDetailRepository(auditSummary: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(
            () => _FakeAuthNotifier(const ['manager']),
          ),
          hrRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const EmployeeDetailScreen(employeeId: 'emp-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chấm công'));
    await tester.pumpAndSettle();

    expect(find.textContaining('0.5 ngày'), findsWidgets);
    expect(find.text('Tính 0.5 công'), findsOneWidget);
    expect(find.text('Không tính: chưa check-out'), findsOneWidget);
    expect(find.text('Phép năm'), findsWidgets);
    expect(
      find.byKey(const ValueKey('employee-working-days-day-detail')),
      findsOneWidget,
    );
  });

  testWidgets('attendance refreshes and switches cache key by employee', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _EmployeeDetailRepository();

    Widget app(String employeeId) => ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(
          () => _FakeAuthNotifier(const ['manager']),
        ),
        hrRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: EmployeeDetailScreen(
          key: ValueKey(employeeId),
          employeeId: employeeId,
        ),
      ),
    );

    await tester.pumpWidget(app('emp-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chấm công'));
    await tester.pumpAndSettle();
    expect(repository.summaryRequests.single.$2, 'emp-1');

    await tester.tap(find.byKey(const ValueKey('employee-attendance-refresh')));
    await tester.pumpAndSettle();
    expect(repository.summaryRequests, hasLength(2));

    await tester.pumpWidget(app('emp-2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chấm công'));
    await tester.pumpAndSettle();
    expect(repository.summaryRequests.last.$2, 'emp-2');
    expect(tester.takeException(), isNull);
  });

  testWidgets('uploaded QR exposes source controls and warns after bank change', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final qrImageAdapter = _QrImageAdapter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(
            () => _FakeAuthNotifier(const ['manager']),
          ),
          hrRepositoryProvider.overrideWithValue(
            _EmployeeDetailRepository(uploadedQr: true),
          ),
          dioProvider.overrideWithValue(
            Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'))
              ..httpClientAdapter = qrImageAdapter,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const EmployeeDetailScreen(employeeId: 'emp-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hồ sơ HR'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sửa hồ sơ'));
    await tester.pumpAndSettle();

    expect(find.text('Thay ảnh QR'), findsOneWidget);
    expect(find.text('Xóa ảnh QR'), findsOneWidget);
    expect(find.text('Dùng VietQR tự động'), findsOneWidget);
    expect(qrImageAdapter.requests, hasLength(1));
    expect(
      qrImageAdapter.requests.single.uri.toString(),
      'https://api.example.test/api/v1/hr/employees/emp-1/payment-qr/image/abc-123.png',
    );

    final accountField = find.widgetWithText(TextFormField, 'Số tài khoản');
    await tester.enterText(accountField, '987654321');
    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Lưu thay đổi'),
    );
    saveButton.onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('Ảnh QR có thể không còn khớp'), findsOneWidget);
    expect(find.text('Giữ ảnh đã tải'), findsOneWidget);
  });

  testWidgets('failed QR upload keeps form state and supports retry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _EmployeeDetailRepository(uploadFailuresRemaining: 1);
    final qrImageAdapter = _QrImageAdapter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(
            () => _FakeAuthNotifier(const ['manager']),
          ),
          hrRepositoryProvider.overrideWithValue(repository),
          dioProvider.overrideWithValue(
            Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'))
              ..httpClientAdapter = qrImageAdapter,
          ),
          employeePaymentQrImagePickerProvider.overrideWithValue(
            () async => XFile.fromData(
              Uint8List.fromList(const [0x89, 0x50, 0x4e, 0x47]),
              name: 'payment-qr.png',
              mimeType: 'image/png',
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const EmployeeDetailScreen(employeeId: 'emp-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hồ sơ HR'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sửa hồ sơ'));
    await tester.pumpAndSettle();

    final accountField = find.widgetWithText(TextFormField, 'Số tài khoản');
    await tester.enterText(accountField, '987654321');
    final uploadButton = find.text('Tải ảnh QR lên');
    await tester.ensureVisible(uploadButton);
    await tester.pumpAndSettle();
    await tester.tap(uploadButton);
    await tester.pumpAndSettle();

    expect(find.text('Mất kết nối khi tải ảnh QR'), findsWidgets);
    expect(
      find.byKey(const ValueKey('payment-qr-operation-error')),
      findsOneWidget,
    );
    expect(find.text('Thử lại'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(accountField).controller?.text,
      '987654321',
    );
    expect(repository.uploadAttempts, 1);

    final retryButton = find.text('Thử lại');
    await tester.ensureVisible(retryButton);
    await tester.pumpAndSettle();
    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(repository.uploadAttempts, 2);
    expect(
      find.byKey(const ValueKey('payment-qr-operation-error')),
      findsNothing,
    );
    expect(find.text('Thay ảnh QR'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(accountField).controller?.text,
      '987654321',
    );
  });
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(
    this.roles, {
    this.configRoles = const [],
    this.payrollStartConfig,
  });
  final List<String> roles;
  final List<String> configRoles;
  final int? payrollStartConfig;

  @override
  Future<AuthState> build() async => AuthState(
    status: AuthStatus.authenticated,
    user: UserInfo(
      id: 'manager-1',
      email: 'manager@19t.vn',
      name: 'Manager',
      roles: roles,
    ),
    configRoles: configRoles,
    payrollStartConfig: payrollStartConfig,
  );
}

class _EmployeeDetailRepository extends HrRepository {
  _EmployeeDetailRepository({
    this.uploadedQr = false,
    this.attendanceStatus = AttendanceDataStatus.available,
    this.actualWorkingDays = 10,
    this.auditSummary = false,
    this.uploadFailuresRemaining = 0,
  }) : super(Dio());
  final bool uploadedQr;
  final AttendanceDataStatus attendanceStatus;
  final double? actualWorkingDays;
  final bool auditSummary;
  int uploadFailuresRemaining;
  int uploadAttempts = 0;
  final summaryRequests = <(String, String)>[];

  @override
  Future<EmployeeDetailResponse> getEmployeeDetail(String id) async {
    return EmployeeDetailResponse(
      employee: HrEmployeeSummary(
        id: id,
        name: 'Nguyen Van A',
        email: 'a@19t.vn',
      ),
      profile: EmployeeProfile(
        userId: id,
        bankCode: 'VCB',
        bankName: 'Vietcombank',
        bankAccountNumber: '123456789',
        bankAccountName: 'NGUYEN VAN A',
        bankQrImageUrl: uploadedQr
            ? '/api/v1/hr/employees/$id/payment-qr/image/abc-123.png'
            : null,
        bankQrSource: uploadedQr ? 'uploaded' : 'generated',
      ),
    );
  }

  @override
  Future<List<EmployeeContract>> getEmployeeContracts(String userId) async =>
      const [];

  @override
  Future<EmployeeProfile> uploadEmployeePaymentQr({
    String? userId,
    required XFile file,
  }) async {
    uploadAttempts += 1;
    if (uploadFailuresRemaining > 0) {
      uploadFailuresRemaining -= 1;
      throw ArgumentError('Mất kết nối khi tải ảnh QR');
    }
    return EmployeeProfile(
      userId: userId ?? 'emp-1',
      bankCode: 'VCB',
      bankAccountNumber: '123456789',
      bankQrImageUrl:
          '/api/v1/hr/employees/${userId ?? 'emp-1'}/payment-qr/image/retry-1.png',
      bankQrSource: 'uploaded',
    );
  }

  @override
  Future<EmployeePayrollSummary> getEmployeePayrollSummary({
    required String month,
    required String userId,
  }) async {
    summaryRequests.add((month, userId));
    final auditDate = '$month-08';
    return EmployeePayrollSummary(
      userId: userId,
      month: month,
      cycleFrom: '$month-01',
      cycleToExclusive: month == '2026-12' ? '2027-01-01' : '$month-28',
      attendanceStatus: attendanceStatus,
      actualWorkingDays: auditSummary ? 0.5 : actualWorkingDays,
      attendanceSessions: auditSummary
          ? [
              EmployeePayrollAttendanceSession(
                id: 1,
                date: auditDate,
                checkIn: DateTime.parse('${auditDate}T01:00:00Z'),
                checkOut: DateTime.parse('${auditDate}T10:00:00Z'),
                workedHours: 9,
                counted: true,
                dayValue: 0.5,
                exclusionReason: null,
              ),
              EmployeePayrollAttendanceSession(
                id: 2,
                date: auditDate,
                checkIn: DateTime.parse('${auditDate}T02:00:00Z'),
                checkOut: null,
                workedHours: null,
                counted: false,
                dayValue: null,
                exclusionReason: 'missing_checkout',
              ),
            ]
          : const [],
      leaveOrders: auditSummary
          ? [
              LeaveRequest(
                id: 'leave-1',
                userId: userId,
                type: 'annual',
                startDate: auditDate,
                endDate: auditDate,
                isHalfDay: true,
                halfDayPart: 'morning',
                requestedDays: 0.5,
                status: 'approved',
              ),
            ]
          : const [],
    );
  }
}

class _QrImageAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromBytes(
      const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
      200,
      headers: {
        Headers.contentTypeHeader: ['image/png'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
