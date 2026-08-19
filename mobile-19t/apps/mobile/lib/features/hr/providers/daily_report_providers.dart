import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_notifier.dart';
import '../data/daily_report_audit_log_sse_service.dart';
import '../data/daily_report_audit_log_models.dart';
import '../data/daily_report_models.dart';
import '../data/daily_report_repository.dart';

final dailyReportRepositoryProvider = Provider<DailyReportRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return DailyReportRepository(dio);
});

final dailyReportAuditLogSseServiceProvider =
    Provider<DailyReportAuditLogSseService>((ref) {
      return DailyReportAuditLogSseService(
        tokenStorage: ref.read(secureTokenStorageProvider),
        authRepository: ref.read(authRepositoryProvider),
      );
    });

/// Today's reports for the current user.
/// Returns a list of 0–2 reports (morning, evening).
final todayReportsProvider =
    AsyncNotifierProvider<TodayReportsNotifier, List<DailyReport>>(
  TodayReportsNotifier.new,
);

class TodayReportsNotifier extends AsyncNotifier<List<DailyReport>> {
  @override
  Future<List<DailyReport>> build() async {
    final repo = ref.read(dailyReportRepositoryProvider);
    return repo.getTodayReports();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(dailyReportRepositoryProvider).getTodayReports(),
    );
  }

  /// Submit a new report and refresh
  Future<DailyReport> submit({
    required String reportType,
    required ReportRole reportRole,
    required List<DailyReportProject> projects,
    String? note,
  }) async {
    final repo = ref.read(dailyReportRepositoryProvider);
    final report = await repo.submitReport(
      reportType: reportType,
      reportRole: reportRole,
      projects: projects,
      note: note,
    );
    await refresh();
    return report;
  }

  /// Update an existing report and refresh
  Future<DailyReport> updateReport({
    required String reportId,
    required String reportType,
    required ReportRole reportRole,
    required List<DailyReportProject> projects,
    String? note,
  }) async {
    final repo = ref.read(dailyReportRepositoryProvider);
    final report = await repo.updateReport(
      reportId: reportId,
      reportType: reportType,
      reportRole: reportRole,
      projects: projects,
      note: note,
    );
    await refresh();
    return report;
  }
}

final dailyReportAuditLogsProvider =
    AsyncNotifierProvider<
      DailyReportAuditLogsNotifier,
      DailyReportAuditLogPage
    >(DailyReportAuditLogsNotifier.new);

class DailyReportAuditLogsNotifier extends AsyncNotifier<DailyReportAuditLogPage> {
  DailyReportAuditLogQuery _currentQuery = const DailyReportAuditLogQuery();

  @override
  Future<DailyReportAuditLogPage> build() async {
    return ref
        .read(dailyReportRepositoryProvider)
        .getAuditLogs(query: _currentQuery);
  }

  DailyReportAuditLogQuery get currentQuery => _currentQuery;

  Future<void> refresh([DailyReportAuditLogQuery? query]) async {
    if (query != null) {
      _currentQuery = query;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(dailyReportRepositoryProvider)
          .getAuditLogs(query: _currentQuery),
    );
  }
}

/// Helper: whether user has submitted a morning report today
DailyReport? todayMorningReport(List<DailyReport> reports) {
  try {
    return reports.firstWhere((r) => r.isMorning);
  } catch (_) {
    return null;
  }
}

/// Helper: whether user has submitted an evening report today
DailyReport? todayEveningReport(List<DailyReport> reports) {
  try {
    return reports.firstWhere((r) => r.isEvening);
  } catch (_) {
    return null;
  }
}

/// Helper: whether user has submitted an OT report today
DailyReport? todayOtReport(List<DailyReport> reports) {
  try {
    return reports.firstWhere((r) => r.isOt);
  } catch (_) {
    return null;
  }
}
