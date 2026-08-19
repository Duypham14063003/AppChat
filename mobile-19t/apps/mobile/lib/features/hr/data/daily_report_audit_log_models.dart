import 'dart:convert';

enum DailyReportAuditLogFilter {
  all,
  submitted,
  advanced,
  skipped,
  failed;

  String get label => switch (this) {
    DailyReportAuditLogFilter.all => 'Tất cả',
    DailyReportAuditLogFilter.submitted => 'Submitted',
    DailyReportAuditLogFilter.advanced => 'Advanced',
    DailyReportAuditLogFilter.skipped => 'Skipped',
    DailyReportAuditLogFilter.failed => 'Failed',
  };

  String? get eventType => switch (this) {
    DailyReportAuditLogFilter.all => null,
    DailyReportAuditLogFilter.submitted => 'daily_report.submitted',
    DailyReportAuditLogFilter.advanced => 'daily_report.stage_sync.advanced',
    DailyReportAuditLogFilter.skipped => 'daily_report.stage_sync.skipped',
    DailyReportAuditLogFilter.failed => 'daily_report.stage_sync.failed',
  };
}

class DailyReportAuditLogPage {
  const DailyReportAuditLogPage({
    required this.items,
    this.total,
    this.page,
    this.limit,
    this.nextCursor,
  });

  final List<DailyReportAuditLog> items;
  final int? total;
  final int? page;
  final int? limit;
  final String? nextCursor;
}

class DailyReportAuditLogQuery {
  const DailyReportAuditLogQuery({
    this.eventType,
    this.status,
    this.reportId,
    this.taskId,
    this.userId,
    this.limit = 20,
  });

  final String? eventType;
  final String? status;
  final String? reportId;
  final String? taskId;
  final String? userId;
  final int limit;

  DailyReportAuditLogQuery copyWith({
    String? eventType,
    String? status,
    String? reportId,
    String? taskId,
    String? userId,
    int? limit,
    bool clearEventType = false,
    bool clearStatus = false,
    bool clearReportId = false,
    bool clearTaskId = false,
    bool clearUserId = false,
  }) {
    return DailyReportAuditLogQuery(
      eventType: clearEventType ? null : (eventType ?? this.eventType),
      status: clearStatus ? null : (status ?? this.status),
      reportId: clearReportId ? null : (reportId ?? this.reportId),
      taskId: clearTaskId ? null : (taskId ?? this.taskId),
      userId: clearUserId ? null : (userId ?? this.userId),
      limit: limit ?? this.limit,
    );
  }

  Map<String, dynamic> toQueryParameters() {
    return <String, dynamic>{
      if (_hasText(eventType)) 'event_type': eventType,
      if (_hasText(status)) 'status': status,
      if (_hasText(reportId)) 'report_id': reportId,
      if (_hasText(taskId)) 'task_id': taskId,
      if (_hasText(userId)) 'user_id': userId,
      'limit': limit.clamp(1, 100),
    };
  }
}

class DailyReportAuditLog {
  const DailyReportAuditLog({
    required this.id,
    required this.category,
    required this.eventType,
    required this.userId,
    required this.entityType,
    required this.entityId,
    required this.status,
    required this.reason,
    required this.metadata,
    required this.createdAt,
    required this.raw,
  });

  factory DailyReportAuditLog.fromJson(Map<String, dynamic> json) {
    final metadata = _asMetadataMap(json['metadata']);
    return DailyReportAuditLog(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      eventType: json['event_type']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      entityType: json['entity_type']?.toString() ?? '',
      entityId: json['entity_id']?.toString() ?? '',
      status: json['status']?.toString(),
      reason: json['reason']?.toString(),
      metadata: metadata,
      createdAt: _parseDateTime(json['created_at']),
      raw: Map<String, dynamic>.from(json),
    );
  }

  final String id;
  final String category;
  final String eventType;
  final String userId;
  final String entityType;
  final String entityId;
  final String? status;
  final String? reason;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
  final Map<String, dynamic> raw;

  String? get metadataError => metadata['error']?.toString();
  String? get taskName => metadata['taskName']?.toString();
  String? get taskId => metadata['taskId']?.toString();
  String? get projectId => metadata['projectId']?.toString();
  String? get projectName => metadata['projectName']?.toString();
  String? get reportType => metadata['reportType']?.toString();
  String? get fromStageId => metadata['fromStageId']?.toString();
  String? get toStageId => metadata['toStageId']?.toString();
  String? get toStageName => metadata['toStageName']?.toString();
  String? get expectedStageId => metadata['expectedStageId']?.toString();
  String? get liveStageId => metadata['liveStageId']?.toString();

  bool get hasStageInfo =>
      fromStageId != null ||
      toStageId != null ||
      toStageName != null ||
      expectedStageId != null ||
      liveStageId != null;

  bool matchesFilter(DailyReportAuditLogFilter filter) {
    final expected = filter.eventType;
    return expected == null || eventType == expected;
  }

  bool matchesSearch(String keyword) {
    final normalized = keyword.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return entityId.toLowerCase().contains(normalized) ||
        (taskName?.toLowerCase().contains(normalized) ?? false) ||
        (taskId?.toLowerCase().contains(normalized) ?? false);
  }
}

Map<String, dynamic> _asMetadataMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }
  if (value is Map) {
    return value.map(
      (key, entry) => MapEntry(key.toString(), entry),
    );
  }
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map(
          (key, entry) => MapEntry(key.toString(), entry),
        );
      }
    } catch (_) {
      return {'raw': value};
    }
  }
  return const {};
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

List<DailyReportAuditLog> sortDailyReportAuditLogsNewestFirst(
  List<DailyReportAuditLog> items,
) {
  final sorted = [...items];
  sorted.sort((a, b) {
    final aTime = a.createdAt;
    final bTime = b.createdAt;
    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    return bTime.compareTo(aTime);
  });
  return List<DailyReportAuditLog>.unmodifiable(sorted);
}

List<DailyReportAuditLog> mergeDailyReportAuditLogs(
  List<DailyReportAuditLog> current,
  List<DailyReportAuditLog> incoming,
) {
  final merged = <String, DailyReportAuditLog>{};
  for (final item in [...incoming, ...current]) {
    merged[item.id] = item;
  }
  return sortDailyReportAuditLogsNewestFirst(merged.values.toList(growable: false));
}
