import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/features/poc/data/poc_repository.dart';
import 'package:nineteen_tech_app/features/poc/models/poc_models.dart';

void main() {
  test('parses PoC detail, history and local dates resiliently', () {
    final poc = PocRecord.fromJson({
      'id': 'poc-1',
      'customer_name': 'Acme',
      'title': 'Sales demo',
      'requirement': 'Validate workflow',
      'product_type': 'web_app',
      'priority': 'high',
      'sale_user_id': 'sale-1',
      'demo_at': '2026-08-14T03:00:00.000Z',
      'status': 'in_progress',
      'version': 3,
      'reference_links': ['https://example.com/spec'],
      'sale_user': {'id': 'sale-1', 'name': 'Sale Owner'},
      'history': [
        {
          'id': 'history-1',
          'event_type': 'assigned',
          'created_at': '2026-08-12T01:00:00.000Z',
          'actor_name': 'Coordinator',
        },
      ],
    });

    expect(poc.id, 'poc-1');
    expect(poc.demoAt.isUtc, isFalse);
    expect(poc.saleUser?.name, 'Sale Owner');
    expect(poc.history.single.eventType, 'assigned');
    expect(poc.referenceLinks, ['https://example.com/spec']);
  });

  test('parses projected capacity overlap and overload', () {
    final developer = PocCapacityDeveloper.fromJson({
      'user_id': 'dev-1',
      'name': 'Dev One',
      'allocated_hours': 32,
      'capacity_hours': 40,
      'remaining_hours': 8,
      'excess_hours': 0,
      'projected_hours': 48,
      'projected_over_capacity': true,
      'projected_has_overlap': true,
      'daily_load': {'2026-08-12': 8},
      'pocs': [],
    });

    expect(developer.projectedHours, 48);
    expect(developer.overCapacity, isTrue);
    expect(developer.hasOverlap, isTrue);
  });

  test('repository sends filters and parses 409 latest state', () async {
    final dio = Dio();
    Map<String, dynamic>? capturedParams;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'GET') {
            capturedParams = Map<String, dynamic>.from(options.queryParameters);
            handler.resolve(
              Response(
                requestOptions: options,
                data: {'items': [], 'total': 0, 'page': 2, 'limit': 20},
              ),
            );
            return;
          }
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 409,
                data: {
                  'message': 'Version conflict',
                  'latest': _pocJson(version: 4),
                },
              ),
            ),
          );
        },
      ),
    );
    final repository = PocRepository(dio);

    await repository.list(
      mode: 'week',
      status: 'ready',
      developerUserId: 'dev-1',
      saleUserId: 'sale-1',
      priority: 'urgent',
      page: 2,
    );
    expect(capturedParams, containsPair('developer_user_id', 'dev-1'));
    expect(capturedParams, containsPair('sale_user_id', 'sale-1'));
    expect(capturedParams, containsPair('priority', 'urgent'));

    expect(
      () => repository.assign('poc-1', {'version': 3}),
      throwsA(
        isA<PocConflict>()
            .having((error) => error.latest?.version, 'latest version', 4)
            .having((error) => error.message, 'message', 'Version conflict'),
      ),
    );
  });
}

Map<String, dynamic> _pocJson({required int version}) => {
  'id': 'poc-1',
  'customer_name': 'Acme',
  'title': 'Demo',
  'requirement': 'Requirement',
  'product_type': 'validation',
  'priority': 'normal',
  'sale_user_id': 'sale-1',
  'demo_at': '2026-08-14T03:00:00.000Z',
  'status': 'assigned',
  'version': version,
  'reference_links': [],
};
