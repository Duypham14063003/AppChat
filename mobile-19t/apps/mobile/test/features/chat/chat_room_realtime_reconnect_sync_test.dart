import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/core/database/app_database.dart';
import 'package:nineteen_tech_app/core/database/chat_dao.dart';
import 'package:nineteen_tech_app/core/network/websocket_manager.dart';
import 'package:nineteen_tech_app/core/network/websocket_provider.dart';
import 'package:nineteen_tech_app/core/notifications/badge_sync_service.dart';
import 'package:nineteen_tech_app/features/auth/data/auth_repository.dart';
import 'package:nineteen_tech_app/features/auth/providers/auth_notifier.dart';
import 'package:nineteen_tech_app/features/chat/data/chat_repository.dart';
import 'package:nineteen_tech_app/features/chat/data/conversation_encryption_key.dart';
import 'package:nineteen_tech_app/features/chat/data/conversation_key_repository.dart';
import 'package:nineteen_tech_app/features/chat/providers/chat_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('shouldSynchronizeChatRoomOnConnectedTransition', () {
    test('returns true only when websocket transitions into connected', () {
      expect(
        shouldSynchronizeChatRoomOnConnectedTransition(
          previousState: WsConnectionState.disconnected,
          nextState: WsConnectionState.connected,
        ),
        isTrue,
      );
      expect(
        shouldSynchronizeChatRoomOnConnectedTransition(
          previousState: WsConnectionState.connecting,
          nextState: WsConnectionState.connected,
        ),
        isTrue,
      );
      expect(
        shouldSynchronizeChatRoomOnConnectedTransition(
          previousState: WsConnectionState.connected,
          nextState: WsConnectionState.connected,
        ),
        isFalse,
      );
      expect(
        shouldSynchronizeChatRoomOnConnectedTransition(
          previousState: WsConnectionState.disconnected,
          nextState: WsConnectionState.connecting,
        ),
        isFalse,
      );
    });
  });

  group('shouldSynchronizeVisibleChatRoomOnReconnect', () {
    test('returns false when the room is not actively visible', () {
      expect(
        shouldSynchronizeVisibleChatRoomOnReconnect(
          conversationId: 'conv-1',
          activeConversationId: null,
          previousState: WsConnectionState.disconnected,
          nextState: WsConnectionState.connected,
        ),
        isFalse,
      );
      expect(
        shouldSynchronizeVisibleChatRoomOnReconnect(
          conversationId: 'conv-1',
          activeConversationId: 'conv-2',
          previousState: WsConnectionState.disconnected,
          nextState: WsConnectionState.connected,
        ),
        isFalse,
      );
    });

    test('returns true only for the active room on reconnect', () {
      expect(
        shouldSynchronizeVisibleChatRoomOnReconnect(
          conversationId: 'conv-1',
          activeConversationId: 'conv-1',
          previousState: WsConnectionState.disconnected,
          nextState: WsConnectionState.connected,
        ),
        isTrue,
      );
    });
  });

  group('chat room realtime recovery', () {
    test(
      'room entry ensures websocket recovery without blocking cached messages',
      () async {
        final db = _InMemoryAppDatabase();
        addTearDown(db.close);
        const convId = 'conv-room-open';

        await _seedConversation(
          db.chatDao,
          convId: convId,
          messageId: 'cached-msg',
          messageContent: 'cached hello',
        );

        final repoCompleter = Completer<Map<String, dynamic>>();
        final repo = _SequencedChatRepository(
          responseFutures: Queue.of([repoCompleter.future]),
        );
        final wsManager = _FakeWebSocketManager(
          initialState: WsConnectionState.disconnected,
        );
        final container = _createContainer(
          db: db,
          repository: repo,
          wsManager: wsManager,
        );
        addTearDown(container.dispose);

        final initialMessages = await container.read(
          chatMessagesProvider(convId).future,
        );
        expect(initialMessages.map((message) => message.content).toList(), [
          'cached hello',
        ]);

        final notifier = container.read(chatMessagesProvider(convId).notifier);
        notifier.recoverRealtimeOnRoomEntry();
        await _flushAsyncWork();

        expect(wsManager.ensureConnectedCount, 1);
        expect(repo.getMessagesCallCount, 1);
        expect(
          container
              .read(chatMessagesProvider(convId))
              .valueOrNull
              ?.map((message) => message.content)
              .toList(),
          ['cached hello'],
        );

        repoCompleter.complete(
          _messagePage(
            _apiMessage(
              id: 'remote-msg',
              convId: convId,
              content: 'remote hello',
              createdAt: '2026-06-15T08:00:00.000Z',
            ),
          ),
        );
        await _flushAsyncWork();

        expect(
          container
              .read(chatMessagesProvider(convId))
              .valueOrNull
              ?.map((message) => message.content)
              .toList(),
          ['remote hello', 'cached hello'],
        );
      },
    );

    test(
      'reconnect synchronization persists missed inbound room messages',
      () async {
        final db = _InMemoryAppDatabase();
        addTearDown(db.close);
        const convId = 'conv-reconnect';

        await _seedConversation(
          db.chatDao,
          convId: convId,
          messageId: 'cached-msg',
          messageContent: 'cached hello',
        );

        final repo = _SequencedChatRepository(
          responses: Queue.of([
            _messagePage(
              _apiMessage(
                id: 'cached-msg',
                convId: convId,
                content: 'cached hello',
                createdAt: '2026-06-15T08:00:00.000Z',
              ),
              _apiMessage(
                id: 'missed-msg',
                convId: convId,
                content: 'missed while disconnected',
                createdAt: '2026-06-15T08:05:00.000Z',
              ),
            ),
          ]),
        );
        final container = _createContainer(
          db: db,
          repository: repo,
          wsManager: _FakeWebSocketManager(
            initialState: WsConnectionState.connected,
          ),
        );
        addTearDown(container.dispose);

        await container.read(chatMessagesProvider(convId).future);

        await container
            .read(chatMessagesProvider(convId).notifier)
            .synchronizeAfterRealtimeReconnect();
        await _flushAsyncWork();

        expect(
          container
              .read(chatMessagesProvider(convId))
              .valueOrNull
              ?.map((message) => message.content)
              .toList(),
          ['missed while disconnected', 'cached hello'],
        );
      },
    );

    test(
      'reconnect request queues another room sync when entry sync is still running',
      () async {
        final db = _InMemoryAppDatabase();
        addTearDown(db.close);
        const convId = 'conv-race';

        await _seedConversation(
          db.chatDao,
          convId: convId,
          messageId: 'cached-msg',
          messageContent: 'cached hello',
        );

        final firstSync = Completer<Map<String, dynamic>>();
        final secondSync = Completer<Map<String, dynamic>>();
        final repo = _SequencedChatRepository(
          responseFutures: Queue.of([firstSync.future, secondSync.future]),
        );
        final container = _createContainer(
          db: db,
          repository: repo,
          wsManager: _FakeWebSocketManager(
            initialState: WsConnectionState.disconnected,
          ),
        );
        addTearDown(container.dispose);

        await container.read(chatMessagesProvider(convId).future);
        final notifier = container.read(chatMessagesProvider(convId).notifier);

        notifier.recoverRealtimeOnRoomEntry();
        await _flushAsyncWork();
        notifier.synchronizeAfterRealtimeReconnect();
        await _flushAsyncWork();

        firstSync.complete(
          _messagePage(
            _apiMessage(
              id: 'cached-msg',
              convId: convId,
              content: 'cached hello',
              createdAt: '2026-06-15T08:00:00.000Z',
            ),
          ),
        );
        await _flushAsyncWork();

        secondSync.complete(
          _messagePage(
            _apiMessage(
              id: 'cached-msg',
              convId: convId,
              content: 'cached hello',
              createdAt: '2026-06-15T08:00:00.000Z',
            ),
            _apiMessage(
              id: 'missed-msg',
              convId: convId,
              content: 'arrived after reconnect',
              createdAt: '2026-06-15T08:06:00.000Z',
            ),
          ),
        );
        await _flushAsyncWork();

        expect(repo.getMessagesCallCount, 2);
        expect(
          container
              .read(chatMessagesProvider(convId))
              .valueOrNull
              ?.map((message) => message.content)
              .toList(),
          ['arrived after reconnect', 'cached hello'],
        );
      },
    );

    test(
      'failed text dispatch stays pending, triggers recovery, and converges on ack',
      () async {
        final db = _InMemoryAppDatabase();
        addTearDown(db.close);
        const convId = 'conv-send-fail';

        await _seedConversation(
          db.chatDao,
          convId: convId,
          messageId: 'seed-msg',
          messageContent: 'seed',
        );

        final wsManager = _FakeWebSocketManager(
          initialState: WsConnectionState.disconnected,
          sendMessageResult: false,
        );
        final container = _createContainer(
          db: db,
          repository: _SequencedChatRepository(),
          wsManager: wsManager,
        );
        addTearDown(container.dispose);

        await container.read(chatMessagesProvider(convId).future);

        final notifier = container.read(chatMessagesProvider(convId).notifier);
        await notifier.sendMessage('hello realtime');
        await _flushAsyncWork();

        final messagesAfterSend = await db.chatDao.getMessages(convId);
        final pending = messagesAfterSend.firstWhere(
          (message) => message.id != 'seed-msg',
        );
        expect(pending.status, 'pending');
        expect(pending.retryCount, 1);
        expect(wsManager.ensureConnectedCount, 1);

        wsManager.emit('message_ack', {'id': pending.id});
        await _flushAsyncWork();

        final acknowledged = await db.chatDao.getMessage(pending.id);
        expect(acknowledged?.status, 'sent');
      },
    );
  });
}

ProviderContainer _createContainer({
  required _InMemoryAppDatabase db,
  required ChatRepository repository,
  required _FakeWebSocketManager wsManager,
}) {
  final key = ConversationEncryptionKey(
    convId: 'conv-send-fail',
    keyId: 'key-1',
    algorithm: 'AES-256-GCM',
    version: 1,
    material: base64Encode(Uint8List(32)),
  );

  return ProviderContainer(
    overrides: [
      authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
      chatDaoProvider.overrideWithValue(db.chatDao),
      chatRepositoryProvider.overrideWithValue(repository),
      webSocketManagerProvider.overrideWithValue(wsManager),
      conversationKeyRepositoryProvider.overrideWithValue(
        ConversationKeyRepository(
          repository,
          _MemoryConversationKeyStore(
            ConversationEncryptionKey.encodeList([key]),
          ),
        ),
      ),
      badgeSyncServiceProvider.overrideWithValue(
        BadgeSyncService(
          readUnreadCounts: () async => const [],
          manageBadgeLocallyOverride: false,
        ),
      ),
    ],
  );
}

Future<void> _seedConversation(
  ChatDao dao, {
  required String convId,
  required String messageId,
  required String messageContent,
}) async {
  await dao.insertConversation(
    LocalConversationsCompanion.insert(
      id: convId,
      createdBy: 'user-2',
      createdAt: DateTime.parse('2026-06-15T07:00:00.000Z'),
      type: const Value('GROUP'),
      name: const Value('Realtime Room'),
      lastMessageAt: Value(DateTime.parse('2026-06-15T07:30:00.000Z')),
      lastMessageContent: Value(messageContent),
      lastMessageSenderId: const Value('user-2'),
    ),
  );

  await dao.insertMessage(
    buildIncomingMessageCompanion({
      'id': messageId,
      'conv_id': convId,
      'sender_id': 'user-2',
      'type': 'text',
      'content': messageContent,
      'created_at': '2026-06-15T07:30:00.000Z',
      'deleted_at': null,
      'edited_at': null,
    }, defaultStatus: 'sent'),
  );
}

Map<String, dynamic> _messagePage(
  Map<String, dynamic> first, [
  Map<String, dynamic>? second,
]) {
  final messages = <Map<String, dynamic>>[first];
  if (second != null) {
    messages.add(second);
  }
  return {'messages': messages, 'nextCursor': null, 'hasMore': false};
}

Map<String, dynamic> _apiMessage({
  required String id,
  required String convId,
  required String content,
  required String createdAt,
}) {
  return {
    'id': id,
    'conv_id': convId,
    'sender_id': 'user-2',
    'type': 'text',
    'content': content,
    'created_at': createdAt,
    'edited_at': null,
    'deleted_at': null,
  };
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

class _MemoryConversationKeyStore implements ConversationKeyStore {
  _MemoryConversationKeyStore(this._value);

  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String value) async {
    _value = value;
  }
}

class _SequencedChatRepository extends ChatRepository {
  _SequencedChatRepository({
    Queue<Map<String, dynamic>>? responses,
    Queue<Future<Map<String, dynamic>>>? responseFutures,
  }) : _responses = responses ?? Queue<Map<String, dynamic>>(),
       _responseFutures =
           responseFutures ?? Queue<Future<Map<String, dynamic>>>(),
       super(Dio());

  final Queue<Map<String, dynamic>> _responses;
  final Queue<Future<Map<String, dynamic>>> _responseFutures;
  int getMessagesCallCount = 0;

  @override
  Future<Map<String, dynamic>> getMessages(
    String convId, {
    String? cursor,
    String dir = 'before',
    int limit = 30,
  }) {
    getMessagesCallCount++;
    if (_responseFutures.isNotEmpty) {
      return _responseFutures.removeFirst();
    }
    if (_responses.isNotEmpty) {
      return Future.value(_responses.removeFirst());
    }
    return Future.value(const {
      'messages': <Map<String, dynamic>>[],
      'nextCursor': null,
      'hasMore': false,
    });
  }
}

class _FakeWebSocketManager extends WebSocketManager {
  _FakeWebSocketManager({
    required WsConnectionState initialState,
    this.sendMessageResult = true,
  }) : _state = initialState,
       super(baseUrl: 'http://localhost', tokenProvider: () => '');

  final Map<String, List<WsEventHandler>> _handlers = {};
  final bool sendMessageResult;
  final StreamController<WsConnectionState> _stateController =
      StreamController<WsConnectionState>.broadcast();
  final WsConnectionState _state;
  int ensureConnectedCount = 0;

  @override
  WsConnectionState get state => _state;

  @override
  Stream<WsConnectionState> get stateStream => _stateController.stream;

  @override
  void on(String event, WsEventHandler handler) {
    _handlers.putIfAbsent(event, () => []).add(handler);
  }

  @override
  void off(String event, WsEventHandler handler) {
    _handlers[event]?.remove(handler);
  }

  @override
  void ensureConnected() {
    ensureConnectedCount++;
  }

  @override
  bool sendMessage(Map<String, dynamic> data, {String? id}) {
    return sendMessageResult;
  }

  @override
  bool sendMarkRead(String convId, String messageId) => true;

  @override
  bool sendMarkDelivered(String convId, String messageId, String senderId) =>
      true;

  void emit(String event, Map<String, dynamic> data) {
    final handlers = List<WsEventHandler>.from(_handlers[event] ?? const []);
    for (final handler in handlers) {
      handler(data);
    }
  }

  @override
  void dispose() {
    _stateController.close();
  }
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
