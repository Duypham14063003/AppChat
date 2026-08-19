import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nineteen_tech_app/core/database/app_database.dart';
import 'package:nineteen_tech_app/core/database/chat_dao.dart';
import 'package:nineteen_tech_app/core/theme/app_theme.dart';
import 'package:nineteen_tech_app/features/auth/data/auth_repository.dart';
import 'package:nineteen_tech_app/features/auth/providers/auth_notifier.dart';
import 'package:nineteen_tech_app/features/chat/data/chat_repository.dart';
import 'package:nineteen_tech_app/features/chat/providers/chat_providers.dart';
import 'package:nineteen_tech_app/features/chat/screens/chat_list_screen.dart';
import 'package:nineteen_tech_app/features/chat/screens/global_bookmarked_messages_screen.dart';

void main() {
  group('globalBookmarkedMessagesProvider', () {
    test('returns cached items before API refresh completes', () async {
      final completer = Completer<GlobalBookmarkedMessagesPage>();
      final dao = _FakeChatDao(
        globalBookmarksCache: [
          _globalBookmarkRow(
            messageId: 'msg-cached',
            messageContent: 'Cached note',
            markedAt: '2026-04-24T11:00:00.000Z',
          ),
        ],
      );
      final repo = _FakeChatRepository(globalBookmarksCompleter: completer);
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
          chatDaoProvider.overrideWithValue(dao),
          chatRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final initial = await container.read(
        globalBookmarkedMessagesProvider(GlobalBookmarkFilter.all).future,
      );

      expect(initial.items.single.messageId, 'msg-cached');
      expect(initial.items.single.messageContent, 'Cached note');

      completer.complete(
        GlobalBookmarkedMessagesPage(
          items: [
            BookmarkedMessageData(
              messageId: 'msg-fresh',
              convId: 'conv-1',
              userId: 'user-1',
              markedAt: DateTime(2026, 4, 24, 10, 0),
              messageContent: 'Fresh note',
              senderName: 'Jane Doe',
              conversationType: 'DIRECT',
              conversationName: 'Jane Doe',
            ),
          ],
          nextCursor: 'cursor-1',
          hasMore: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final refreshed = container
          .read(globalBookmarkedMessagesProvider(GlobalBookmarkFilter.all))
          .valueOrNull;

      expect(repo.lastFilter, GlobalBookmarkFilter.all);
      expect(refreshed?.items.single.messageId, 'msg-fresh');
      expect(refreshed?.items.single.messageContent, 'Fresh note');
      expect(refreshed?.hasMore, isTrue);
      expect(refreshed?.nextCursor, 'cursor-1');
      expect(dao.deletedBookmarkKeys, contains('conv-1:msg-cached'));
    });

    test('maps selected filter to local and remote inbox queries', () async {
      final dao = _FakeChatDao(
        globalBookmarksCache: [
          _globalBookmarkRow(
            messageId: 'msg-group',
            conversationType: 'GROUP',
            conversationName: 'Design Team',
          ),
        ],
      );
      final repo = _FakeChatRepository(
        globalBookmarksPage: const GlobalBookmarkedMessagesPage(
          items: [],
          nextCursor: null,
          hasMore: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
          chatDaoProvider.overrideWithValue(dao),
          chatRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(
        globalBookmarkedMessagesProvider(GlobalBookmarkFilter.group).future,
      );
      await Future<void>.delayed(Duration.zero);

      expect(dao.lastGlobalConversationType, 'GROUP');
      expect(repo.lastFilter, GlobalBookmarkFilter.group);
    });

    test(
      'prunes first-page cache with UUID-aware ordering when marked_at ties',
      () async {
        final dao = _FakeChatDao(
          globalBookmarksCache: [
            _globalBookmarkRow(
              messageId: '00000000-0000-0000-0000-000000000003',
              markedAt: '2026-04-24T10:00:00.000Z',
            ),
            _globalBookmarkRow(
              messageId: '00000000-0000-0000-0000-000000000002',
              markedAt: '2026-04-24T10:00:00.000Z',
            ),
            _globalBookmarkRow(
              messageId: '00000000-0000-0000-0000-000000000001',
              markedAt: '2026-04-24T10:00:00.000Z',
            ),
          ],
        );

        await pruneGlobalBookmarkFirstPageCache(
          dao: dao,
          userId: 'user-1',
          page: GlobalBookmarkedMessagesPage(
            items: [
              BookmarkedMessageData(
                messageId: '00000000-0000-0000-0000-000000000002',
                convId: 'conv-1',
                userId: 'user-1',
                markedAt: DateTime.parse('2026-04-24T10:00:00.000Z'),
              ),
            ],
            nextCursor: 'cursor-1',
            hasMore: true,
          ),
        );

        expect(
          dao.deletedBookmarkKeys,
          contains('conv-1:00000000-0000-0000-0000-000000000003'),
        );
        expect(
          dao.deletedBookmarkKeys,
          isNot(contains('conv-1:00000000-0000-0000-0000-000000000001')),
        );
      },
    );
  });

  group('global bookmark inbox navigation', () {
    testWidgets('opens saved-messages inbox from the chat list header', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/chat',
        routes: [
          GoRoute(
            path: '/chat',
            builder: (context, state) => const ChatListScreen(),
          ),
          GoRoute(
            path: '/bookmarks',
            builder: (context, state) => const GlobalBookmarkedMessagesScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        _buildTestRouterApp(
          router,
          dao: _FakeChatDao(),
          repo: _FakeChatRepository(
            globalBookmarksPage: const GlobalBookmarkedMessagesPage(
              items: [],
              nextCursor: null,
              hasMore: false,
            ),
          ),
          conversations: const [],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Tin nhắn đã lưu'));
      await tester.pumpAndSettle();

      expect(find.text('Tin nhắn đã lưu'), findsOneWidget);
    });

    testWidgets('tapping a saved item routes to the source message', (
      tester,
    ) async {
      final completer = Completer<GlobalBookmarkedMessagesPage>();
      final router = GoRouter(
        initialLocation: '/bookmarks',
        routes: [
          GoRoute(
            path: '/bookmarks',
            builder: (context, state) => const GlobalBookmarkedMessagesScreen(),
          ),
          GoRoute(
            path: '/chat/:id',
            builder: (context, state) => Scaffold(
              body: Text(
                'chat:${state.pathParameters['id']}:${state.uri.queryParameters['messageId']}',
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        _buildTestRouterApp(
          router,
          dao: _FakeChatDao(
            globalBookmarksCache: [
              _globalBookmarkRow(
                conversationName: 'Design Team',
                conversationType: 'GROUP',
                messageId: 'msg-1',
                messageContent: 'Pinned idea',
              ),
            ],
          ),
          repo: _FakeChatRepository(globalBookmarksCompleter: completer),
          conversations: const [],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Design Team'));
      await tester.pumpAndSettle();

      expect(find.text('chat:conv-1:msg-1'), findsOneWidget);
    });

    testWidgets(
      'saved-message inbox updates the messageId when re-targeting the same conversation',
      (tester) async {
        final completer = Completer<GlobalBookmarkedMessagesPage>();
        final router = GoRouter(
          initialLocation: '/chat/conv-1?messageId=msg-1',
          routes: [
            GoRoute(
              path: '/chat/:id',
              builder: (context, state) => Scaffold(
                body: Column(
                  children: [
                    Text(
                      'chat:${state.pathParameters['id']}:${state.uri.queryParameters['messageId']}',
                    ),
                    const Expanded(child: GlobalBookmarkedMessagesScreen()),
                  ],
                ),
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          _buildTestRouterApp(
            router,
            dao: _FakeChatDao(
              globalBookmarksCache: [
                _globalBookmarkRow(
                  conversationName: 'Design Team',
                  conversationType: 'GROUP',
                  messageId: 'msg-2',
                  messageContent: 'Pinned idea',
                ),
              ],
            ),
            repo: _FakeChatRepository(globalBookmarksCompleter: completer),
            conversations: const [],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('chat:conv-1:msg-1'), findsOneWidget);

        await tester.tap(find.text('Design Team'));
        await tester.pumpAndSettle();

        expect(find.text('chat:conv-1:msg-2'), findsOneWidget);
      },
    );
  });
}

Widget _buildTestRouterApp(
  GoRouter router, {
  required _FakeChatDao dao,
  required _FakeChatRepository repo,
  required List<LocalConversation> conversations,
}) {
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
      chatDaoProvider.overrideWithValue(dao),
      chatRepositoryProvider.overrideWithValue(repo),
      chatListProvider.overrideWith(() => _FakeChatListNotifier(conversations)),
    ],
    child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
  );
}

Map<String, dynamic> _globalBookmarkRow({
  String messageId = 'msg-1',
  String messageContent = 'Saved note',
  String conversationType = 'DIRECT',
  String conversationName = 'Jane Doe',
  String markedAt = '2026-04-24T10:00:00.000Z',
}) {
  return {
    'user_id': 'user-1',
    'conv_id': 'conv-1',
    'message_id': messageId,
    'marked_at': markedAt,
    'message_content': messageContent,
    'message_type': 'text',
    'sender_id': 'user-2',
    'sender_name': 'Jane Doe',
    'message_created_at': '2026-04-24T09:30:00.000Z',
    'conversation_type': conversationType,
    'conversation_name': conversationName,
    'conversation_avatar_url': null,
  };
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

class _FakeChatListNotifier extends ChatListNotifier {
  _FakeChatListNotifier(this.conversations);

  final List<LocalConversation> conversations;

  @override
  Future<List<LocalConversation>> build() async => conversations;
}

class _FakeChatRepository extends ChatRepository {
  _FakeChatRepository({this.globalBookmarksPage, this.globalBookmarksCompleter})
    : super(Dio());

  final GlobalBookmarkedMessagesPage? globalBookmarksPage;
  final Completer<GlobalBookmarkedMessagesPage>? globalBookmarksCompleter;
  GlobalBookmarkFilter? lastFilter;
  String? lastCursor;
  int? lastLimit;

  @override
  Future<GlobalBookmarkedMessagesPage> getGlobalBookmarkedMessages({
    GlobalBookmarkFilter filter = GlobalBookmarkFilter.all,
    String? cursor,
    int limit = 20,
  }) async {
    lastFilter = filter;
    lastCursor = cursor;
    lastLimit = limit;
    if (globalBookmarksCompleter != null) {
      return globalBookmarksCompleter!.future;
    }
    return globalBookmarksPage ??
        const GlobalBookmarkedMessagesPage(
          items: [],
          nextCursor: null,
          hasMore: false,
        );
  }
}

class _FakeChatDao extends ChatDao {
  _FakeChatDao({
    List<LocalBookmarkedMessage>? conversationBookmarks,
    List<Map<String, dynamic>>? globalBookmarksCache,
  }) : _conversationBookmarks = conversationBookmarks ?? const [],
       _globalBookmarksCache = globalBookmarksCache ?? const [],
       super(_FakeAppDatabase());

  final List<LocalBookmarkedMessage> _conversationBookmarks;
  final List<Map<String, dynamic>> _globalBookmarksCache;
  String? lastGlobalConversationType;
  final List<LocalBookmarkedMessagesCompanion> insertedBookmarks = [];
  final List<String> deletedBookmarkKeys = [];
  int deleteAllForUserCallCount = 0;

  @override
  Future<List<LocalBookmarkedMessage>> getBookmarkedMessages(
    String userId,
    String convId,
  ) async {
    return _conversationBookmarks
        .where(
          (bookmark) => bookmark.userId == userId && bookmark.convId == convId,
        )
        .toList(growable: false);
  }

  @override
  Future<void> deleteAllBookmarkedMessages(
    String userId,
    String convId,
  ) async {}

  @override
  Future<void> deleteBookmarkedMessage(
    String userId,
    String convId,
    String messageId,
  ) async {
    deletedBookmarkKeys.add('$convId:$messageId');
  }

  @override
  Future<void> insertBookmarkedMessage(
    LocalBookmarkedMessagesCompanion entry,
  ) async {
    insertedBookmarks.add(entry);
  }

  @override
  Future<List<Map<String, dynamic>>> getGlobalBookmarkedMessages(
    String userId, {
    String? conversationType,
    int limit = 20,
  }) async {
    lastGlobalConversationType = conversationType;
    final rows = _globalBookmarksCache
        .where(
          (row) =>
              conversationType == null ||
              row['conversation_type'] == conversationType,
        )
        .take(limit)
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
    return rows;
  }

  @override
  Future<List<LocalBookmarkedMessage>> getAllBookmarkedMessagesForUser(
    String userId,
  ) async {
    return _globalBookmarksCache
        .where((row) => row['user_id'] == userId)
        .map(
          (row) => LocalBookmarkedMessage(
            convId: row['conv_id'] as String,
            messageId: row['message_id'] as String,
            userId: row['user_id'] as String,
            markedAt: DateTime.parse(row['marked_at'] as String),
            messageContent: row['message_content'] as String?,
            messageType: row['message_type'] as String?,
            senderId: row['sender_id'] as String?,
            senderName: row['sender_name'] as String?,
            messageCreatedAt: DateTime.parse(
              row['message_created_at'] as String,
            ),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> deleteAllBookmarkedMessagesForUser(String userId) async {
    deleteAllForUserCallCount += 1;
  }
}

class _FakeAppDatabase extends Fake implements AppDatabase {
  _FakeAppDatabase()
    : _connection = DatabaseConnection(NativeDatabase.memory());

  final DatabaseConnection _connection;

  @override
  DatabaseConnection get connection => _connection;
}
