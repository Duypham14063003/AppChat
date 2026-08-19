import '../../task/models/task_models.dart';

/// Role type for daily reports — determines which fields are shown.
enum ReportRole {
  dev('dev'),
  qc('qc');

  const ReportRole(this.value);
  final String value;

  static ReportRole fromString(String? value) {
    if (value == 'qc') return ReportRole.qc;
    return ReportRole.dev;
  }

  String get label => this == ReportRole.dev ? 'Developer' : 'QC';
}

/// A single daily report (morning or evening).
class DailyReport {
  final String id;
  final String reportType; // 'morning' | 'evening'
  final String reportDate;
  final ReportRole reportRole;
  final List<DailyReportProject> projects;
  final String? note;
  final String? chatMessageId;
  final DateTime? createdAt;

  const DailyReport({
    required this.id,
    required this.reportType,
    required this.reportDate,
    this.reportRole = ReportRole.dev,
    required this.projects,
    this.note,
    this.chatMessageId,
    this.createdAt,
  });

  factory DailyReport.fromJson(Map<String, dynamic> json) {
    final projectsRaw = json['projects'] as List? ?? [];
    return DailyReport(
      id: json['id']?.toString() ?? '',
      reportType: json['report_type']?.toString() ?? 'morning',
      reportDate: json['report_date']?.toString() ?? '',
      reportRole: ReportRole.fromString(json['report_role']?.toString()),
      projects: projectsRaw
          .whereType<Map<String, dynamic>>()
          .map(DailyReportProject.fromJson)
          .toList(),
      note: json['note']?.toString(),
      chatMessageId: json['chat_message_id']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  bool get isMorning => reportType == 'morning';
  bool get isEvening => reportType == 'evening';
  bool get isOt => reportType == 'ot';
  bool get isQc => reportRole == ReportRole.qc;
}

/// A project entry within a daily report, containing its selected tasks.
class DailyReportProject {
  final int projectId;
  final String projectName;
  final List<DailyReportTask> tasks;

  const DailyReportProject({
    required this.projectId,
    required this.projectName,
    required this.tasks,
  });

  factory DailyReportProject.fromJson(Map<String, dynamic> json) {
    final tasksRaw = json['tasks'] as List? ?? [];
    return DailyReportProject(
      projectId: json['project_id'] as int? ?? 0,
      projectName: json['project_name']?.toString() ?? '',
      tasks: tasksRaw
          .whereType<Map<String, dynamic>>()
          .map(DailyReportTask.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'project_id': projectId,
    'project_name': projectName,
    'tasks': tasks.map((t) => t.toJson()).toList(),
  };
}

/// A task entry within a daily report project.
///
/// **Dev evening fields:** [status] ('done'/'doing') + [progress] (10-90%).
/// **QC evening fields:** [qcDone], [qcMiss], [qcFail] counts.
class DailyReportTask {
  final Task task;
  // Dev fields
  final String? status;   // null | 'done' | 'doing'
  final int? progress;    // null | 10-90
  // QC fields
  final int? qcDone;
  final int? qcMiss;
  final int? qcFail;
  final String? qcNote;

  const DailyReportTask({
    required this.task,
    this.status,
    this.progress,
    this.qcDone,
    this.qcMiss,
    this.qcFail,
    this.qcNote,
  });

  factory DailyReportTask.fromJson(Map<String, dynamic> json) {
    return DailyReportTask(
      task: Task.fromJson(json),
      status: json['status']?.toString(),
      progress: json['progress'] as int?,
      qcDone: json['qc_done'] as int?,
      qcMiss: json['qc_miss'] as int?,
      qcFail: json['qc_fail'] as int?,
      qcNote: json['qc_note']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    final raw = task.toRawJson();
    if (status != null) {
      raw['status'] = status;
      raw['progress'] = progress;
    }
    if (qcDone != null) raw['qc_done'] = qcDone;
    if (qcMiss != null) raw['qc_miss'] = qcMiss;
    if (qcFail != null) raw['qc_fail'] = qcFail;
    if (qcNote != null) raw['qc_note'] = qcNote;
    return raw;
  }

  DailyReportTask copyWith({
    String? status,
    int? progress,
    int? qcDone,
    int? qcMiss,
    int? qcFail,
    String? qcNote,
  }) {
    return DailyReportTask(
      task: task,
      status: status ?? this.status,
      progress: progress,
      qcDone: qcDone ?? this.qcDone,
      qcMiss: qcMiss ?? this.qcMiss,
      qcFail: qcFail ?? this.qcFail,
      qcNote: qcNote ?? this.qcNote,
    );
  }

  bool get isDone => status == 'done';
  bool get isDoing => status == 'doing';
}
