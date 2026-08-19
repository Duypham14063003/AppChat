class PocUser {
  const PocUser({
    required this.id,
    required this.name,
    this.email,
    this.avatarUrl,
    this.department,
    this.jobTitle,
  });

  factory PocUser.fromJson(Map<String, dynamic> json) => PocUser(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Unknown',
    email: json['email']?.toString(),
    avatarUrl: (json['avatar_url'] ?? json['avatarUrl'])?.toString(),
    department: json['department']?.toString(),
    jobTitle: (json['job_title'] ?? json['jobTitle'])?.toString(),
  );

  final String id;
  final String name;
  final String? email;
  final String? avatarUrl;
  final String? department;
  final String? jobTitle;
}

class PocHistoryEvent {
  const PocHistoryEvent({
    required this.id,
    required this.eventType,
    required this.createdAt,
    this.actorUserId,
    this.actorName,
    this.previousValues,
    this.newValues,
  });

  factory PocHistoryEvent.fromJson(Map<String, dynamic> json) =>
      PocHistoryEvent(
        id: json['id']?.toString() ?? '',
        eventType: json['event_type']?.toString() ?? 'updated',
        createdAt: _date(json['created_at']) ?? DateTime.now(),
        actorUserId: json['actor_user_id']?.toString(),
        actorName: json['actor_name']?.toString(),
        previousValues: _map(json['previous_values']),
        newValues: _map(json['new_values']),
      );

  final String id;
  final String eventType;
  final DateTime createdAt;
  final String? actorUserId;
  final String? actorName;
  final Map<String, dynamic>? previousValues;
  final Map<String, dynamic>? newValues;
}

class PocRecord {
  const PocRecord({
    required this.id,
    required this.customerName,
    required this.title,
    required this.requirement,
    required this.productType,
    required this.priority,
    required this.saleUserId,
    required this.demoAt,
    required this.status,
    required this.version,
    required this.referenceLinks,
    required this.history,
    this.code,
    this.developerUserId,
    this.assignedByUserId,
    this.workingConversationId,
    this.sourceMessageId,
    this.plannedStartAt,
    this.estimatedHours,
    this.outcome,
    this.pocUrl,
    this.cancelReason,
    this.readyAt,
    this.demonstratedAt,
    this.saleUser,
    this.developerUser,
    this.assignedByUser,
    this.overdue = false,
    this.demoSoon = false,
  });

  factory PocRecord.fromJson(Map<String, dynamic> json) => PocRecord(
    id: json['id']?.toString() ?? '',
    code: json['code']?.toString(),
    customerName: json['customer_name']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    requirement: json['requirement']?.toString() ?? '',
    productType: json['product_type']?.toString() ?? 'validation',
    priority: json['priority']?.toString() ?? 'normal',
    saleUserId: json['sale_user_id']?.toString() ?? '',
    developerUserId: json['developer_user_id']?.toString(),
    assignedByUserId: json['assigned_by_user_id']?.toString(),
    workingConversationId: json['working_conversation_id']?.toString(),
    sourceMessageId: json['source_message_id']?.toString(),
    plannedStartAt: _date(json['planned_start_at']),
    estimatedHours: _number(json['estimated_hours']),
    demoAt: _date(json['demo_at']) ?? DateTime.now(),
    status: json['status']?.toString() ?? 'unassigned',
    outcome: json['outcome']?.toString(),
    pocUrl: json['poc_url']?.toString(),
    referenceLinks: _strings(json['reference_links']),
    cancelReason: json['cancel_reason']?.toString(),
    readyAt: _date(json['ready_at']),
    demonstratedAt: _date(json['demonstrated_at']),
    version: (json['version'] as num?)?.toInt() ?? 1,
    saleUser: _user(json['sale_user']),
    developerUser: _user(json['developer_user']),
    assignedByUser: _user(json['assigned_by_user']),
    overdue: json['overdue'] == true,
    demoSoon: json['demo_soon'] == true,
    history: ((json['history'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => PocHistoryEvent.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false),
  );

  final String id;
  final String? code;
  final String customerName;
  final String title;
  final String requirement;
  final String productType;
  final String priority;
  final String saleUserId;
  final String? developerUserId;
  final String? assignedByUserId;
  final String? workingConversationId;
  final String? sourceMessageId;
  final DateTime? plannedStartAt;
  final double? estimatedHours;
  final DateTime demoAt;
  final String status;
  final String? outcome;
  final String? pocUrl;
  final List<String> referenceLinks;
  final String? cancelReason;
  final DateTime? readyAt;
  final DateTime? demonstratedAt;
  final int version;
  final PocUser? saleUser;
  final PocUser? developerUser;
  final PocUser? assignedByUser;
  final bool overdue;
  final bool demoSoon;
  final List<PocHistoryEvent> history;
}

class PocPage {
  const PocPage({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  factory PocPage.fromJson(Map<String, dynamic> json) => PocPage(
    items: ((json['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => PocRecord.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false),
    total: (json['total'] as num?)?.toInt() ?? 0,
    page: (json['page'] as num?)?.toInt() ?? 1,
    limit: (json['limit'] as num?)?.toInt() ?? 20,
  );

  final List<PocRecord> items;
  final int total;
  final int page;
  final int limit;
}

class PocConflict implements Exception {
  const PocConflict(this.latest, [this.message = 'PoC vừa được cập nhật']);
  final PocRecord? latest;
  final String message;
  @override
  String toString() => message;
}

class PocCapacityDeveloper {
  const PocCapacityDeveloper({
    required this.userId,
    required this.name,
    required this.allocatedHours,
    required this.capacityHours,
    required this.remainingHours,
    required this.excessHours,
    required this.overCapacity,
    required this.hasOverlap,
    required this.dailyLoad,
    required this.pocs,
    this.avatarUrl,
    this.department,
    this.jobTitle,
    this.projectedHours,
  });

  factory PocCapacityDeveloper.fromJson(Map<String, dynamic> json) =>
      PocCapacityDeveloper(
        userId: json['user_id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Unknown',
        avatarUrl: json['avatar_url']?.toString(),
        department: json['department']?.toString(),
        jobTitle: json['job_title']?.toString(),
        allocatedHours: _number(json['allocated_hours']) ?? 0,
        capacityHours: _number(json['capacity_hours']) ?? 40,
        remainingHours: _number(json['remaining_hours']) ?? 0,
        excessHours: _number(json['excess_hours']) ?? 0,
        projectedHours: _number(json['projected_hours']),
        overCapacity:
            json['over_capacity'] == true ||
            json['projected_over_capacity'] == true,
        hasOverlap:
            json['has_overlap'] == true ||
            json['projected_has_overlap'] == true,
        dailyLoad: _numberMap(json['daily_load']),
        pocs: ((json['pocs'] as List?) ?? const [])
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList(growable: false),
      );

  final String userId;
  final String name;
  final String? avatarUrl;
  final String? department;
  final String? jobTitle;
  final double allocatedHours;
  final double capacityHours;
  final double remainingHours;
  final double excessHours;
  final double? projectedHours;
  final bool overCapacity;
  final bool hasOverlap;
  final Map<String, double> dailyLoad;
  final List<Map<String, dynamic>> pocs;
}

class PocCapacityWeek {
  const PocCapacityWeek({
    required this.isoYear,
    required this.isoWeek,
    required this.dates,
    required this.developers,
  });
  factory PocCapacityWeek.fromJson(Map<String, dynamic> json) =>
      PocCapacityWeek(
        isoYear: (json['iso_year'] as num?)?.toInt() ?? 0,
        isoWeek: (json['iso_week'] as num?)?.toInt() ?? 0,
        dates: _strings(json['dates']),
        developers: ((json['developers'] as List?) ?? const [])
            .whereType<Map>()
            .map(
              (item) =>
                  PocCapacityDeveloper.fromJson(item.cast<String, dynamic>()),
            )
            .toList(growable: false),
      );
  final int isoYear;
  final int isoWeek;
  final List<String> dates;
  final List<PocCapacityDeveloper> developers;
}

class PocWeeklyReport {
  const PocWeeklyReport({
    required this.isoYear,
    required this.isoWeek,
    required this.weekStart,
    required this.weekEnd,
    required this.total,
    required this.counts,
    required this.demos,
    required this.overdue,
    required this.capacity,
  });
  factory PocWeeklyReport.fromJson(Map<String, dynamic> json) =>
      PocWeeklyReport(
        isoYear: (json['iso_year'] as num?)?.toInt() ?? 0,
        isoWeek: (json['iso_week'] as num?)?.toInt() ?? 0,
        weekStart: json['week_start']?.toString() ?? '',
        weekEnd: json['week_end']?.toString() ?? '',
        total: (json['total'] as num?)?.toInt() ?? 0,
        counts: ((json['counts'] as Map?) ?? const {}).map(
          (key, value) =>
              MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
        ),
        demos: _maps(json['demos']),
        overdue: _maps(json['overdue']),
        capacity: _maps(json['capacity']),
      );
  final int isoYear;
  final int isoWeek;
  final String weekStart;
  final String weekEnd;
  final int total;
  final Map<String, int> counts;
  final List<Map<String, dynamic>> demos;
  final List<Map<String, dynamic>> overdue;
  final List<Map<String, dynamic>> capacity;
}

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();
double? _number(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
List<String> _strings(dynamic value) =>
    ((value as List?) ?? const []).map((item) => item.toString()).toList();
Map<String, dynamic>? _map(dynamic value) =>
    value is Map ? value.cast<String, dynamic>() : null;
PocUser? _user(dynamic value) =>
    value is Map ? PocUser.fromJson(value.cast<String, dynamic>()) : null;
List<Map<String, dynamic>> _maps(dynamic value) =>
    ((value as List?) ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList(growable: false);
Map<String, double> _numberMap(dynamic value) => ((value as Map?) ?? const {})
    .map((key, item) => MapEntry(key.toString(), _number(item) ?? 0));
