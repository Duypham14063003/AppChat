import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../data/hr_models.dart';
import '../data/payroll_export_file_service.dart';
import '../data/hr_repository.dart';
import '../../auth/providers/auth_notifier.dart';
import '../../../core/database/app_database.dart';

const _uuid = Uuid();

bool isApprovedLeaveInMonth(
  dynamic leave,
  DateTime monthStart,
  DateTime monthEndExclusive,
) {
  final String? status;
  final String? startDate;
  final String? endDate;

  if (leave is LeaveRequest) {
    status = leave.status;
    startDate = leave.startDate;
    endDate = leave.endDate;
  } else if (leave is Map<String, dynamic>) {
    status = leave['status']?.toString();
    startDate = leave['start_date']?.toString();
    endDate = leave['end_date']?.toString();
  } else {
    return false;
  }

  if (status != 'approved') return false;

  final start = DateTime.tryParse(startDate ?? '');
  if (start == null) return false;
  final end = DateTime.tryParse(endDate ?? '') ?? start;

  return start.isBefore(monthEndExclusive) && !end.isBefore(monthStart);
}

final hrRepositoryProvider = Provider<HrRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return HrRepository(dio);
});

final payrollExportFileServiceProvider = Provider<PayrollExportFileService>((
  ref,
) {
  return PayrollExportFileService();
});

final hrEmployeeDirectoryProvider =
    AsyncNotifierProvider.family<
      HrEmployeeDirectoryNotifier,
      HrEmployeeDirectoryPage,
      HrEmployeeDirectoryQuery
    >(HrEmployeeDirectoryNotifier.new);

class HrEmployeeDirectoryNotifier
    extends
        FamilyAsyncNotifier<HrEmployeeDirectoryPage, HrEmployeeDirectoryQuery> {
  HrEmployeeDirectoryQuery get _query => arg;

  @override
  Future<HrEmployeeDirectoryPage> build(HrEmployeeDirectoryQuery arg) async {
    return ref
        .read(hrRepositoryProvider)
        .getEmployees(
          search: arg.search,
          department: arg.department,
          jobTitle: arg.jobTitle,
          isActive: arg.isActive,
          employmentStatus: arg.employmentStatus,
          page: arg.page,
          limit: arg.limit,
        );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build(_query));
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;
    final nextPage = current.page + 1;
    final next = await ref
        .read(hrRepositoryProvider)
        .getEmployees(
          search: _query.search,
          department: _query.department,
          jobTitle: _query.jobTitle,
          isActive: _query.isActive,
          employmentStatus: _query.employmentStatus,
          page: nextPage,
          limit: _query.limit,
        );
    state = AsyncData(
      HrEmployeeDirectoryPage(
        items: [...current.items, ...next.items],
        total: next.total,
        page: next.page,
        limit: next.limit,
      ),
    );
  }
}

final leaveEmployeeOptionsProvider = FutureProvider<List<HrEmployeeSummary>>((
  ref,
) async {
  final employees = [...await ref.read(hrRepositoryProvider).getAllEmployees()];
  employees.sort((left, right) {
    final nameOrder = left.name.toLowerCase().compareTo(
      right.name.toLowerCase(),
    );
    if (nameOrder != 0) return nameOrder;
    return left.email.toLowerCase().compareTo(right.email.toLowerCase());
  });
  return employees;
});

final employeeDetailProvider =
    FutureProvider.family<EmployeeDetailResponse, String>((ref, employeeId) {
      return ref.read(hrRepositoryProvider).getEmployeeDetail(employeeId);
    });

final myEmployeeProfileProvider = FutureProvider<EmployeeDetailResponse>((ref) {
  return ref.read(hrRepositoryProvider).getMyEmployeeProfile();
});

final employeeContractsProvider =
    AsyncNotifierProvider.family<
      EmployeeContractsNotifier,
      List<EmployeeContract>,
      String
    >(EmployeeContractsNotifier.new);

class EmployeeContractsNotifier
    extends FamilyAsyncNotifier<List<EmployeeContract>, String> {
  String get _employeeId => arg;

  @override
  Future<List<EmployeeContract>> build(String arg) async {
    return ref.read(hrRepositoryProvider).getEmployeeContracts(arg);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build(_employeeId));
  }
}

final expiringEmployeeContractsProvider =
    FutureProvider<List<ExpiringEmployeeContract>>((ref) {
      return ref.read(hrRepositoryProvider).getExpiringContracts();
    });

final employeeProfileMutationProvider =
    AsyncNotifierProvider<EmployeeProfileMutationNotifier, EmployeeProfile?>(
      EmployeeProfileMutationNotifier.new,
    );

final employeePaymentQrImagePickerProvider =
    Provider<Future<XFile?> Function()>((_) {
      return () => ImagePicker().pickImage(source: ImageSource.gallery);
    });

class EmployeeProfileMutationNotifier extends AsyncNotifier<EmployeeProfile?> {
  @override
  Future<EmployeeProfile?> build() async => null;

  Future<EmployeeProfile> updateSelf(EmployeeProfileUpdateRequest request) {
    return _update(null, request, selfService: true);
  }

  Future<EmployeeProfile> updateEmployee({
    required String userId,
    required EmployeeProfileUpdateRequest request,
  }) {
    return _update(userId, request, selfService: false);
  }

  Future<EmployeeProfile> uploadPaymentQr({
    String? userId,
    required XFile file,
  }) {
    return _mutateQr(
      userId,
      () => ref
          .read(hrRepositoryProvider)
          .uploadEmployeePaymentQr(userId: userId, file: file),
    );
  }

  Future<EmployeeProfile> deletePaymentQr({String? userId}) {
    return _mutateQr(
      userId,
      () => ref
          .read(hrRepositoryProvider)
          .deleteEmployeePaymentQr(userId: userId),
    );
  }

  Future<EmployeeProfile> _update(
    String? userId,
    EmployeeProfileUpdateRequest request, {
    required bool selfService,
  }) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(hrRepositoryProvider);
      final profile = selfService || userId == null
          ? await repo.updateMyEmployeeProfile(request)
          : await repo.updateEmployeeProfile(userId: userId, request: request);
      state = AsyncData(profile);
      ref.invalidate(myEmployeeProfileProvider);
      if (userId != null) {
        ref.invalidate(employeeDetailProvider(userId));
      }
      ref.invalidate(
        hrEmployeeDirectoryProvider(const HrEmployeeDirectoryQuery()),
      );
      return profile;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<EmployeeProfile> _mutateQr(
    String? userId,
    Future<EmployeeProfile> Function() operation,
  ) async {
    state = const AsyncLoading();
    try {
      final profile = await operation();
      state = AsyncData(profile);
      ref.invalidate(myEmployeeProfileProvider);
      if (userId != null) ref.invalidate(employeeDetailProvider(userId));
      return profile;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

final employeeContractMutationProvider =
    AsyncNotifierProvider<EmployeeContractMutationNotifier, EmployeeContract?>(
      EmployeeContractMutationNotifier.new,
    );

class EmployeeContractMutationNotifier
    extends AsyncNotifier<EmployeeContract?> {
  @override
  Future<EmployeeContract?> build() async => null;

  Future<EmployeeContract> create(EmployeeContractRequest request) {
    return _submit(
      () => ref.read(hrRepositoryProvider).createEmployeeContract(request),
    );
  }

  Future<EmployeeContract> updateContract({
    required String contractId,
    required EmployeeContractRequest request,
  }) {
    return _submit(
      () => ref
          .read(hrRepositoryProvider)
          .updateEmployeeContract(contractId: contractId, request: request),
    );
  }

  Future<EmployeeContract> renew({
    required String contractId,
    required EmployeeContractRequest request,
  }) {
    return _submit(
      () => ref
          .read(hrRepositoryProvider)
          .renewEmployeeContract(contractId: contractId, request: request),
    );
  }

  Future<EmployeeContract> uploadAttachment({
    required String contractId,
    required XFile file,
  }) {
    return _submit(
      () => ref
          .read(hrRepositoryProvider)
          .uploadEmployeeContractAttachment(contractId: contractId, file: file),
    );
  }

  Future<EmployeeContract> deleteAttachment(String contractId) {
    return _submit(
      () => ref
          .read(hrRepositoryProvider)
          .deleteEmployeeContractAttachment(contractId),
    );
  }

  Future<void> deleteContract(String contractId) async {
    state = const AsyncLoading();
    try {
      await ref.read(hrRepositoryProvider).deleteEmployeeContract(contractId);
      state = const AsyncData(null);
      ref.invalidate(expiringEmployeeContractsProvider);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<EmployeeContract> _submit(
    Future<EmployeeContract> Function() task,
  ) async {
    state = const AsyncLoading();
    try {
      final contract = await task();
      state = AsyncData(contract);
      ref.invalidate(expiringEmployeeContractsProvider);
      return contract;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

int resolvePayrollStartDay(Map<String, dynamic>? config) {
  final value = config?['payroll_start_day'];
  final startDay = switch (value) {
    final int day => day,
    final String text => int.tryParse(text),
    _ => null,
  };

  if (startDay == null || startDay < 1 || startDay > 28) {
    return 1;
  }

  return startDay;
}

DateTime resolveCurrentPayrollMonth(int payrollStartDay, {DateTime? now}) {
  final currentDate = now ?? DateTime.now();
  if (currentDate.day >= payrollStartDay) {
    return DateTime(currentDate.year, currentDate.month + 1);
  }
  return DateTime(currentDate.year, currentDate.month);
}

final employeeAttendanceCurrentDateProvider = Provider<DateTime>(
  (_) => DateTime.now(),
);

({String from, String to}) buildPayrollMonthSummaryRange(
  String month,
  int payrollStartDay,
) {
  final selectedMonth = DateTime.parse('$month-01');
  final previousMonth = DateTime(
    selectedMonth.year,
    selectedMonth.month - 1,
    payrollStartDay,
  );
  final currentBoundary = DateTime(
    selectedMonth.year,
    selectedMonth.month,
    payrollStartDay - 1,
  );

  String format(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  return (from: format(previousMonth), to: format(currentBoundary));
}

// --- GPS Helper ---

Future<({double? lat, double? lng})> captureGps() async {
  if (kIsWeb) return (lat: null, lng: null);

  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return (lat: null, lng: null);
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return (lat: null, lng: null);
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return (lat: null, lng: null);
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
    return (lat: position.latitude, lng: position.longitude);
  } catch (e) {
    debugPrint('[GPS] Error: $e');
    return (lat: null, lng: null);
  }
}

// --- Attendance Provider ---

class AttendanceState {
  final Map<String, dynamic>? todayRecord;
  final bool isLoading;
  final String? errorMessage;
  final bool lastCheckoutRewarded;
  final int lastCheckoutRewardPoints;
  AttendanceState({
    this.todayRecord,
    this.isLoading = false,
    this.errorMessage,
    this.lastCheckoutRewarded = false,
    this.lastCheckoutRewardPoints = 0,
  });
}

final attendanceProvider =
    AsyncNotifierProvider<AttendanceNotifier, AttendanceState>(
      AttendanceNotifier.new,
    );

class AttendanceNotifier extends AsyncNotifier<AttendanceState> {
  @override
  Future<AttendanceState> build() async {
    try {
      final repo = ref.read(hrRepositoryProvider);
      final data = await repo.getTodayStatus();
      return AttendanceState(todayRecord: data);
    } catch (e) {
      debugPrint('[Attendance] Failed to load today status: $e');
      return AttendanceState();
    }
  }

  Future<void> checkin() async {
    state = const AsyncLoading();
    try {
      final authState = ref.read(authNotifierProvider);
      final userId = authState.valueOrNull?.user?.id ?? '';
      final dao = ref.read(hrDaoProvider);
      final repo = ref.read(hrRepositoryProvider);

      final gps = await captureGps();
      final now = DateTime.now();
      final id = _uuid.v4();

      // Save locally first (offline-first)
      await dao.insertAttendance(
        LocalAttendanceCompanion.insert(
          id: id,
          userId: userId,
          checkinAt: now,
          checkinLat: Value(gps.lat),
          checkinLng: Value(gps.lng),
        ),
      );

      // Try API
      try {
        await repo.checkin({
          'timestamp': now.toUtc().toIso8601String(),
          'lat': gps.lat,
          'lng': gps.lng,
        });
        await dao.markSynced(id);
      } on DioException catch (e) {
        if (e.response?.statusCode == 409) {
          final msg = (e.response?.data as Map?)?['message'] ?? 'Conflict';
          debugPrint('[Attendance] 409: $msg');
          final serverState = await repo.getTodayStatus();
          state = AsyncData(
            AttendanceState(todayRecord: serverState, errorMessage: msg),
          );
          return;
        }
        // Network error — keep local, will sync later
        debugPrint('[Attendance] API checkin failed, kept local: $e');
      }

      // Always reload full today status from server
      final todayStatus = await repo.getTodayStatus();
      state = AsyncData(AttendanceState(todayRecord: todayStatus));
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<AttendanceCheckoutResult> checkout() async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(hrRepositoryProvider);
      final gps = await captureGps();
      final now = DateTime.now();

      final checkoutResult = await repo.checkout({
        'timestamp': now.toUtc().toIso8601String(),
        'lat': gps.lat,
        'lng': gps.lng,
      });

      // Reload full today status from server
      final todayStatus = await repo.getTodayStatus();
      todayStatus['rewarded'] = checkoutResult.rewarded;
      todayStatus['reward_points'] = checkoutResult.rewardPoints;
      state = AsyncData(
        AttendanceState(
          todayRecord: todayStatus,
          lastCheckoutRewarded: checkoutResult.rewarded,
          lastCheckoutRewardPoints: checkoutResult.rewardPoints,
        ),
      );
      return checkoutResult;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await build());
  }
}

// --- Attendance History Provider ---

final attendanceHistoryProvider = FutureProvider.family<List<dynamic>, String>((
  ref,
  month,
) async {
  final repo = ref.read(hrRepositoryProvider);
  final config = ref.read(authNotifierProvider).valueOrNull?.payrollStartConfig;
  final startDay = config ?? 1;
  final range = buildPayrollMonthSummaryRange(month, startDay);
  return repo.getHistory(from: range.from, to: range.to);
});

class AttendanceCalendarData {
  final List<dynamic> attendanceRecords;
  final List<LeaveRequest> leaveRecords;

  const AttendanceCalendarData({
    required this.attendanceRecords,
    required this.leaveRecords,
  });
}

final attendanceCalendarProvider =
    FutureProvider.family<AttendanceCalendarData, String>((ref, month) async {
      final repo = ref.read(hrRepositoryProvider);
      final year = int.parse(month.split('-')[0]);
      final m = int.parse(month.split('-')[1]);
      final monthStart = DateTime(year, m, 1);
      final monthEndExclusive = DateTime(year, m + 1, 1);
      final from = '$year-${m.toString().padLeft(2, '0')}-01';
      final to = DateTime(year, m + 1, 0); // Last day of month
      final toStr =
          '${to.year}-${to.month.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')}';

      final attendanceRecords = await repo.getHistory(from: from, to: toStr);
      final leavesResponse = await repo.getLeaves();

      final leaveRecords = leavesResponse.leaves
          .where(
            (leave) =>
                isApprovedLeaveInMonth(leave, monthStart, monthEndExclusive),
          )
          .toList(growable: false);

      return AttendanceCalendarData(
        attendanceRecords: attendanceRecords,
        leaveRecords: leaveRecords,
      );
    });

// --- Leave List Provider ---

final leaveListProvider =
    AsyncNotifierProvider<LeaveListNotifier, LeaveListResponse>(
      LeaveListNotifier.new,
    );

class LeaveListNotifier extends AsyncNotifier<LeaveListResponse> {
  String? _statusFilter;
  String? _typeFilter;
  int _selectedMonth = 0;
  int _selectedYear = 0;
  String? _selectedEmployeeId;

  DateTime get _now => DateTime.now();

  @override
  Future<LeaveListResponse> build() async {
    if (_selectedMonth == 0) {
      final auth = await ref.watch(authNotifierProvider.future);
      final payrollMonth = resolveCurrentPayrollMonth(
        auth.payrollStartConfig ?? 1,
      );
      _selectedMonth = payrollMonth.month;
      _selectedYear = payrollMonth.year;
    }
    final repo = ref.read(hrRepositoryProvider);
    final response = await repo.getLeaves(
      status: _statusFilter,
      userId: _selectedEmployeeId,
      year: _selectedYear,
      month: _selectedMonth,
    );
    return _filterResponse(response);
  }

  void setFilter(String? status) {
    _statusFilter = status;
    ref.invalidateSelf();
  }

  void setTypeFilter(String? type) {
    if (_typeFilter == type) return;
    _typeFilter = type;
    ref.invalidateSelf();
  }

  void setSelectedEmployeeId(String? employeeId) {
    if (_selectedEmployeeId == employeeId) return;
    _selectedEmployeeId = employeeId;
    ref.invalidateSelf();
  }

  int get selectedMonth => _selectedMonth == 0 ? _now.month : _selectedMonth;
  String? get selectedEmployeeId => _selectedEmployeeId;
  int get selectedYear => _selectedYear == 0 ? _now.year : _selectedYear;
  String? get typeFilter => _typeFilter;

  void setMonth(int month) {
    if (_selectedMonth == month) return;
    _selectedMonth = month;
    ref.invalidateSelf();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await build());
  }

  LeaveListResponse _filterResponse(LeaveListResponse response) {
    final filteredLeaves = _filterLeaves(response.leaves);

    double otHours = 0;
    double leaveDays = 0;
    double wfhDays = 0;

    for (final l in filteredLeaves) {
      if (l.status == 'approved') {
        if (l.type == 'ot') {
          otHours += l.otTime ?? 0.0;
        } else if (l.type == 'wfh') {
          wfhDays += l.requestedDays ?? 0.0;
        } else if (l.type != 'wfh') {
          leaveDays += l.requestedDays ?? 0.0;
        }
      }
    }

    return LeaveListResponse(
      leaves: filteredLeaves,
      otHours: otHours,
      leaveDays: leaveDays,
      wfhDays: wfhDays,
    );
  }

  List<LeaveRequest> _filterLeaves(List<LeaveRequest> leaves) {
    return leaves
        .where((leave) {
          // Type filter
          if (_typeFilter != null) {
            if (_typeFilter == 'ot' && leave.type != 'ot') return false;
            if (_typeFilter == 'wfh' && leave.type != 'wfh') return false;
            if (_typeFilter == 'leave' &&
                (leave.type == 'ot' || leave.type == 'wfh')) {
              return false;
            }
          }

          return true;
        })
        .toList(growable: false);
  }
}

class EmployeePayrollSummaryQuery {
  const EmployeePayrollSummaryQuery({
    required this.month,
    required this.userId,
  });

  final String month;
  final String userId;

  @override
  bool operator ==(Object other) {
    return other is EmployeePayrollSummaryQuery &&
        other.month == month &&
        other.userId == userId;
  }

  @override
  int get hashCode => Object.hash(month, userId);
}

final employeePayrollSummaryProvider =
    FutureProvider.family<EmployeePayrollSummary, EmployeePayrollSummaryQuery>((
      ref,
      query,
    ) {
      return ref
          .read(hrRepositoryProvider)
          .getEmployeePayrollSummary(month: query.month, userId: query.userId);
    });

final attendanceSummaryProvider =
    FutureProvider.family<AttendanceSummary, String>((ref, month) async {
      final repo = ref.read(hrRepositoryProvider);
      Map<String, dynamic>? config;

      try {
        config = await ref.watch(payrollConfigProvider.future);
      } catch (_) {
        // Keep the overview usable when config cannot be fetched.
        config = null;
      }

      final payrollStartDay = resolvePayrollStartDay(config);
      final range = buildPayrollMonthSummaryRange(month, payrollStartDay);
      return repo.getSummary(range.from, range.to);
    });

class LeaveBalanceQuery {
  const LeaveBalanceQuery({this.year});

  final int? year;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is LeaveBalanceQuery && other.year == year);
  }

  @override
  int get hashCode => year.hashCode;
}

class UserWfhBalanceQuery {
  const UserWfhBalanceQuery({this.year, this.userId});

  final int? year;
  final String? userId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is UserWfhBalanceQuery &&
            other.year == year &&
            other.userId == userId);
  }

  @override
  int get hashCode => Object.hash(year, userId);
}

final leaveBalanceProvider =
    FutureProvider.family<LeaveBalance, LeaveBalanceQuery>((ref, query) async {
      final repo = ref.read(hrRepositoryProvider);
      return repo.getLeaveBalance(year: query.year);
    });

final wfhBalanceProvider = FutureProvider.family<WfhBalance, LeaveBalanceQuery>(
  (ref, query) async {
    final repo = ref.read(hrRepositoryProvider);
    return repo.getWfhBalance(year: query.year);
  },
);

final userWfhBalanceProvider =
    FutureProvider.family<WfhBalance, UserWfhBalanceQuery>((ref, query) async {
      final repo = ref.read(hrRepositoryProvider);
      final userId = query.userId?.trim();
      if (userId == null || userId.isEmpty) {
        return repo.getWfhBalance(year: query.year);
      }
      return repo.getAdminUserWfhBalance(userId: userId, year: query.year ?? 0);
    });

final hrOverviewLeavesProvider = FutureProvider<List<LeaveRequest>>((
  ref,
) async {
  final repo = ref.read(hrRepositoryProvider);
  final response = await repo.getLeaves();
  return response.leaves;
});

class RewardsOverviewQuery {
  const RewardsOverviewQuery({required this.limit, this.department});

  final int limit;
  final String? department;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is RewardsOverviewQuery &&
            other.limit == limit &&
            other.department == department);
  }

  @override
  int get hashCode => Object.hash(limit, department);
}

final rewardsOverviewProvider =
    FutureProvider.family<RewardsOverviewResponse, RewardsOverviewQuery>((
      ref,
      query,
    ) async {
      final repo = ref.read(hrRepositoryProvider);
      return repo.getRewardsOverview(
        limit: query.limit,
        department: query.department,
      );
    });

// Keep a distinct provider identity after the top-period API changed from a
// list to a grouped response. This also prevents stale hot-reload state from
// being cast to RewardTopPeriodResponse.
final rewardsTopPeriodGroupedProvider =
    FutureProvider.family<RewardTopPeriodResponse, String>((ref, period) async {
      final repo = ref.read(hrRepositoryProvider);
      return repo.getRewardsTopPeriod(period: period, limit: 2);
    });

final rewardAdminItemsProvider = FutureProvider<List<RewardAdminItem>>((
  ref,
) async {
  final repo = ref.read(hrRepositoryProvider);
  return repo.getAdminRewardItems();
});

final rewardAdminEmployeesProvider = FutureProvider<List<RewardAdminEmployee>>((
  ref,
) async {
  final repo = ref.read(hrRepositoryProvider);
  return repo.getAdminRewardEmployees();
});

class EmployeeOtSummaryQuery {
  const EmployeeOtSummaryQuery({required this.from, required this.to});

  final String from;
  final String to;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is EmployeeOtSummaryQuery &&
            other.from == from &&
            other.to == to);
  }

  @override
  int get hashCode => Object.hash(from, to);
}

final employeeOtSummaryProvider =
    FutureProvider.family<List<EmployeeOtSummary>, EmployeeOtSummaryQuery>((
      ref,
      query,
    ) async {
      final repo = ref.read(hrRepositoryProvider);
      return repo.getAttendanceOtSummary(from: query.from, to: query.to);
    });

final rewardAdminRedemptionsProvider =
    FutureProvider.family<List<RewardRedemption>, String?>((ref, status) async {
      final repo = ref.read(hrRepositoryProvider);
      return repo.getAdminRewardRedemptions(status: status);
    });

final rewardCatalogProvider = FutureProvider<List<RewardAdminItem>>((
  ref,
) async {
  final repo = ref.read(hrRepositoryProvider);
  return repo.getRewardCatalog();
});

final myRewardRedemptionsProvider = FutureProvider<List<RewardRedemption>>((
  ref,
) async {
  final repo = ref.read(hrRepositoryProvider);
  return repo.getMyRewardRedemptions();
});

final myRewardTransactionsProvider = FutureProvider<List<RewardTransaction>>((
  ref,
) async {
  final repo = ref.read(hrRepositoryProvider);
  return repo.getMyRewardTransactions();
});

// --- Payroll Config Provider ---

final payrollConfigProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(hrRepositoryProvider);
  return repo.getConfig();
});

final internalRolesProvider = FutureProvider<List<RewardInternalRole>>((
  ref,
) async {
  final repo = ref.read(hrRepositoryProvider);
  return repo.getInternalRoles();
});

final odooTaskTagConfigsProvider = FutureProvider<List<OdooTaskTagConfig>>((
  ref,
) async {
  final repo = ref.read(hrRepositoryProvider);
  return repo.getOdooTaskTagConfigs();
});

final jobTitlesOverviewProvider = FutureProvider<List<OdooJobTitleOverview>>((
  ref,
) async {
  final repo = ref.read(hrRepositoryProvider);
  return repo.getJobTitlesOverview();
});

final jobTitleMappingsProvider = FutureProvider<List<JobTitleMapping>>((
  ref,
) async {
  final repo = ref.read(hrRepositoryProvider);
  return repo.getJobTitleMappings();
});
