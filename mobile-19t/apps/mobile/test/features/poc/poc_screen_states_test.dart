import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/core/theme/theme_color_presets.dart';
import 'package:nineteen_tech_app/core/database/app_database.dart';
import 'package:nineteen_tech_app/features/chat/data/user_repository.dart';
import 'package:nineteen_tech_app/features/chat/providers/chat_providers.dart';
import 'package:nineteen_tech_app/features/poc/data/poc_repository.dart';
import 'package:nineteen_tech_app/features/poc/models/poc_models.dart';
import 'package:nineteen_tech_app/features/poc/providers/poc_providers.dart';
import 'package:nineteen_tech_app/features/poc/screens/poc_assignment_screen.dart';
import 'package:nineteen_tech_app/features/poc/screens/poc_form_screen.dart';
import 'package:nineteen_tech_app/features/poc/screens/poc_list_screen.dart';

void main() {
  Widget harness(Widget child, PocRepository repository) => ProviderScope(
    overrides: [
      pocRepositoryProvider.overrideWithValue(repository),
      chatListProvider.overrideWith(_EmptyChatListNotifier.new),
      userRepositoryProvider.overrideWithValue(_FakeUserRepository()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        extensions: [
          AppThemePaletteExtension(palette: AppThemePreset.noirGold.palette),
        ],
      ),
      home: child,
    ),
  );

  testWidgets('request form exposes concise required fields and chat context', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const PocFormScreen(
          initialConversationId: 'conv-1',
          sourceMessageId: 'message-1',
        ),
        _StatePocRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Khách hàng'), findsOneWidget);
    expect(find.text('Tên dự án / nội dung demo'), findsOneWidget);
    expect(find.text('Yêu cầu cần PoC'), findsOneWidget);
    expect(find.text('Lịch demo / hạn PoC'), findsOneWidget);
    expect(find.textContaining('liên kết với tin nhắn'), findsOneWidget);
    expect(find.textContaining('mã PoC'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'assignment shows projected overload and preserves draft on conflict',
    (tester) async {
      await tester.pumpWidget(
        harness(
          const PocAssignmentScreen(pocId: 'poc-1'),
          _StatePocRepository(conflictOnAssign: true),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Developer One'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      await tester.tap(find.text('Developer One'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cập nhật phân công'));
      await tester.pumpAndSettle();
      expect(find.text('Xác nhận cảnh báo tải'), findsOneWidget);
      await tester.tap(find.text('Vẫn phân công'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('PoC đã được cập nhật'), findsOneWidget);
      expect(
        find.textContaining('Bản nháp của bạn vẫn được giữ'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('queue presents empty and error recovery states', (tester) async {
    await tester.pumpWidget(
      harness(const PocListScreen(), _StatePocRepository(empty: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa có PoC phù hợp'), findsOneWidget);

    await tester.pumpWidget(
      harness(const PocListScreen(), _StatePocRepository(failList: true)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Không tải được PoC'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _EmptyChatListNotifier extends ChatListNotifier {
  @override
  Future<List<LocalConversation>> build() async => const [];
}

class _FakeUserRepository extends UserRepository {
  _FakeUserRepository() : super(Dio());
  @override
  Future<UserListResponse> getUsers({
    String? search,
    String? cursor,
    int limit = 50,
  }) async => const UserListResponse(
    users: [
      UserContact(id: 'dev-1', name: 'Developer One', email: 'dev@example.com'),
    ],
    total: 1,
    hasMore: false,
  );
}

class _StatePocRepository extends PocRepository {
  _StatePocRepository({
    this.empty = false,
    this.failList = false,
    this.conflictOnAssign = false,
  }) : super(Dio());

  final bool empty;
  final bool failList;
  final bool conflictOnAssign;

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
  }) async {
    if (failList) throw Exception('offline');
    return PocPage(
      items: empty ? const [] : [_poc()],
      total: empty ? 0 : 1,
      page: 1,
      limit: 20,
    );
  }

  @override
  Future<PocRecord> detail(String id) async => _poc();

  @override
  Future<PocCapacityWeek> previewCapacity({
    required DateTime plannedStart,
    required DateTime demoAt,
    required double estimatedHours,
    String? excludePocId,
  }) async => const PocCapacityWeek(
    isoYear: 2026,
    isoWeek: 33,
    dates: [
      '2026-08-10',
      '2026-08-11',
      '2026-08-12',
      '2026-08-13',
      '2026-08-14',
    ],
    developers: [
      PocCapacityDeveloper(
        userId: 'dev-1',
        name: 'Developer One',
        allocatedHours: 38,
        capacityHours: 40,
        remainingHours: 2,
        excessHours: 6,
        projectedHours: 46,
        overCapacity: true,
        hasOverlap: true,
        dailyLoad: {},
        pocs: [],
      ),
    ],
  );

  @override
  Future<PocRecord> assign(String id, Map<String, dynamic> data) async {
    if (conflictOnAssign) {
      throw PocConflict(_poc(), 'PoC vừa được người khác cập nhật');
    }
    return _poc();
  }
}

PocRecord _poc() => PocRecord(
  id: 'poc-1',
  code: 'SALE.DEV-WA-P0018-1000-14.08.26',
  customerName: 'Acme',
  title: 'Demo workflow',
  requirement: 'Validate workflow',
  productType: 'web_app',
  priority: 'high',
  saleUserId: 'sale-1',
  developerUserId: 'dev-1',
  plannedStartAt: DateTime.now().add(const Duration(hours: 1)),
  estimatedHours: 8,
  demoAt: DateTime.now().add(const Duration(days: 3)),
  status: 'assigned',
  version: 2,
  referenceLinks: const [],
  history: const [],
  saleUser: const PocUser(id: 'sale-1', name: 'Sale Owner'),
  developerUser: const PocUser(id: 'dev-1', name: 'Developer One'),
);
