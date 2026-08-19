import 'package:dio/dio.dart';
import '../models/poc_models.dart';

class PocRepository {
  const PocRepository(this._dio);
  final Dio _dio;

  Future<PocPage> list({
    String mode = 'all',
    String? search,
    String? status,
    String? week,
    String? developerUserId,
    String? saleUserId,
    String? priority,
    int page = 1,
  }) async {
    final response = await _dio.get(
      '/pocs',
      queryParameters: {
        'mode': mode,
        'page': page,
        if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
        'status': ?status,
        'week': ?week,
        'developer_user_id': ?developerUserId,
        'sale_user_id': ?saleUserId,
        'priority': ?priority,
      },
    );
    return PocPage.fromJson(_asMap(response.data));
  }

  Future<PocRecord> detail(String id) async {
    final response = await _dio.get('/pocs/$id');
    return PocRecord.fromJson(_asMap(response.data));
  }

  Future<PocRecord> create(Map<String, dynamic> data) async {
    final response = await _dio.post('/pocs', data: data);
    return PocRecord.fromJson(_asMap(response.data));
  }

  Future<PocRecord> assign(String id, Map<String, dynamic> data) =>
      _mutation('/pocs/$id/assignment', data);

  Future<PocRecord> updatePlan(String id, Map<String, dynamic> data) =>
      _mutation('/pocs/$id/plan', data);

  Future<PocRecord> transition(String id, Map<String, dynamic> data) =>
      _mutation('/pocs/$id/status', data);

  Future<PocCapacityWeek> capacity(DateTime week) async {
    final response = await _dio.get(
      '/pocs/capacity',
      queryParameters: {'week': week.toIso8601String()},
    );
    return PocCapacityWeek.fromJson(_asMap(response.data));
  }

  Future<PocCapacityWeek> previewCapacity({
    required DateTime plannedStart,
    required DateTime demoAt,
    required double estimatedHours,
    String? excludePocId,
  }) async {
    final response = await _dio.post(
      '/pocs/capacity/preview',
      data: {
        'planned_start_at': plannedStart.toUtc().toIso8601String(),
        'demo_at': demoAt.toUtc().toIso8601String(),
        'estimated_hours': estimatedHours,
        'exclude_poc_id': ?excludePocId,
      },
    );
    return PocCapacityWeek.fromJson(_asMap(response.data));
  }

  Future<PocWeeklyReport> weeklyReport(DateTime week) async {
    final response = await _dio.get(
      '/pocs/weekly-report',
      queryParameters: {'week': week.toIso8601String()},
    );
    return PocWeeklyReport.fromJson(_asMap(response.data));
  }

  Future<void> publishWeeklyReport(DateTime week) async {
    await _dio.post(
      '/pocs/weekly-report/publish',
      queryParameters: {'week': week.toIso8601String()},
    );
  }

  Future<PocRecord> _mutation(String path, Map<String, dynamic> data) async {
    try {
      final response = await _dio.patch(path, data: data);
      return PocRecord.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      if (error.response?.statusCode == 409) {
        final payload = _asMap(error.response?.data);
        final body = payload['response'] is Map
            ? _asMap(payload['response'])
            : payload;
        final latest = body['latest'] is Map
            ? PocRecord.fromJson(_asMap(body['latest']))
            : null;
        throw PocConflict(
          latest,
          body['message']?.toString() ?? 'PoC vừa được người khác cập nhật',
        );
      }
      rethrow;
    }
  }

  Map<String, dynamic> _asMap(dynamic value) =>
      value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};
}
