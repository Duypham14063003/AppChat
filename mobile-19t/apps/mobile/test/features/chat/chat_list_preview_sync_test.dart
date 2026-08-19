import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/core/database/app_database.dart';
import 'package:nineteen_tech_app/core/database/chat_dao.dart';
import 'package:nineteen_tech_app/core/network/websocket_manager.dart';
import 'package:nineteen_tech_app/core/network/websocket_provider.dart';
import 'package:nineteen_tech_app/core/notifications/badge_sync_service.dart';
import 'package:nineteen_tech_app/features/auth/data/auth_repository.dart';
import 'package:nineteen_tech_app/features/auth/providers/auth_notifier.dart';
import 'package:nineteen_tech_app/features/chat/data/chat_repository.dart';
import 'package:nineteen_tech_app/features/chat/providers/chat_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('chatListProvider preview sync', () {
    test(
      'updates latest preview to recalled placeholder on recall event',
      () async {
        final db = _InMemoryAppDatabase();
        addTearDown(db.close);
        const convId = 'conv-recall';
        const messageId = 'msg-recall';

        await _seedConversation(
          db.chatDao,
          convId: convId,
          messageId: messageId,
          lastMessageContent: 'Tin nhắn cần thu hồi',
          messageContent: 'Tin nhắn cần thu hồi',
        );

        final wsManager = _FakeWebSocketManager();
        final container = ProviderContainer(
          overrides: [
            authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
            chatDaoProvider.overrideWithValue(db.chatDao),
            chatRepositoryProvider.overrideWithValue(_FakeChatRepository()),
            webSocketManagerProvider.overrideWithValue(wsManager),
            badgeSyncServiceProvider.overrideWithValue(
              BadgeSyncService(
                readUnreadCounts: () async => const [],
                manageBadgeLocallyOverride: false,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(chatListProvider.future);

        wsManager.emit('message_recalled', {
          'id': messageId,
          'conv_id': convId,
          'sender_id': 'user-1',
          'type': 'text',
          'content': null,
          'created_at': '2026-05-06T09:59:00.000Z',
          'deleted_at': '2026-05-06T10:13:00.000Z',
        });
        await _flushAsyncWork();

        final conversation = await db.chatDao.getConversation(convId);
        expect(conversation?.lastMessageContent, 'Tin nhắn đã được thu hồi');

        final providerValue = container.read(chatListProvider).valueOrNull;
        final providerConversation = providerValue?.firstWhere(
          (conversation) => conversation.id == convId,
        );
        expect(
          providerConversation?.lastMessageContent,
          'Tin nhắn đã được thu hồi',
        );
      },
    );

    test('updates latest preview text on edit event', () async {
      final db = _InMemoryAppDatabase();
      addTearDown(db.close);
      const convId = 'conv-edit';
      const messageId = 'msg-edit';

      await _seedConversation(
        db.chatDao,
        convId: convId,
        messageId: messageId,
        lastMessageContent: 'Nội dung cũ',
        messageContent: 'Nội dung cũ',
      );

      final wsManager = _FakeWebSocketManager();
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
          chatDaoProvider.overrideWithValue(db.chatDao),
          chatRepositoryProvider.overrideWithValue(_FakeChatRepository()),
          webSocketManagerProvider.overrideWithValue(wsManager),
          badgeSyncServiceProvider.overrideWithValue(
            BadgeSyncService(
              readUnreadCounts: () async => const [],
              manageBadgeLocallyOverride: false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(chatListProvider.future);

      wsManager.emit('message_updated', {
        'id': messageId,
        'conv_id': convId,
        'sender_id': 'user-1',
        'type': 'text',
        'content': 'Nội dung mới',
        'created_at': '2026-05-06T09:59:00.000Z',
        'edited_at': '2026-05-06T10:10:00.000Z',
        'deleted_at': null,
      });
      await _flushAsyncWork();

      final conversation = await db.chatDao.getConversation(convId);
      expect(conversation?.lastMessageContent, 'Nội dung mới');

      final providerValue = container.read(chatListProvider).valueOrNull;
      final providerConversation = providerValue?.firstWhere(
        (conversation) => conversation.id == convId,
      );
      expect(providerConversation?.lastMessageContent, 'Nội dung mới');
    });
  });
}

Future<void> _seedConversation(
  ChatDao dao, {
  required String convId,
  required String messageId,
  required String lastMessageContent,
  required String messageContent,
}) async {
  await dao.insertConversation(
    LocalConversationsCompanion.insert(
      id: convId,
      createdBy: 'user-1',
      createdAt: DateTime.parse('2026-05-06T09:00:00.000Z'),
      type: const Value('DIRECT'),
      otherMemberName: const Value('Teammate'),
      lastMessageAt: Value(DateTime.parse('2026-05-06T09:59:00.000Z')),
      lastMessageContent: Value(lastMessageContent),
      lastMessageSenderId: const Value('user-1'),
    ),
  );

  await dao.insertMessage(
    buildIncomingMessageCompanion({
      'id': messageId,
      'conv_id': convId,
      'sender_id': 'user-1',
      'type': 'text',
      'content': messageContent,
      'created_at': '2026-05-06T09:59:00.000Z',
      'deleted_at': null,
      'edited_at': null,
    }, defaultStatus: 'sent'),
  );
}

Future<void> _flushAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(const Duration(milliseconds: 10));
  await Future<void>.delayed(Duration.zero);
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async {
    return const AuthState(
      status: AuthStatus.authenticated,
      user: UserInfo(
        id: 'user-1',
        email: 'tester@example.com',
        name: 'Tester',
        employmentStatus: 'official',
        roles: <String>[],
      ),
    );
  }
}

class _FakeChatRepository extends ChatRepository {
  _FakeChatRepository() : super(Dio());

  @override
  Future<Map<String, dynamic>> getConversations({String? cursor}) async {
    return {
      'conversations': const <Map<String, dynamic>>[],
      'nextCursor': null,
      'hasMore': false,
    };
  }
}

class _FakeWebSocketManager extends WebSocketManager {
  _FakeWebSocketManager()
    : super(baseUrl: 'http://localhost', tokenProvider: () => '');

  final Map<String, List<WsEventHandler>> _handlers = {};

  @override
  void on(String event, WsEventHandler handler) {
    _handlers.putIfAbsent(event, () => []).add(handler);
  }

  @override
  void off(String event, WsEventHandler handler) {
    _handlers[event]?.remove(handler);
  }

  void emit(String event, Map<String, dynamic> data) {
    final handlers = List<WsEventHandler>.from(_handlers[event] ?? const []);
    for (final handler in handlers) {
      handler(data);
    }
  }

  @override
  void connect() {}

  @override
  void disconnect() {}
}

class _InMemoryAppDatabase extends GeneratedDatabase implements AppDatabase {
  _InMemoryAppDatabase() : super(DatabaseConnection(NativeDatabase.memory()));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createTable(localConversations);
      await m.createTable(localMessages);
      await customStatement(
        'CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(id UNINDEXED, content, conv_id UNINDEXED)',
      );
    },
  );

  @override
  late final $LocalConversationsTable localConversations =
      $LocalConversationsTable(this);

  @override
  late final $LocalMessagesTable localMessages = $LocalMessagesTable(this);

  @override
  late final ChatDao chatDao = ChatDao(this as AppDatabase);

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localConversations,
    localMessages,
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
