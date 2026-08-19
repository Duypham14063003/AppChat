import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'hr_models.dart';

class HrRepository {
  static const int paymentQrMaxBytes = 5 * 1024 * 1024;

  final Dio _dio;
  HrRepository(this._dio);

  // --- Attendance ---

  Future<Map<String, dynamic>> checkin(Map<String, dynamic> data) async {
    final res = await _dio.post('/hr/attendance/checkin', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<AttendanceCheckoutResult> checkout(Map<String, dynamic> data) async {
    final res = await _dio.post('/hr/attendance/checkout', data: data);
    return AttendanceCheckoutResult.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<dynamic>> getHistory({String? from, String? to}) async {
    final params = <String, dynamic>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    final res = await _dio.get('/hr/attendance', queryParameters: params);
    return res.data as List<dynamic>;
  }

  Future<AttendanceSummary> getSummary(String from, String to) async {
    final res = await _dio.get(
      '/hr/attendance/summary',
      queryParameters: {'from': from, 'to': to},
    );
    return AttendanceSummary.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getTodayStatus() async {
    final res = await _dio.get('/hr/attendance/today');
    final data = res.data;
    if (data == null) {
      return {
        'sessions': [],
        'total_hours': 0,
        'total_ot': 0,
        'has_open_session': false,
        'session_count': 0,
      };
    }
    if (data is Map<String, dynamic>) return data;
    return {
      'sessions': [],
      'total_hours': 0,
      'total_ot': 0,
      'has_open_session': false,
      'session_count': 0,
    };
  }

  // --- Employee management ---

  Future<HrEmployeeDirectoryPage> getEmployees({
    String? search,
    String? department,
    String? jobTitle,
    bool? isActive,
    String? employmentStatus,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (department != null && department.trim().isNotEmpty)
        'department': department.trim(),
      if (jobTitle != null && jobTitle.trim().isNotEmpty)
        'job_title': jobTitle.trim(),
      'is_active': ?isActive,
      if (employmentStatus != null && employmentStatus.trim().isNotEmpty)
        'employment_status': employmentStatus.trim(),
    };
    final res = await _dio.get('/hr/employees', queryParameters: params);
    return HrEmployeeDirectoryPage.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<HrEmployeeSummary>> getAllEmployees({int pageSize = 100}) async {
    final employeesById = <String, HrEmployeeSummary>{};
    var page = 1;

    while (true) {
      final response = await getEmployees(page: page, limit: pageSize);
      for (final employee in response.items) {
        employeesById[employee.id] = employee;
      }
      if (!response.hasMore || response.items.isEmpty) break;
      page += 1;
    }

    return employeesById.values.toList(growable: false);
  }

  Future<EmployeeDetailResponse> getEmployeeDetail(String id) async {
    final res = await _dio.get('/hr/employees/$id');
    return EmployeeDetailResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<EmployeeDetailResponse> getMyEmployeeProfile() async {
    final res = await _dio.get('/hr/employees/me');
    return EmployeeDetailResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<EmployeeProfile> updateMyEmployeeProfile(
    EmployeeProfileUpdateRequest request,
  ) async {
    final res = await _dio.patch(
      '/hr/employees/me/profile',
      data: request.toJson(),
    );
    return EmployeeProfile.fromJson(res.data as Map<String, dynamic>);
  }

  Future<EmployeeProfile> updateEmployeeProfile({
    required String userId,
    required EmployeeProfileUpdateRequest request,
  }) async {
    final res = await _dio.patch(
      '/hr/employees/$userId/profile',
      data: request.toJson(),
    );
    return EmployeeProfile.fromJson(res.data as Map<String, dynamic>);
  }

  Future<EmployeeProfile> uploadEmployeePaymentQr({
    String? userId,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > paymentQrMaxBytes) {
      throw ArgumentError('Ảnh QR không được vượt quá 5 MiB');
    }
    final mediaType = _paymentQrMediaType(file.name, file.mimeType);
    if (mediaType == null) {
      throw ArgumentError('Ảnh QR chỉ hỗ trợ JPEG, PNG hoặc WebP');
    }
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: file.name,
        contentType: mediaType,
      ),
    });
    final path = userId == null
        ? '/hr/employees/me/payment-qr'
        : '/hr/employees/$userId/payment-qr';
    final res = await _dio.post(path, data: formData);
    return EmployeeProfile.fromJson(res.data as Map<String, dynamic>);
  }

  MediaType? _paymentQrMediaType(String filename, String? declaredMimeType) {
    final extension = filename.split('.').last.toLowerCase();
    final fromExtension = switch (extension) {
      'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
      'webp' => MediaType('image', 'webp'),
      'png' => MediaType('image', 'png'),
      _ => null,
    };
    if (fromExtension != null) return fromExtension;
    return switch (declaredMimeType?.toLowerCase()) {
      'image/jpeg' => MediaType('image', 'jpeg'),
      'image/png' => MediaType('image', 'png'),
      'image/webp' => MediaType('image', 'webp'),
      _ => null,
    };
  }

  Future<EmployeeProfile> deleteEmployeePaymentQr({String? userId}) async {
    final path = userId == null
        ? '/hr/employees/me/payment-qr'
        : '/hr/employees/$userId/payment-qr';
    final res = await _dio.delete(path);
    return EmployeeProfile.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<EmployeeContract>> getEmployeeContracts(String userId) async {
    final res = await _dio.get('/hr/employees/$userId/contracts');
    final data = res.data as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(EmployeeContract.fromJson)
        .toList(growable: false);
  }

  Future<List<ExpiringEmployeeContract>> getExpiringContracts() async {
    final res = await _dio.get('/hr/employees/contracts/expiring');
    final data = res.data as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(ExpiringEmployeeContract.fromJson)
        .toList(growable: false);
  }

  Future<EmployeeContract> createEmployeeContract(
    EmployeeContractRequest request,
  ) async {
    final res = await _dio.post(
      '/hr/employees/contracts',
      data: request.toJson(),
    );
    return EmployeeContract.fromJson(res.data as Map<String, dynamic>);
  }

  Future<EmployeeContract> updateEmployeeContract({
    required String contractId,
    required EmployeeContractRequest request,
  }) async {
    final res = await _dio.patch(
      '/hr/employees/contracts/$contractId',
      data: request.toUpdateJson(),
    );
    return EmployeeContract.fromJson(res.data as Map<String, dynamic>);
  }

  Future<EmployeeContract> renewEmployeeContract({
    required String contractId,
    required EmployeeContractRequest request,
  }) async {
    final res = await _dio.post(
      '/hr/employees/contracts/$contractId/renew',
      data: request.toJson(),
    );
    return EmployeeContract.fromJson(res.data as Map<String, dynamic>);
  }

  Future<EmployeeContract> uploadEmployeeContractAttachment({
    required String contractId,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: file.name),
    });
    final res = await _dio.post(
      '/hr/employees/contracts/$contractId/attachment',
      data: formData,
    );
    return EmployeeContract.fromJson(res.data as Map<String, dynamic>);
  }

  Future<EmployeeContract> deleteEmployeeContractAttachment(
    String contractId,
  ) async {
    final res = await _dio.delete(
      '/hr/employees/contracts/$contractId/attachment',
    );
    return EmployeeContract.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteEmployeeContract(String contractId) async {
    await _dio.delete('/hr/employees/contracts/$contractId');
  }

  // --- Leave ---

  Future<LeaveRequest> createLeave(Map<String, dynamic> data) async {
    final res = await _dio.post('/hr/leaves', data: data);
    return LeaveRequest.fromJson(res.data as Map<String, dynamic>);
  }

  Future<LeaveListResponse> getLeaves({
    String? status,
    String? userId,
    int? year,
    int? month,
  }) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    if (userId != null && userId.isNotEmpty) params['user_id'] = userId;
    if (year != null) params['year'] = year;
    if (month != null) params['month'] = month;
    final res = await _dio.get('/hr/leaves', queryParameters: params);
    final data = res.data;
    if (data is List) {
      return LeaveListResponse(
        leaves: data
            .whereType<Map<String, dynamic>>()
            .map(LeaveRequest.fromJson)
            .toList(growable: false),
        otHours: 0,
        leaveDays: 0,
        wfhDays: 0,
      );
    }
    return LeaveListResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<LeaveBalance> getLeaveBalance({int? year}) async {
    final params = <String, dynamic>{};
    if (year != null) {
      params['year'] = year;
    }

    final res = await _dio.get('/hr/leaves/balance', queryParameters: params);
    return LeaveBalance.fromJson(res.data as Map<String, dynamic>);
  }

  Future<WfhBalance> getWfhBalance({int? year}) async {
    final params = <String, dynamic>{};
    if (year != null) {
      params['year'] = year;
    }

    final res = await _dio.get(
      '/hr/leaves/wfh-balance',
      queryParameters: params,
    );
    return WfhBalance.fromJson(res.data as Map<String, dynamic>);
  }

  Future<WfhAdminConfig> getAdminWfhConfig({required int year}) async {
    final res = await _dio.get(
      '/hr/leaves/admin/wfh-config',
      queryParameters: {'year': year},
    );
    return WfhAdminConfig.fromJson(res.data as Map<String, dynamic>);
  }

  Future<WfhAdminConfig> updateAdminWfhConfig({
    required int year,
    required double allocatedDays,
  }) async {
    final res = await _dio.patch(
      '/hr/leaves/admin/wfh-config',
      data: {'year': year, 'allocated_days': allocatedDays},
    );
    return WfhAdminConfig.fromJson(res.data as Map<String, dynamic>);
  }

  Future<WfhBalance> getAdminUserWfhBalance({
    required String userId,
    required int year,
  }) async {
    final res = await _dio.get(
      '/hr/leaves/admin/users/$userId/wfh-balance',
      queryParameters: {'year': year},
    );
    return WfhBalance.fromJson(res.data as Map<String, dynamic>);
  }

  Future<WfhBalance> updateAdminUserWfhBalance({
    required String userId,
    required int year,
    required double allocatedDays,
  }) async {
    final res = await _dio.patch(
      '/hr/leaves/admin/users/$userId/wfh-balance',
      data: {'year': year, 'allocated_days': allocatedDays},
    );
    return WfhBalance.fromJson(res.data as Map<String, dynamic>);
  }

  Future<EmployeePayrollSummary> getEmployeePayrollSummary({
    required String month,
    required String userId,
  }) async {
    final response = await _dio.get(
      '/hr/reports/payroll-summary',
      queryParameters: {'month': month, 'user_id': userId},
    );
    return EmployeePayrollSummary.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<PayrollWorkbookDownload> exportPayrollWorkbook({
    required String month,
  }) async {
    final response = await _dio.get<List<int>>(
      '/hr/reports/payroll-export',
      queryParameters: {'month': month},
      options: Options(responseType: ResponseType.bytes),
    );
    final rawBytes = response.data;
    if (rawBytes == null || rawBytes.isEmpty) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'Empty payroll export response',
      );
    }

    return PayrollWorkbookDownload(
      bytes: Uint8List.fromList(rawBytes),
      filename:
          _parseAttachmentFilename(
            response.headers.value('content-disposition'),
          ) ??
          'bang-cong-luong-$month.xlsx',
      mimeType:
          response.headers
              .value(Headers.contentTypeHeader)
              ?.split(';')
              .first
              .trim() ??
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  Future<RewardsOverviewResponse> getRewardsOverview({
    int limit = 20,
    String? department,
  }) async {
    final safeLimit = limit < 1 ? 1 : limit;
    final res = await _dio.get(
      '/rewards/overview',
      queryParameters: {
        'limit': safeLimit,
        if (department != null && department.trim().isNotEmpty)
          'department': department.trim(),
      },
    );
    return RewardsOverviewResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<RewardTopPeriodResponse> getRewardsTopPeriod({
    required String period,
    int limit = 2,
  }) async {
    final safeLimit = limit < 1 ? 1 : limit;
    final res = await _dio.get(
      '/rewards/top-period',
      queryParameters: {'period': period, 'limit': safeLimit},
    );
    return RewardTopPeriodResponse.fromJson(
      res.data as Map<String, dynamic>? ?? const {},
    );
  }

  Future<List<RewardAdminItem>> getAdminRewardItems() async {
    final res = await _dio.get('/rewards/admin/items?include_inactive=true');
    final data = res.data;
    final items = data is List<dynamic>
        ? data
        : (data as Map<String, dynamic>)['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(RewardAdminItem.fromJson)
        .toList(growable: false);
  }

  Future<List<RewardAdminEmployee>> getAdminRewardEmployees() async {
    final res = await _dio.get('/rewards/admin/employees');
    final data = res.data as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(RewardAdminEmployee.fromJson)
        .toList(growable: false);
  }

  Future<List<EmployeeOtSummary>> getAttendanceOtSummary({
    required String from,
    required String to,
  }) async {
    final res = await _dio.get(
      '/hr/attendance/ot-summary',
      queryParameters: {'from': from, 'to': to},
    );
    final data = res.data as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(EmployeeOtSummary.fromJson)
        .toList(growable: false);
  }

  Future<List<RewardAdminItem>> getRewardCatalog() async {
    final res = await _dio.get('/rewards/catalog');
    final data = res.data as List<dynamic>? ?? const [];
    final items = data
        .whereType<Map<String, dynamic>>()
        .map(RewardAdminItem.fromJson)
        .where((item) => item.isActive)
        .toList(growable: false);

    items.sort((a, b) {
      final sortCompare = a.sortOrder.compareTo(b.sortOrder);
      if (sortCompare != 0) return sortCompare;
      return a.pointsCost.compareTo(b.pointsCost);
    });

    return items;
  }

  Future<List<RewardRedemption>> getMyRewardRedemptions() async {
    final res = await _dio.get('/rewards/redemptions');
    final data = res.data as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(RewardRedemption.fromJson)
        .toList(growable: false);
  }

  Future<List<RewardTransaction>> getMyRewardTransactions() async {
    final res = await _dio.get('/rewards/transactions');
    final data = res.data as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(RewardTransaction.fromJson)
        .toList(growable: false);
  }

  Future<List<RewardRedemption>> getAdminRewardRedemptions({
    String? status,
  }) async {
    final params = <String, dynamic>{};
    if (status != null && status.trim().isNotEmpty) {
      params['status'] = status.trim();
    }
    final res = await _dio.get(
      '/rewards/admin/redemptions',
      queryParameters: params,
    );
    final data = res.data as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(RewardRedemption.fromJson)
        .toList(growable: false);
  }

  Future<void> processAdminRewardRedemption({
    required String id,
    required String status,
    String? processedNote,
  }) async {
    await _dio.patch(
      '/rewards/admin/redemptions/$id',
      data: {
        'status': status,
        if (processedNote != null && processedNote.trim().isNotEmpty)
          'processed_note': processedNote.trim(),
      },
    );
  }

  Future<void> grantAdminRewardPoints({
    required String userId,
    required int points,
    String? note,
  }) async {
    await _dio.post(
      '/rewards/admin/points/grant',
      data: {
        'user_id': userId,
        'points': points,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }

  Future<void> resetAdminRewardPoints() async {
    await _dio.post('/rewards/admin/points/reset');
  }

  Future<void> createRewardRedemption({
    required String rewardItemId,
    int quantity = 1,
    String? requestedNote,
  }) async {
    await _dio.post(
      '/rewards/redemptions',
      data: {
        'reward_item_id': rewardItemId,
        'quantity': quantity,
        if (requestedNote != null && requestedNote.trim().isNotEmpty)
          'requested_note': requestedNote.trim(),
      },
    );
  }

  Future<RewardAdminItem> createAdminRewardItem({
    required String name,
    required String description,
    required String imageUrl,
    required int pointsCost,
    required int stockTotal,
    required bool isActive,
    required int sortOrder,
    required String category,
  }) async {
    final res = await _dio.post(
      '/rewards/admin/items',
      data: {
        'name': name,
        'description': description,
        'image_url': imageUrl,
        'points_cost': pointsCost,
        'stock_total': stockTotal,
        'is_active': isActive,
        'sort_order': sortOrder,
        'metadata': {'category': category},
      },
    );
    return RewardAdminItem.fromJson(res.data as Map<String, dynamic>);
  }

  Future<RewardAdminItem> updateAdminRewardItem({
    required String id,
    String? name,
    String? description,
    String? imageUrl,
    int? pointsCost,
    int? stockTotal,
    bool? isActive,
    int? sortOrder,
    String? category,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (description != null) data['description'] = description;
    if (imageUrl != null) data['image_url'] = imageUrl;
    if (pointsCost != null) data['points_cost'] = pointsCost;
    if (stockTotal != null) data['stock_total'] = stockTotal;
    if (isActive != null) data['is_active'] = isActive;
    if (sortOrder != null) data['sort_order'] = sortOrder;
    if (category != null) {
      data['metadata'] = {'category': category};
    }

    final res = await _dio.patch('/rewards/admin/items/$id', data: data);
    return RewardAdminItem.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteAdminRewardItem(String id) async {
    await _dio.delete('/rewards/admin/items/$id');
  }

  Future<String> uploadRewardItemImage(XFile file) async {
    final bytes = await file.readAsBytes();
    final mimeType = file.mimeType ?? 'image/jpeg';
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: file.name,
        contentType: MediaType.parse(mimeType),
      ),
    });

    final res = await _dio.post('/rewards/admin/items/upload', data: formData);
    final data = res.data as Map<String, dynamic>;
    final url = data['url']?.toString();
    if (url == null || url.trim().isEmpty) {
      throw StateError('Không nhận được URL ảnh từ server');
    }

    return url;
  }

  Future<LeaveRequest> submitLeave(String id) async {
    final res = await _dio.patch('/hr/leaves/$id/submit');
    return LeaveRequest.fromJson(res.data as Map<String, dynamic>);
  }

  Future<LeaveRequest> approveLeave(String id) async {
    final res = await _dio.patch('/hr/leaves/$id/approve');
    return LeaveRequest.fromJson(res.data as Map<String, dynamic>);
  }

  Future<LeaveRequest> rejectLeave(String id, String reason) async {
    final res = await _dio.patch(
      '/hr/leaves/$id/reject',
      data: {'reject_reason': reason},
    );
    return LeaveRequest.fromJson(res.data as Map<String, dynamic>);
  }

  Future<LeaveRequest> cancelApprovedLeave(String id, String reason) async {
    final res = await _dio.patch(
      '/hr/leaves/$id/cancel',
      data: {'reason': reason},
    );
    return LeaveRequest.fromJson(res.data as Map<String, dynamic>);
  }

  // --- Config ---

  Future<Map<String, dynamic>> getConfig() async {
    final res = await _dio.get('/hr/config');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateConfig(Map<String, dynamic> data) async {
    final res = await _dio.patch('/hr/config', data: data);
    return res.data as Map<String, dynamic>;
  }

  // --- Rewards admin configurations ---

  Future<List<RewardInternalRole>> getInternalRoles() async {
    final res = await _dio.get('/rewards/admin/internal-roles');
    final data = res.data as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(RewardInternalRole.fromJson)
        .toList(growable: false);
  }

  Future<RewardInternalRole> createInternalRole(
    String name,
    double multiplier,
  ) async {
    final res = await _dio.post(
      '/rewards/admin/internal-roles',
      data: {'name': name, 'multiplier': multiplier},
    );
    return RewardInternalRole.fromJson(res.data as Map<String, dynamic>);
  }

  Future<RewardInternalRole> updateInternalRole(
    String id,
    double multiplier,
  ) async {
    final res = await _dio.patch(
      '/rewards/admin/internal-roles/$id',
      data: {'multiplier': multiplier},
    );
    return RewardInternalRole.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteInternalRole(String id) async {
    await _dio.delete('/rewards/admin/internal-roles/$id');
  }

  Future<List<OdooTaskTagConfig>> getOdooTaskTagConfigs() async {
    final res = await _dio.get('/rewards/admin/odoo-tasks/tag-configs');
    final data = res.data as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(OdooTaskTagConfig.fromJson)
        .toList(growable: false);
  }

  Future<OdooTaskTagConfig> updateOdooTaskTagConfig(
    String id,
    int basePoints,
  ) async {
    final res = await _dio.patch(
      '/rewards/admin/odoo-tasks/tag-configs/$id',
      data: {'base_points': basePoints},
    );
    return OdooTaskTagConfig.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<OdooJobTitleOverview>> getJobTitlesOverview() async {
    final res = await _dio.get('/rewards/admin/odoo-tasks/job-titles-overview');
    final data = res.data as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(OdooJobTitleOverview.fromJson)
        .toList(growable: false);
  }

  Future<void> syncJobTitles() async {
    await _dio.post('/rewards/admin/odoo-tasks/sync-job-titles');
  }

  Future<List<JobTitleMapping>> getJobTitleMappings() async {
    final res = await _dio.get('/rewards/admin/job-title-mappings');
    final data = res.data as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(JobTitleMapping.fromJson)
        .toList(growable: false);
  }

  Future<JobTitleMapping> createJobTitleMapping({
    required String jobTitle,
    required String internalRoleId,
  }) async {
    final res = await _dio.post(
      '/rewards/admin/job-title-mappings',
      data: {'job_title': jobTitle, 'internal_role_id': internalRoleId},
    );
    return JobTitleMapping.fromJson(res.data as Map<String, dynamic>);
  }

  Future<JobTitleMapping> updateJobTitleMapping(
    String id, {
    required String internalRoleId,
  }) async {
    final res = await _dio.patch(
      '/rewards/admin/job-title-mappings/$id',
      data: {'internal_role_id': internalRoleId},
    );
    return JobTitleMapping.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteJobTitleMapping(String id) async {
    await _dio.delete('/rewards/admin/job-title-mappings/$id');
  }
}

String? _parseAttachmentFilename(String? contentDisposition) {
  if (contentDisposition == null || contentDisposition.isEmpty) {
    return null;
  }

  final encodedMatch = RegExp(
    r'''filename\*=UTF-8''([^;]+)''',
    caseSensitive: false,
  ).firstMatch(contentDisposition);
  if (encodedMatch != null) {
    return Uri.decodeComponent(encodedMatch.group(1) ?? '');
  }

  final plainMatch = RegExp(
    r'filename="?([^";]+)"?',
    caseSensitive: false,
  ).firstMatch(contentDisposition);
  return plainMatch?.group(1);
}
