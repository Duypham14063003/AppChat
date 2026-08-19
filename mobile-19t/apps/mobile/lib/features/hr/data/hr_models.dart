import 'dart:typed_data';

import '../../../core/config/app_config.dart';

class LeaveRequest {
  const LeaveRequest({
    required this.id,
    this.userId = '',
    required this.type,
    required this.startDate,
    required this.endDate,
    this.reason,
    required this.isHalfDay,
    this.halfDayPart,
    this.requestedDays,
    this.paidDays,
    this.unpaidDays,
    this.status,
    this.approvedAt,
    this.rejectReason,
    this.startTime,
    this.endTime,
    this.otTime,
    this.userName,
    this.approverName,
    this.cancelledAt,
    this.cancelReason,
    this.cancellerName,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'annual',
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      reason: json['reason']?.toString(),
      isHalfDay: json['is_half_day'] == true,
      halfDayPart: json['half_day_part']?.toString(),
      requestedDays: _asDouble(json['requested_days']),
      paidDays: _asDouble(json['paid_days']),
      unpaidDays: _asDouble(json['unpaid_days']),
      status: json['status']?.toString(),
      approvedAt: _parseDateTime(json['approved_at']),
      rejectReason: json['reject_reason']?.toString(),
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
      otTime: _asDouble(json['ot_time']),
      userName:
          json['user_name']?.toString() ??
          (json['requester'] as Map<String, dynamic>?)?['name']?.toString(),
      approverName:
          json['approved_by_name']?.toString() ??
          (json['approver'] as Map<String, dynamic>?)?['name']?.toString(),
      cancelledAt: _parseDateTime(json['cancelled_at']),
      cancelReason: json['cancel_reason']?.toString(),
      cancellerName:
          json['cancelled_by_name']?.toString() ??
          (json['canceller'] as Map<String, dynamic>?)?['name']?.toString(),
    );
  }

  final String id;
  final String userId;
  final String type;
  final String startDate;
  final String endDate;
  final String? reason;
  final bool isHalfDay;
  final String? halfDayPart;
  final double? requestedDays;
  final double? paidDays;
  final double? unpaidDays;
  final String? status;
  final DateTime? approvedAt;
  final String? rejectReason;
  final String? startTime;
  final String? endTime;
  final double? otTime;
  final String? userName;
  final String? approverName;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final String? cancellerName;
}

class LeaveListResponse {
  const LeaveListResponse({
    required this.leaves,
    required this.otHours,
    required this.leaveDays,
    required this.wfhDays,
  });

  factory LeaveListResponse.fromJson(Map<String, dynamic> json) {
    final leavesRaw = json['leaves'] as List<dynamic>? ?? const [];
    return LeaveListResponse(
      leaves: leavesRaw
          .whereType<Map<String, dynamic>>()
          .map(LeaveRequest.fromJson)
          .toList(growable: false),
      otHours: _asDouble(json['otHours']) ?? 0,
      leaveDays: _asDouble(json['leaveDays']) ?? 0,
      wfhDays: _asDouble(json['wfhDays']) ?? 0,
    );
  }

  final List<LeaveRequest> leaves;
  final double otHours;
  final double leaveDays;
  final double wfhDays;
}

class PayrollWorkbookDownload {
  const PayrollWorkbookDownload({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;
}

enum AttendanceDataStatus { available, unmapped, unavailable }

class EmployeePayrollSummary {
  const EmployeePayrollSummary({
    required this.userId,
    required this.month,
    required this.cycleFrom,
    required this.cycleToExclusive,
    required this.attendanceStatus,
    this.actualWorkingDays,
    this.attendanceSessions = const [],
    this.leaveOrders = const [],
  });

  factory EmployeePayrollSummary.fromJson(Map<String, dynamic> json) {
    final status = switch (json['attendance_status']?.toString()) {
      'available' => AttendanceDataStatus.available,
      'unmapped' => AttendanceDataStatus.unmapped,
      _ => AttendanceDataStatus.unavailable,
    };
    return EmployeePayrollSummary(
      userId: json['user_id']?.toString() ?? '',
      month: json['month']?.toString() ?? '',
      cycleFrom: json['cycle_from']?.toString() ?? '',
      cycleToExclusive: json['cycle_to_exclusive']?.toString() ?? '',
      attendanceStatus: status,
      actualWorkingDays: _asDouble(json['actual_working_days']),
      attendanceSessions:
          (json['attendance_sessions'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(EmployeePayrollAttendanceSession.fromJson)
              .toList(growable: false),
      leaveOrders: (json['leave_orders'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LeaveRequest.fromJson)
          .toList(growable: false),
    );
  }

  final String userId;
  final String month;
  final String cycleFrom;
  final String cycleToExclusive;
  final AttendanceDataStatus attendanceStatus;
  final double? actualWorkingDays;
  final List<EmployeePayrollAttendanceSession> attendanceSessions;
  final List<LeaveRequest> leaveOrders;
}

class EmployeePayrollAttendanceSession {
  const EmployeePayrollAttendanceSession({
    required this.id,
    required this.date,
    required this.checkIn,
    required this.checkOut,
    required this.workedHours,
    required this.counted,
    required this.dayValue,
    required this.exclusionReason,
  });

  factory EmployeePayrollAttendanceSession.fromJson(Map<String, dynamic> json) {
    return EmployeePayrollAttendanceSession(
      id: _asInt(json['id']) ?? 0,
      date: json['date']?.toString() ?? '',
      checkIn: _parseDateTime(json['check_in']),
      checkOut: _parseDateTime(json['check_out']),
      workedHours: _asDouble(json['worked_hours']),
      counted: json['counted'] == true,
      dayValue: _asDouble(json['day_value']),
      exclusionReason: json['exclusion_reason']?.toString(),
    );
  }

  final int id;
  final String date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final double? workedHours;
  final bool counted;
  final double? dayValue;
  final String? exclusionReason;
}

class AttendanceSummary {
  const AttendanceSummary({
    required this.totalDays,
    required this.totalHours,
    required this.totalOt,
    required this.daysLate,
    required this.paidLeaveDays,
    required this.unpaidLeaveDays,
    required this.absentWithoutLeaveDays,
    required this.daysAbsent,
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    return AttendanceSummary(
      totalDays: _asDouble(json['total_days']) ?? 0,
      totalHours: _asDouble(json['total_hours']) ?? 0,
      totalOt: _asDouble(json['total_ot']) ?? 0,
      daysLate: _asDouble(json['days_late']) ?? 0,
      paidLeaveDays: _asDouble(json['paid_leave_days']) ?? 0,
      unpaidLeaveDays: _asDouble(json['unpaid_leave_days']) ?? 0,
      absentWithoutLeaveDays: _asDouble(json['absent_without_leave_days']) ?? 0,
      daysAbsent: _asDouble(json['days_absent']) ?? 0,
    );
  }

  final double totalDays;
  final double totalHours;
  final double totalOt;
  final double daysLate;
  final double paidLeaveDays;
  final double unpaidLeaveDays;
  final double absentWithoutLeaveDays;
  final double daysAbsent;
}

class AttendanceCheckoutResult {
  const AttendanceCheckoutResult({
    required this.id,
    required this.userId,
    this.checkinAt,
    this.checkoutAt,
    required this.totalHours,
    required this.otHours,
    required this.rewarded,
    required this.rewardPoints,
    this.raw,
  });

  factory AttendanceCheckoutResult.fromJson(Map<String, dynamic> json) {
    return AttendanceCheckoutResult(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      checkinAt: _parseDateTime(json['checkin_at']),
      checkoutAt: _parseDateTime(json['checkout_at']),
      totalHours: _asDouble(json['total_hours']) ?? 0,
      otHours: _asDouble(json['ot_hours']) ?? 0,
      rewarded: json['rewarded'] == true,
      rewardPoints: (json['reward_points'] as num?)?.toInt() ?? 0,
      raw: json,
    );
  }

  final String id;
  final String userId;
  final DateTime? checkinAt;
  final DateTime? checkoutAt;
  final double totalHours;
  final double otHours;
  final bool rewarded;
  final int rewardPoints;
  final Map<String, dynamic>? raw;
}

class LeaveBalance {
  const LeaveBalance({
    required this.year,
    this.employmentStatus,
    required this.isPaidLeaveEligible,
    required this.allocatedDays,
    required this.usedPaidDays,
    required this.remainingPaidDays,
    required this.hasRemainingPaidLeave,
  });

  factory LeaveBalance.fromJson(Map<String, dynamic> json) {
    return LeaveBalance(
      year: (json['year'] as num?)?.toInt() ?? 0,
      employmentStatus: json['employment_status']?.toString(),
      isPaidLeaveEligible: json['is_paid_leave_eligible'] == true,
      allocatedDays: _asDouble(json['allocated_days']) ?? 0,
      usedPaidDays: _asDouble(json['used_paid_days']) ?? 0,
      remainingPaidDays: _asDouble(json['remaining_paid_days']) ?? 0,
      hasRemainingPaidLeave: json['has_remaining_paid_leave'] == true,
    );
  }

  final int year;
  final String? employmentStatus;
  final bool isPaidLeaveEligible;
  final double allocatedDays;
  final double usedPaidDays;
  final double remainingPaidDays;
  final bool hasRemainingPaidLeave;
}

class WfhBalance {
  const WfhBalance({
    required this.year,
    required this.allocatedDays,
    required this.usedDays,
    required this.remainingDays,
    required this.hasRemainingDays,
    required this.isOverride,
  });

  factory WfhBalance.fromJson(Map<String, dynamic> json) {
    return WfhBalance(
      year: (json['year'] as num?)?.toInt() ?? 0,
      allocatedDays: _asDouble(json['allocated_days']) ?? 0,
      usedDays: _asDouble(json['used_days']) ?? 0,
      remainingDays: _asDouble(json['remaining_days']) ?? 0,
      hasRemainingDays: json['has_remaining_days'] == true,
      isOverride: json['is_override'] == true,
    );
  }

  final int year;
  final double allocatedDays;
  final double usedDays;
  final double remainingDays;
  final bool hasRemainingDays;
  final bool isOverride;
}

class WfhAdminConfig {
  const WfhAdminConfig({required this.year, required this.allocatedDays});

  factory WfhAdminConfig.fromJson(Map<String, dynamic> json) {
    return WfhAdminConfig(
      year: (json['year'] as num?)?.toInt() ?? 0,
      allocatedDays: _asDouble(json['allocated_days']) ?? 0,
    );
  }

  final int year;
  final double allocatedDays;
}

class RewardLeaderboardEntry {
  const RewardLeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.rankingPoints,
    required this.balance,
    required this.lifetimeEarned,
    required this.lifetimeSpent,
    required this.updatedAt,
  });

  factory RewardLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return RewardLeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      userId: json['user_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Nhân viên',
      email: json['email']?.toString() ?? '',
      avatarUrl: _resolveAvatarUrl(json['avatar_url']?.toString()),
      rankingPoints:
          (json['ranking_points'] as num?)?.toInt() ??
          ((json['lifetime_earned'] as num?)?.toInt() ?? 0) -
              ((json['lifetime_spent'] as num?)?.toInt() ?? 0),
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      lifetimeEarned: (json['lifetime_earned'] as num?)?.toInt() ?? 0,
      lifetimeSpent: (json['lifetime_spent'] as num?)?.toInt() ?? 0,
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  final int rank;
  final String userId;
  final String name;
  final String email;
  final String? avatarUrl;
  final int rankingPoints;
  final int balance;
  final int lifetimeEarned;
  final int lifetimeSpent;
  final DateTime? updatedAt;
}

class RewardTopPeriodEntry {
  const RewardTopPeriodEntry({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.pointsEarned,
    required this.period,
  });

  factory RewardTopPeriodEntry.fromJson(Map<String, dynamic> json) {
    return RewardTopPeriodEntry(
      userId: json['user_id']?.toString() ?? '',
      name: json['name']?.toString(),
      avatarUrl: _resolveAvatarUrl(json['avatar_url']?.toString()),
      pointsEarned: (json['points_earned'] as num?)?.toInt() ?? 0,
      period: json['period']?.toString() ?? '',
    );
  }

  final String userId;
  final String? name;
  final String? avatarUrl;
  final int pointsEarned;
  final String period;

  String get displayName {
    if (name == null || name!.trim().isEmpty) return 'Nhân viên';
    return name!.trim();
  }
}

class RewardTopPeriodResponse {
  const RewardTopPeriodResponse({required this.tech, required this.other});

  factory RewardTopPeriodResponse.fromJson(Map<String, dynamic> json) {
    List<RewardTopPeriodEntry> parseGroup(Object? raw) {
      return (raw as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RewardTopPeriodEntry.fromJson)
          .take(2)
          .toList(growable: false);
    }

    return RewardTopPeriodResponse(
      tech: parseGroup(json['tech']),
      other: parseGroup(json['other']),
    );
  }

  final List<RewardTopPeriodEntry> tech;
  final List<RewardTopPeriodEntry> other;

  bool get isEmpty => tech.isEmpty && other.isEmpty;
}

class RewardsOverviewResponse {
  const RewardsOverviewResponse({
    required this.leaderboard,
    required this.pendingLeaveRequests,
  });

  factory RewardsOverviewResponse.fromJson(Map<String, dynamic> json) {
    final leaderboardRaw = json['leaderboard'] as List<dynamic>? ?? const [];
    final pendingRaw =
        json['pending_leave_requests'] as List<dynamic>? ?? const [];

    return RewardsOverviewResponse(
      leaderboard: leaderboardRaw
          .whereType<Map<String, dynamic>>()
          .map(RewardLeaderboardEntry.fromJson)
          .toList(growable: false),
      pendingLeaveRequests: pendingRaw
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => LeaveRequest.fromJson({...item, 'status': 'submitted'}),
          )
          .toList(growable: false),
    );
  }

  final List<RewardLeaderboardEntry> leaderboard;
  final List<LeaveRequest> pendingLeaveRequests;
}

class RewardAdminItem {
  const RewardAdminItem({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.pointsCost,
    required this.stockTotal,
    required this.stockRemaining,
    required this.isActive,
    required this.sortOrder,
    required this.category,
  });

  factory RewardAdminItem.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'];
    final metadataMap = metadata is Map<String, dynamic>
        ? metadata
        : <String, dynamic>{};

    return RewardAdminItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Vật phẩm',
      description: json['description']?.toString() ?? '',
      imageUrl: _resolveAvatarUrl(json['image_url']?.toString()),
      pointsCost: (json['points_cost'] as num?)?.toInt() ?? 0,
      stockTotal: (json['stock_total'] as num?)?.toInt() ?? 0,
      stockRemaining:
          (json['stock_remaining'] as num?)?.toInt() ??
          (json['stock_total'] as num?)?.toInt() ??
          0,
      isActive: json['is_active'] != false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      category: metadataMap['category']?.toString() ?? 'other',
    );
  }

  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final int pointsCost;
  final int stockTotal;
  final int stockRemaining;
  final bool isActive;
  final int sortOrder;
  final String category;
}

class RewardAdminEmployee {
  const RewardAdminEmployee({required this.id, required this.name});

  factory RewardAdminEmployee.fromJson(Map<String, dynamic> json) {
    return RewardAdminEmployee(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Nhân viên',
    );
  }

  final String id;
  final String name;
}

class EmployeeOtSummary {
  const EmployeeOtSummary({
    required this.userId,
    required this.name,
    required this.totalOt,
  });

  factory EmployeeOtSummary.fromJson(Map<String, dynamic> json) {
    return EmployeeOtSummary(
      userId: json['user_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Nhân viên',
      totalOt: _asDouble(json['total_ot']) ?? 0,
    );
  }

  final String userId;
  final String name;
  final double totalOt;
}

class RewardRedemption {
  const RewardRedemption({
    required this.id,
    required this.userId,
    required this.userName,
    required this.rewardItemId,
    required this.quantity,
    required this.unitPointsCost,
    required this.totalPointsCost,
    required this.status,
    required this.requestedNote,
    required this.processedNote,
    required this.processedBy,
    required this.processedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.rewardItem,
  });

  factory RewardRedemption.fromJson(Map<String, dynamic> json) {
    return RewardRedemption(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName:
          json['user_name']?.toString() ??
          (json['user'] is Map<String, dynamic>
              ? (json['user'] as Map<String, dynamic>)['name']?.toString()
              : null),
      rewardItemId: json['reward_item_id']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPointsCost: (json['unit_points_cost'] as num?)?.toInt() ?? 0,
      totalPointsCost: (json['total_points_cost'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'pending',
      requestedNote: json['requested_note']?.toString(),
      processedNote: json['processed_note']?.toString(),
      processedBy: json['processed_by']?.toString(),
      processedAt: _parseDateTime(json['processed_at']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      rewardItem: json['reward_item'] is Map<String, dynamic>
          ? RewardAdminItem.fromJson(
              json['reward_item'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  final String id;
  final String userId;
  final String? userName;
  final String rewardItemId;
  final int quantity;
  final int unitPointsCost;
  final int totalPointsCost;
  final String status;
  final String? requestedNote;
  final String? processedNote;
  final String? processedBy;
  final DateTime? processedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final RewardAdminItem? rewardItem;
}

class RewardTransaction {
  const RewardTransaction({
    required this.id,
    required this.type,
    required this.points,
    required this.note,
    required this.balanceAfter,
    required this.createdAt,
  });

  factory RewardTransaction.fromJson(Map<String, dynamic> json) {
    return RewardTransaction(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
      note: json['note']?.toString(),
      balanceAfter: (json['balance_after'] as num?)?.toInt() ?? 0,
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  final String id;
  final String type;
  final int points;
  final String? note;
  final int balanceAfter;
  final DateTime? createdAt;
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

String? _resolveAvatarUrl(String? avatarUrl) {
  if (avatarUrl == null || avatarUrl.isEmpty) return avatarUrl;
  if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
    return avatarUrl;
  }
  if (avatarUrl.startsWith('/')) {
    return '${AppConfig.instance.apiUrl}$avatarUrl';
  }
  return avatarUrl;
}

class RewardInternalRole {
  final String id;
  final String roleName;
  final double multiplier;

  const RewardInternalRole({
    required this.id,
    required this.roleName,
    required this.multiplier,
  });

  factory RewardInternalRole.fromJson(Map<String, dynamic> json) {
    return RewardInternalRole(
      id: json['id']?.toString() ?? '',
      roleName: (json['name'] ?? json['role_name'])?.toString() ?? '',
      multiplier: _asDouble(json['multiplier']) ?? 1.0,
    );
  }
}

class OdooTaskTagConfig {
  final String id;
  final String tagName;
  final int basePoints;

  const OdooTaskTagConfig({
    required this.id,
    required this.tagName,
    required this.basePoints,
  });

  factory OdooTaskTagConfig.fromJson(Map<String, dynamic> json) {
    return OdooTaskTagConfig(
      id: json['id']?.toString() ?? '',
      tagName: (json['name'] ?? json['tag_name'])?.toString() ?? '',
      basePoints: _asInt(json['base_points']) ?? 0,
    );
  }
}

class OdooJobTitleOverview {
  final String jobTitle;
  final int userCount;
  final bool isConfigured;
  final String? mappingId;
  final String? internalRoleId;
  final String? internalRoleName;

  const OdooJobTitleOverview({
    required this.jobTitle,
    required this.userCount,
    required this.isConfigured,
    this.mappingId,
    this.internalRoleId,
    this.internalRoleName,
  });

  factory OdooJobTitleOverview.fromJson(Map<String, dynamic> json) {
    final internalRole = json['internal_role'] as Map<String, dynamic>?;
    return OdooJobTitleOverview(
      jobTitle:
          (json['odoo_job_title'] ??
                  json['odooJobTitle'] ??
                  json['job_title'] ??
                  json['jobTitle'] ??
                  json['name'] ??
                  json['title'])
              ?.toString() ??
          '',
      userCount: _asInt(json['user_count'] ?? json['userCount']) ?? 0,
      isConfigured:
          json['is_mapped'] == true ||
          json['isMapped'] == true ||
          json['is_configured'] == true ||
          json['isConfigured'] == true,
      mappingId: (json['mapping_id'] ?? json['mappingId'])?.toString(),
      internalRoleId:
          (json['internal_role_id'] ??
                  json['internalRoleId'] ??
                  internalRole?['id'])
              ?.toString(),
      internalRoleName:
          (json['internal_role_name'] ??
                  json['internalRoleName'] ??
                  internalRole?['name'] ??
                  internalRole?['role_name'])
              ?.toString(),
    );
  }
}

class JobTitleMapping {
  final String id;
  final String jobTitle;
  final String internalRoleId;
  final String? internalRoleName;

  const JobTitleMapping({
    required this.id,
    required this.jobTitle,
    required this.internalRoleId,
    this.internalRoleName,
  });

  factory JobTitleMapping.fromJson(Map<String, dynamic> json) {
    return JobTitleMapping(
      id: json['id']?.toString() ?? '',
      jobTitle:
          (json['odoo_job_title'] ??
                  json['odooJobTitle'] ??
                  json['job_title'] ??
                  json['jobTitle'] ??
                  json['name'] ??
                  json['title'])
              ?.toString() ??
          '',
      internalRoleId:
          (json['internal_role_id'] ?? json['internalRoleId'])?.toString() ??
          '',
      internalRoleName:
          (json['internal_role_name'] ??
                  json['internalRoleName'] ??
                  (json['internal_role'] as Map<String, dynamic>?)?['name']
                      ?.toString() ??
                  (json['internalRole'] as Map<String, dynamic>?)?['name']
                      ?.toString())
              ?.toString(),
    );
  }
}

class HrEmployeeDirectoryQuery {
  const HrEmployeeDirectoryQuery({
    this.search,
    this.department,
    this.jobTitle,
    this.isActive,
    this.employmentStatus,
    this.page = 1,
    this.limit = 20,
  });

  final String? search;
  final String? department;
  final String? jobTitle;
  final bool? isActive;
  final String? employmentStatus;
  final int page;
  final int limit;

  HrEmployeeDirectoryQuery copyWith({
    String? search,
    String? department,
    String? jobTitle,
    bool? isActive,
    String? employmentStatus,
    int? page,
    int? limit,
  }) {
    return HrEmployeeDirectoryQuery(
      search: search ?? this.search,
      department: department ?? this.department,
      jobTitle: jobTitle ?? this.jobTitle,
      isActive: isActive ?? this.isActive,
      employmentStatus: employmentStatus ?? this.employmentStatus,
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HrEmployeeDirectoryQuery &&
        other.search == search &&
        other.department == department &&
        other.jobTitle == jobTitle &&
        other.isActive == isActive &&
        other.employmentStatus == employmentStatus &&
        other.page == page &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(
    search,
    department,
    jobTitle,
    isActive,
    employmentStatus,
    page,
    limit,
  );
}

class HrEmployeeSummary {
  const HrEmployeeSummary({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.department,
    this.jobTitle,
    this.employmentStatus,
    this.isActive = true,
  });

  factory HrEmployeeSummary.fromJson(Map<String, dynamic> json) {
    return HrEmployeeSummary(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      avatarUrl: _resolveAvatarUrl(
        (json['avatar_url'] ?? json['avatarUrl'])?.toString(),
      ),
      department: (json['department'] ?? json['department_name'])?.toString(),
      jobTitle: (json['job_title'] ?? json['jobTitle'])?.toString(),
      employmentStatus: (json['employment_status'] ?? json['employmentStatus'])
          ?.toString(),
      isActive: json['is_active'] == true || json['isActive'] == true,
    );
  }

  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String? department;
  final String? jobTitle;
  final String? employmentStatus;
  final bool isActive;
}

class HrEmployeeDirectoryPage {
  const HrEmployeeDirectoryPage({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  factory HrEmployeeDirectoryPage.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List<dynamic>? ?? const [];
    return HrEmployeeDirectoryPage(
      items: itemsRaw
          .whereType<Map<String, dynamic>>()
          .map(HrEmployeeSummary.fromJson)
          .toList(growable: false),
      total: _asInt(json['total']) ?? 0,
      page: _asInt(json['page']) ?? 1,
      limit: _asInt(json['limit']) ?? 20,
    );
  }

  final List<HrEmployeeSummary> items;
  final int total;
  final int page;
  final int limit;

  bool get hasMore => page * limit < total;
}

class EmployeeProfile {
  const EmployeeProfile({
    required this.userId,
    this.dateOfBirth,
    this.gender,
    this.identityNumber,
    this.identityIssuedDate,
    this.identityIssuedPlace,
    this.permanentAddress,
    this.currentAddress,
    this.personalPhone,
    this.personalEmail,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.emergencyContactRelationship,
    this.maritalStatus,
    this.taxCode,
    this.bankAccountNumber,
    this.bankName,
    this.bankCode,
    this.bankAccountName,
    this.bankQrImageUrl,
    this.bankQrSource,
    this.joinedAt,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory EmployeeProfile.fromJson(Map<String, dynamic> json) {
    return EmployeeProfile(
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      dateOfBirth: json['date_of_birth']?.toString(),
      gender: json['gender']?.toString(),
      identityNumber: json['identity_number']?.toString(),
      identityIssuedDate: json['identity_issued_date']?.toString(),
      identityIssuedPlace: json['identity_issued_place']?.toString(),
      permanentAddress: json['permanent_address']?.toString(),
      currentAddress: json['current_address']?.toString(),
      personalPhone: json['personal_phone']?.toString(),
      personalEmail: json['personal_email']?.toString(),
      emergencyContactName: json['emergency_contact_name']?.toString(),
      emergencyContactPhone: json['emergency_contact_phone']?.toString(),
      emergencyContactRelationship: json['emergency_contact_relationship']
          ?.toString(),
      maritalStatus: json['marital_status']?.toString(),
      taxCode: json['tax_code']?.toString(),
      bankAccountNumber: json['bank_account_number']?.toString(),
      bankName: json['bank_name']?.toString(),
      bankCode: json['bank_code']?.toString(),
      bankAccountName: json['bank_account_name']?.toString(),
      bankQrImageUrl: json['bank_qr_image_url']?.toString(),
      bankQrSource: json['bank_qr_source']?.toString(),
      joinedAt: json['joined_at']?.toString(),
      updatedBy: json['updated_by']?.toString(),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  final String userId;
  final String? dateOfBirth;
  final String? gender;
  final String? identityNumber;
  final String? identityIssuedDate;
  final String? identityIssuedPlace;
  final String? permanentAddress;
  final String? currentAddress;
  final String? personalPhone;
  final String? personalEmail;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? emergencyContactRelationship;
  final String? maritalStatus;
  final String? taxCode;
  final String? bankAccountNumber;
  final String? bankName;
  final String? bankCode;
  final String? bankAccountName;
  final String? bankQrImageUrl;
  final String? bankQrSource;
  final String? joinedAt;
  final String? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class EmployeeContract {
  const EmployeeContract({
    required this.id,
    required this.userId,
    required this.type,
    this.signedDate,
    required this.startDate,
    this.endDate,
    required this.status,
    this.notes,
    this.renewedFromId,
    required this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    this.daysUntilExpiry,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentMimeType,
    this.attachmentSize,
  });

  factory EmployeeContract.fromJson(Map<String, dynamic> json) {
    return EmployeeContract(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      type: json['type']?.toString() ?? 'draft',
      signedDate: json['signed_date']?.toString(),
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString(),
      status: json['status']?.toString() ?? 'draft',
      notes: json['notes']?.toString(),
      renewedFromId: json['renewed_from_id']?.toString(),
      createdBy: json['created_by']?.toString() ?? '',
      updatedBy: json['updated_by']?.toString(),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      daysUntilExpiry: _asInt(json['days_until_expiry']),
      attachmentUrl: (json['attachment_url'] ?? json['attachmentUrl'])
          ?.toString(),
      attachmentName: (json['attachment_name'] ?? json['attachmentName'])
          ?.toString(),
      attachmentMimeType:
          (json['attachment_mime_type'] ?? json['attachmentMimeType'])
              ?.toString(),
      attachmentSize: _asInt(json['attachment_size'] ?? json['attachmentSize']),
    );
  }

  final String id;
  final String userId;
  final String type;
  final String? signedDate;
  final String startDate;
  final String? endDate;
  final String status;
  final String? notes;
  final String? renewedFromId;
  final String createdBy;
  final String? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? daysUntilExpiry;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentMimeType;
  final int? attachmentSize;

  bool get hasAttachment =>
      attachmentUrl != null && attachmentUrl!.trim().isNotEmpty;

  bool get isActive => status == 'active';
}

class EmployeeDetailResponse {
  const EmployeeDetailResponse({
    required this.employee,
    this.profile,
    this.contracts = const [],
  });

  factory EmployeeDetailResponse.fromJson(Map<String, dynamic> json) {
    final profileJson = json['profile'] as Map<String, dynamic>?;
    final contractsRaw = json['contracts'] as List<dynamic>? ?? const [];
    return EmployeeDetailResponse(
      employee: HrEmployeeSummary.fromJson(json),
      profile: profileJson == null
          ? null
          : EmployeeProfile.fromJson(profileJson),
      contracts: contractsRaw
          .whereType<Map<String, dynamic>>()
          .map(EmployeeContract.fromJson)
          .toList(growable: false),
    );
  }

  final HrEmployeeSummary employee;
  final EmployeeProfile? profile;
  final List<EmployeeContract> contracts;
}

class EmployeeProfileUpdateRequest {
  const EmployeeProfileUpdateRequest({
    this.dateOfBirth,
    this.gender,
    this.identityNumber,
    this.identityIssuedDate,
    this.identityIssuedPlace,
    this.permanentAddress,
    this.currentAddress,
    this.personalPhone,
    this.personalEmail,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.emergencyContactRelationship,
    this.maritalStatus,
    this.taxCode,
    this.bankAccountNumber,
    this.bankName,
    this.bankCode,
    this.bankAccountName,
    this.bankQrSource,
    this.joinedAt,
  });

  final String? dateOfBirth;
  final String? gender;
  final String? identityNumber;
  final String? identityIssuedDate;
  final String? identityIssuedPlace;
  final String? permanentAddress;
  final String? currentAddress;
  final String? personalPhone;
  final String? personalEmail;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? emergencyContactRelationship;
  final String? maritalStatus;
  final String? taxCode;
  final String? bankAccountNumber;
  final String? bankName;
  final String? bankCode;
  final String? bankAccountName;
  final String? bankQrSource;
  final String? joinedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
      if (gender != null) 'gender': gender,
      if (identityNumber != null) 'identity_number': identityNumber,
      if (identityIssuedDate != null)
        'identity_issued_date': identityIssuedDate,
      if (identityIssuedPlace != null)
        'identity_issued_place': identityIssuedPlace,
      if (permanentAddress != null) 'permanent_address': permanentAddress,
      if (currentAddress != null) 'current_address': currentAddress,
      if (personalPhone != null) 'personal_phone': personalPhone,
      if (personalEmail != null) 'personal_email': personalEmail,
      if (emergencyContactName != null)
        'emergency_contact_name': emergencyContactName,
      if (emergencyContactPhone != null)
        'emergency_contact_phone': emergencyContactPhone,
      if (emergencyContactRelationship != null)
        'emergency_contact_relationship': emergencyContactRelationship,
      if (maritalStatus != null) 'marital_status': maritalStatus,
      if (taxCode != null) 'tax_code': taxCode,
      if (bankAccountNumber != null) 'bank_account_number': bankAccountNumber,
      if (bankName != null) 'bank_name': bankName,
      if (bankCode != null) 'bank_code': bankCode,
      if (bankAccountName != null) 'bank_account_name': bankAccountName,
      if (bankQrSource != null) 'bank_qr_source': bankQrSource,
      if (joinedAt != null) 'joined_at': joinedAt,
    };
  }
}

class EmployeeContractRequest {
  const EmployeeContractRequest({
    required this.userId,
    required this.type,
    required this.startDate,
    this.signedDate,
    this.endDate,
    this.status,
    this.notes,
  });

  final String userId;
  final String type;
  final String startDate;
  final String? signedDate;
  final String? endDate;
  final String? status;
  final String? notes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'user_id': userId,
      'type': type,
      'start_date': startDate,
      if (signedDate != null) 'signed_date': signedDate,
      if (endDate != null) 'end_date': endDate,
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return <String, dynamic>{
      'type': type,
      'start_date': startDate,
      if (signedDate != null) 'signed_date': signedDate,
      if (endDate != null) 'end_date': endDate,
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes,
    };
  }
}

class ExpiringEmployeeContract {
  const ExpiringEmployeeContract({
    required this.contract,
    this.employee,
    this.daysUntilExpiry,
  });

  factory ExpiringEmployeeContract.fromJson(Map<String, dynamic> json) {
    final employeeJson = json['employee'] as Map<String, dynamic>?;
    return ExpiringEmployeeContract(
      contract: EmployeeContract.fromJson(json),
      employee: employeeJson == null
          ? null
          : HrEmployeeSummary.fromJson(employeeJson),
      daysUntilExpiry: _asInt(json['days_until_expiry']),
    );
  }

  final EmployeeContract contract;
  final HrEmployeeSummary? employee;
  final int? daysUntilExpiry;
}
