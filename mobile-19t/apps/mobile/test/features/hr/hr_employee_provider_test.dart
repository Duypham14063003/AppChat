import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nineteen_tech_app/features/hr/data/hr_models.dart';
import 'package:nineteen_tech_app/features/hr/data/hr_repository.dart';
import 'package:nineteen_tech_app/features/hr/providers/hr_providers.dart';

void main() {
  test('employee directory notifier loads more pages', () async {
    final repo = _FakeHrRepository();
    final container = ProviderContainer(
      overrides: [hrRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(
      hrEmployeeDirectoryProvider(
        const HrEmployeeDirectoryQuery(limit: 1),
      ).notifier,
    );
    final first = await container.read(
      hrEmployeeDirectoryProvider(
        const HrEmployeeDirectoryQuery(limit: 1),
      ).future,
    );

    expect(first.items, hasLength(1));
    expect(first.hasMore, isTrue);

    await notifier.loadMore();
    final second = await container.read(
      hrEmployeeDirectoryProvider(
        const HrEmployeeDirectoryQuery(limit: 1),
      ).future,
    );

    expect(second.items, hasLength(2));
    expect(second.items.last.name, 'Employee 2');
  });

  test(
    'leave employee options are complete and deterministically sorted',
    () async {
      final repo = _FakeHrRepository();
      final container = ProviderContainer(
        overrides: [hrRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final employees = await container.read(
        leaveEmployeeOptionsProvider.future,
      );

      expect(employees.map((employee) => employee.id), [
        'emp-a',
        'emp-b',
        'emp-inactive',
      ]);
      expect(employees.last.isActive, isFalse);
    },
  );

  test(
    'employee payroll summary provider is keyed by month and employee ID',
    () async {
      final repo = _FakeHrRepository();
      final container = ProviderContainer(
        overrides: [hrRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      const query = EmployeePayrollSummaryQuery(
        month: '2026-08',
        userId: 'emp-a',
      );

      final first = await container.read(
        employeePayrollSummaryProvider(query).future,
      );
      final second = await container.read(
        employeePayrollSummaryProvider(query).future,
      );

      expect(first.actualWorkingDays, 9);
      expect(second.actualWorkingDays, 9);
      expect(repo.summaryRequests, [('2026-08', 'emp-a')]);
    },
  );

  test(
    'payment QR upload invalidates self and targeted employee data',
    () async {
      final repo = _FakeHrRepository();
      final container = ProviderContainer(
        overrides: [hrRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final selfSubscription = container.listen(
        myEmployeeProfileProvider,
        (_, _) {},
        fireImmediately: true,
      );
      final detailSubscription = container.listen(
        employeeDetailProvider('emp-a'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(selfSubscription.close);
      addTearDown(detailSubscription.close);
      await container.read(myEmployeeProfileProvider.future);
      await container.read(employeeDetailProvider('emp-a').future);

      final uploaded = await container
          .read(employeeProfileMutationProvider.notifier)
          .uploadPaymentQr(
            userId: 'emp-a',
            file: XFile.fromData(
              Uint8List.fromList([1, 2, 3]),
              name: 'qr.png',
              mimeType: 'image/png',
            ),
          );
      await container.read(myEmployeeProfileProvider.future);
      await container.read(employeeDetailProvider('emp-a').future);

      expect(uploaded.bankQrSource, 'uploaded');
      expect(repo.uploadTargets, ['emp-a']);
      expect(repo.selfDetailRequests, 2);
      expect(repo.detailRequests, ['emp-a', 'emp-a']);
    },
  );

  test(
    'payment QR removal uses self endpoint and refreshes self data',
    () async {
      final repo = _FakeHrRepository();
      final container = ProviderContainer(
        overrides: [hrRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final selfSubscription = container.listen(
        myEmployeeProfileProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(selfSubscription.close);
      await container.read(myEmployeeProfileProvider.future);

      final removed = await container
          .read(employeeProfileMutationProvider.notifier)
          .deletePaymentQr();
      await container.read(myEmployeeProfileProvider.future);

      expect(removed.bankQrSource, 'generated');
      expect(repo.deleteTargets, [null]);
      expect(repo.selfDetailRequests, 2);
    },
  );

  test(
    'recoverable payment QR failure is exposed without invalidation',
    () async {
      final repo = _FakeHrRepository()..paymentQrError = StateError('offline');
      final container = ProviderContainer(
        overrides: [hrRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final selfSubscription = container.listen(
        myEmployeeProfileProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(selfSubscription.close);
      await container.read(myEmployeeProfileProvider.future);

      await expectLater(
        container
            .read(employeeProfileMutationProvider.notifier)
            .uploadPaymentQr(
              file: XFile.fromData(
                Uint8List.fromList([1]),
                name: 'qr.png',
                mimeType: 'image/png',
              ),
            ),
        throwsStateError,
      );

      expect(container.read(employeeProfileMutationProvider).hasError, isTrue);
      expect(repo.selfDetailRequests, 1);
    },
  );

  test('QR source switching uses self and HR profile mutation paths', () async {
    final repo = _FakeHrRepository();
    final container = ProviderContainer(
      overrides: [hrRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await container
        .read(employeeProfileMutationProvider.notifier)
        .updateSelf(
          const EmployeeProfileUpdateRequest(bankQrSource: 'generated'),
        );
    await container
        .read(employeeProfileMutationProvider.notifier)
        .updateEmployee(
          userId: 'emp-a',
          request: const EmployeeProfileUpdateRequest(bankQrSource: 'uploaded'),
        );

    expect(repo.selfProfileSources, ['generated']);
    expect(repo.employeeProfileSources, [('emp-a', 'uploaded')]);
  });
}

class _FakeHrRepository extends HrRepository {
  _FakeHrRepository() : super(Dio());

  final List<(String, String)> summaryRequests = [];
  final List<String> detailRequests = [];
  final List<String?> uploadTargets = [];
  final List<String?> deleteTargets = [];
  final List<String?> selfProfileSources = [];
  final List<(String, String?)> employeeProfileSources = [];
  int selfDetailRequests = 0;
  Object? paymentQrError;

  EmployeeDetailResponse _detail(String id) => EmployeeDetailResponse(
    employee: HrEmployeeSummary(
      id: id,
      name: 'Employee $id',
      email: '$id@19t.vn',
    ),
    profile: EmployeeProfile(
      userId: id,
      bankCode: 'VCB',
      bankAccountNumber: '123456789',
      bankQrSource: 'generated',
    ),
  );

  @override
  Future<EmployeeDetailResponse> getMyEmployeeProfile() async {
    selfDetailRequests += 1;
    return _detail('self-1');
  }

  @override
  Future<EmployeeDetailResponse> getEmployeeDetail(String id) async {
    detailRequests.add(id);
    return _detail(id);
  }

  @override
  Future<EmployeeProfile> updateMyEmployeeProfile(
    EmployeeProfileUpdateRequest request,
  ) async {
    selfProfileSources.add(request.bankQrSource);
    return EmployeeProfile(
      userId: 'self-1',
      bankQrSource: request.bankQrSource,
    );
  }

  @override
  Future<EmployeeProfile> updateEmployeeProfile({
    required String userId,
    required EmployeeProfileUpdateRequest request,
  }) async {
    employeeProfileSources.add((userId, request.bankQrSource));
    return EmployeeProfile(userId: userId, bankQrSource: request.bankQrSource);
  }

  @override
  Future<EmployeeProfile> uploadEmployeePaymentQr({
    String? userId,
    required XFile file,
  }) async {
    uploadTargets.add(userId);
    if (paymentQrError case final error?) throw error;
    return EmployeeProfile(
      userId: userId ?? 'self-1',
      bankQrImageUrl:
          '/api/v1/hr/employees/${userId ?? 'self-1'}/payment-qr/image/qr-1.png',
      bankQrSource: 'uploaded',
    );
  }

  @override
  Future<EmployeeProfile> deleteEmployeePaymentQr({String? userId}) async {
    deleteTargets.add(userId);
    if (paymentQrError case final error?) throw error;
    return EmployeeProfile(
      userId: userId ?? 'self-1',
      bankCode: 'VCB',
      bankAccountNumber: '123456789',
      bankQrSource: 'generated',
    );
  }

  @override
  Future<List<HrEmployeeSummary>> getAllEmployees({int pageSize = 100}) async {
    return const [
      HrEmployeeSummary(
        id: 'emp-inactive',
        name: 'Zed',
        email: 'z@19t.vn',
        isActive: false,
      ),
      HrEmployeeSummary(id: 'emp-b', name: 'An', email: 'b@19t.vn'),
      HrEmployeeSummary(id: 'emp-a', name: 'An', email: 'a@19t.vn'),
    ];
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
      attendanceStatus: AttendanceDataStatus.available,
      actualWorkingDays: 9,
    );
  }

  @override
  Future<HrEmployeeDirectoryPage> getEmployees({
    String? search,
    String? department,
    String? jobTitle,
    bool? isActive,
    String? employmentStatus,
    int page = 1,
    int limit = 20,
  }) async {
    if (page == 1) {
      return const HrEmployeeDirectoryPage(
        items: [
          HrEmployeeSummary(
            id: 'emp-1',
            name: 'Employee 1',
            email: 'e1@19t.vn',
          ),
        ],
        total: 2,
        page: 1,
        limit: 1,
      );
    }
    return const HrEmployeeDirectoryPage(
      items: [
        HrEmployeeSummary(id: 'emp-2', name: 'Employee 2', email: 'e2@19t.vn'),
      ],
      total: 2,
      page: 2,
      limit: 1,
    );
  }
}
