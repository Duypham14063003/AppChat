import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/core/theme/theme_color_presets.dart';
import 'package:nineteen_tech_app/features/hr/data/hr_models.dart';
import 'package:nineteen_tech_app/features/hr/data/hr_repository.dart';
import 'package:nineteen_tech_app/features/hr/providers/hr_providers.dart';
import 'package:nineteen_tech_app/features/poc/data/poc_repository.dart';
import 'package:nineteen_tech_app/features/poc/models/poc_models.dart';
import 'package:nineteen_tech_app/features/poc/providers/poc_providers.dart';
import 'package:nineteen_tech_app/features/poc/screens/poc_capacity_screen.dart';
import 'package:nineteen_tech_app/features/poc/screens/poc_detail_screen.dart';
import 'package:nineteen_tech_app/features/poc/screens/poc_list_screen.dart';
import 'package:nineteen_tech_app/features/poc/screens/poc_weekly_report_screen.dart';

void main() {
  final repository = _FakePocRepository();
  final hrRepository = _FakeHrRepository();

  Future<void> pumpScreen(WidgetTester tester, Widget child, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pocRepositoryProvider.overrideWithValue(repository),
          hrRepositoryProvider.overrideWithValue(hrRepository),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: AppThemePreset.noirGold.palette.background,
            extensions: [
              AppThemePaletteExtension(
                palette: AppThemePreset.noirGold.palette,
              ),
            ],
          ),
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('queue mobile screenshot', (tester) async {
    await pumpScreen(tester, const PocListScreen(), const Size(390, 844));
    expect(find.text('PoC của tôi'), findsOneWidget);
    expect(find.textContaining('SALE.DEV'), findsWidgets);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/poc_queue_mobile.png'),
    );
  });

  testWidgets('queue desktop screenshot', (tester) async {
    await pumpScreen(tester, const PocListScreen(), const Size(1200, 900));
    expect(find.byType(SegmentedButton<String>), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/poc_queue_desktop.png'),
    );
  });

  testWidgets('detail and history screenshot', (tester) async {
    await pumpScreen(
      tester,
      const PocDetailScreen(pocId: 'poc-1'),
      const Size(390, 844),
    );
    expect(find.text('Chi tiết PoC'), findsOneWidget);
    expect(find.text('Kế hoạch'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/poc_detail_mobile.png'),
    );
  });

  testWidgets('capacity mobile screenshot', (tester) async {
    await pumpScreen(
      tester,
      PocCapacityScreen(initialWeek: _week),
      const Size(390, 844),
    );
    expect(find.text('Developer One'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsWidgets);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/poc_capacity_mobile.png'),
    );
  });

  testWidgets('capacity desktop screenshot', (tester) async {
    await pumpScreen(
      tester,
      PocCapacityScreen(initialWeek: _week),
      const Size(1200, 900),
    );
    expect(find.textContaining('8.0h'), findsWidgets);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/poc_capacity_desktop.png'),
    );
  });

  testWidgets('weekly report screenshot', (tester) async {
    await pumpScreen(
      tester,
      PocWeeklyReportScreen(initialWeek: _week),
      const Size(390, 844),
    );
    expect(find.text('Lịch demo'), findsOneWidget);
    expect(find.text('Năng lực Dev'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/poc_weekly_mobile.png'),
    );
  });
}

final _week = DateTime(2026, 8, 12);

class _FakePocRepository extends PocRepository {
  _FakePocRepository() : super(Dio());

  @override
  Future<PocPage> list({
    String mode = 'all',
    String? search,
    String? status,
    String? week,
    String? developerUserId,
    String? saleUserId,
    String? priority,
    int page = 1,
  }) async => PocPage(items: [_poc()], total: 1, page: page, limit: 20);

  @override
  Future<PocRecord> detail(String id) async => _poc();

  @override
  Future<PocCapacityWeek> capacity(DateTime week) async => _capacity();

  @override
  Future<PocWeeklyReport> weeklyReport(DateTime week) async =>
      const PocWeeklyReport(
        isoYear: 2026,
        isoWeek: 33,
        weekStart: '10/08/2026',
        weekEnd: '16/08/2026',
        total: 3,
        counts: {'in_progress': 1, 'ready': 1, 'demonstrated': 1},
        demos: [
          {
            'id': 'poc-1',
            'code': 'SALE.DEV-WA-P0018-1000-14.08.26',
            'title': 'Demo quy trình phê duyệt',
            'customer_name': 'Acme Corporation',
            'developer_name': 'Developer One',
            'demo_at': '2026-08-14T03:00:00.000Z',
          },
        ],
        overdue: [],
        capacity: [
          {
            'user_id': 'dev-1',
            'name': 'Developer One',
            'allocated_hours': 44,
            'capacity_hours': 40,
            'over_capacity': true,
            'excess_hours': 4,
          },
        ],
      );
}

class _FakeHrRepository extends HrRepository {
  _FakeHrRepository() : super(Dio());
  @override
  Future<LeaveListResponse> getLeaves({
    String? status,
    String? userId,
    int? year,
    int? month,
  }) async => const LeaveListResponse(
    leaves: [
      LeaveRequest(
        id: 'leave-1',
        userId: 'dev-1',
        type: 'annual',
        startDate: '2026-08-13',
        endDate: '2026-08-13',
        isHalfDay: false,
        status: 'approved',
      ),
    ],
    otHours: 0,
    leaveDays: 1,
    wfhDays: 0,
  );
}

PocRecord _poc() => PocRecord(
  id: 'poc-1',
  code: 'SALE.DEV-WA-P0018-1000-14.08.26',
  customerName: 'Acme Corporation',
  title: 'Demo quy trình phê duyệt nhiều cấp cho khách hàng',
  requirement:
      'Mô phỏng luồng tạo đề nghị, duyệt nhiều cấp và theo dõi trạng thái theo thời gian thực.',
  productType: 'web_app',
  priority: 'high',
  saleUserId: 'sale-1',
  developerUserId: 'dev-1',
  assignedByUserId: 'user-1',
  workingConversationId: 'conv-1',
  plannedStartAt: DateTime(2026, 8, 10, 8),
  estimatedHours: 44,
  demoAt: DateTime(2026, 8, 14, 10),
  status: 'in_progress',
  version: 3,
  referenceLinks: const ['https://example.com/spec'],
  saleUser: const PocUser(id: 'sale-1', name: 'Nguyễn Minh Sale'),
  developerUser: const PocUser(id: 'dev-1', name: 'Developer One'),
  overdue: true,
  history: [
    PocHistoryEvent(
      id: 'history-1',
      eventType: 'created',
      createdAt: DateTime(2026, 8, 8, 9),
      actorName: 'Nguyễn Minh Sale',
    ),
    PocHistoryEvent(
      id: 'history-2',
      eventType: 'assigned',
      createdAt: DateTime(2026, 8, 9, 10),
      actorName: 'Điều phối viên',
    ),
  ],
);

PocCapacityWeek _capacity() => const PocCapacityWeek(
  isoYear: 2026,
  isoWeek: 33,
  dates: [
    '2026-08-10',
    '2026-08-11',
    '2026-08-12',
    '2026-08-13',
    '2026-08-14',
    '2026-08-15',
    '2026-08-16',
  ],
  developers: [
    PocCapacityDeveloper(
      userId: 'dev-1',
      name: 'Developer One',
      allocatedHours: 44,
      capacityHours: 40,
      remainingHours: -4,
      excessHours: 4,
      overCapacity: true,
      hasOverlap: true,
      dailyLoad: {
        '2026-08-10': 8,
        '2026-08-11': 8,
        '2026-08-12': 10,
        '2026-08-13': 10,
        '2026-08-14': 8,
      },
      pocs: [
        {
          'id': 'poc-1',
          'code': 'SALE.DEV-WA-P0018',
          'title': 'Demo approval workflow',
          'planned_start_at': '2026-08-10T01:00:00.000Z',
          'demo_at': '2026-08-14T03:00:00.000Z',
        },
      ],
    ),
    PocCapacityDeveloper(
      userId: 'dev-2',
      name: 'Developer Two With A Long Name',
      allocatedHours: 16,
      capacityHours: 40,
      remainingHours: 24,
      excessHours: 0,
      overCapacity: false,
      hasOverlap: false,
      dailyLoad: {
        '2026-08-10': 0,
        '2026-08-11': 4,
        '2026-08-12': 4,
        '2026-08-13': 4,
        '2026-08-14': 4,
      },
      pocs: [],
    ),
  ],
);
