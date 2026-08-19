import 'package:dio/dio.dart';
import 'daily_report_audit_log_models.dart';
import 'daily_report_models.dart';

class DailyReportRepository {
  final Dio _dio;

  DailyReportRepository(this._dio);

  /// Fetch today's reports for the current user.
  Future<List<DailyReport>> getTodayReports() async {
    final res = await _dio.get('/daily-reports/today');
    final data = res.data;
    if (data is Map<String, dynamic>) {
      final reports = data['reports'] as List? ?? [];
      return reports
          .whereType<Map<String, dynamic>>()
          .map(DailyReport.fromJson)
          .toList();
    }
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(DailyReport.fromJson)
          .toList();
    }
    return [];
  }

  /// Submit a new daily report.
  Future<DailyReport> submitReport({
    required String reportType,
    required ReportRole reportRole,
    required List<DailyReportProject> projects,
    String? note,
  }) async {
    final body = <String, dynamic>{
      'report_type': reportType,
      'report_role': reportRole.value,
      'projects': projects.map((p) => p.toJson()).toList(),
    };
    if (note != null && note.trim().isNotEmpty) {
      body['note'] = note.trim();
    }

    final res = await _dio.post('/daily-reports', data: body);
    return DailyReport.fromJson(res.data as Map<String, dynamic>);
  }

  /// Update an existing daily report.
  Future<DailyReport> updateReport({
    required String reportId,
    required String reportType,
    required ReportRole reportRole,
    required List<DailyReportProject> projects,
    String? note,
  }) async {
    final body = <String, dynamic>{
      'report_type': reportType,
      'report_role': reportRole.value,
      'projects': projects.map((p) => p.toJson()).toList(),
    };
    if (note != null && note.trim().isNotEmpty) {
      body['note'] = note.trim();
    }

    final res = await _dio.put('/daily-reports/$reportId', data: body);
    return DailyReport.fromJson(res.data as Map<String, dynamic>);
  }

  Future<DailyReportAuditLogPage> getAuditLogs({
    DailyReportAuditLogQuery query = const DailyReportAuditLogQuery(),
  }) async {
    final res = await _dio.get(
      '/daily-reports/audit-logs',
      queryParameters: query.toQueryParameters(),
    );
    final data = res.data;

    if (data is List) {
      final items = data
          .whereType<Map<String, dynamic>>()
          .map(DailyReportAuditLog.fromJson)
          .toList(growable: false);
      return DailyReportAuditLogPage(
        items: sortDailyReportAuditLogsNewestFirst(items),
      );
    }

    if (data is Map<String, dynamic>) {
      final rawItems =
          data['items'] ??
          data['data'] ??
          data['logs'] ??
          data['results'] ??
          const [];
      final items = (rawItems as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DailyReportAuditLog.fromJson)
          .toList(growable: false);

      return DailyReportAuditLogPage(
        items: sortDailyReportAuditLogsNewestFirst(items),
        total: _asInt(data['total']),
        page: _asInt(data['page']),
        limit: _asInt(data['limit']),
        nextCursor: data['nextCursor']?.toString() ?? data['cursor']?.toString(),
      );
    }

    return const DailyReportAuditLogPage(items: []);
  }
}

int? _asInt(dynamic value) {
  return switch (value) {
    int number => number,
    String text => int.tryParse(text),
    _ => null,
  };
}
