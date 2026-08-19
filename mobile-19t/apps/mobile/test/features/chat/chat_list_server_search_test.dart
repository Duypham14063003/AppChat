import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nineteen_tech_app/core/database/app_database.dart';
import 'package:nineteen_tech_app/core/theme/app_theme.dart';
import 'package:nineteen_tech_app/features/auth/data/auth_repository.dart';
import 'package:nineteen_tech_app/features/auth/providers/auth_notifier.dart';
import 'package:nineteen_tech_app/features/chat/data/chat_repository.dart';
import 'package:nineteen_tech_app/features/chat/providers/chat_providers.dart';
import 'package:nineteen_tech_app/features/chat/screens/chat_list_screen.dart';

void main() {
  group('serverSearchNotifierProvider', () {
    test('ignores stale responses from older queries', () async {
      final hiCompleter = Completer<Map<String, dynamic>>();
      final helloCompleter = Completer<Map<String, dynamic>>();
      final repo = _FakeChatRepository(
        onSearchMessages:
            ({required String query, String? cursor, required int limit}) {
              if (query == 'hi') return hiCompleter.future;
              return helloCompleter.future;
            },
      );
      final container = ProviderContainer(
        overrides: [chatRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      unawaited(
        container.read(serverSearchNotifierProvider.notifier).search('hi'),
      );
      unawaited(
        container.read(serverSearchNotifierProvider.notifier).search('hello'),
      );

      helloCompleter.complete(
        _searchResponse([
          _searchResult(
            id: 'msg-new',
            content: 'hello world',
            snippet: '<mark>hello</mark> world',
          ),
        ]),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      hiCompleter.complete(
        _searchResponse([
          _searchResult(
            id: 'msg-old',
            content: 'hi world',
            snippet: '<mark>hi</mark> world',
          ),
        ]),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(serverSearchNotifierProvider);
      expect(state.query, 'hello');
      expect(state.results.single.messageId, 'msg-new');
    });
  });

  group('ChatListScreen server search', () {
    testWidgets('debounces API search and ignores queries shorter than 2', (
      tester,
    ) async {
      final repo = _FakeChatRepository(
        onSearchMessages:
            ({
              required String query,
              String? cursor,
              required int limit,
            }) async => _searchResponse([]),
      );

      await tester.pumpWidget(_buildTestApp(repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Tìm kiếm'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'h');
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.searchCalls, isEmpty);

      await tester.enterText(find.byType(TextField), 'hi');
      await tester.pump(const Duration(milliseconds: 299));
      expect(repo.searchCalls, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();

      expect(repo.searchCalls.length, 1);
      expect(repo.searchCalls.single.query, 'hi');
    });

    testWidgets('renders loading, empty, and error states from server search', (
      tester,
    ) async {
      final loadingCompleter = Completer<Map<String, dynamic>>();
      var requestCount = 0;
      final repo = _FakeChatRepository(
        onSearchMessages:
            ({required String query, String? cursor, required int limit}) {
              requestCount += 1;
              if (requestCount == 1) {
                return loadingCompleter.future;
              }
              throw DioException(
                requestOptions: RequestOptions(path: '/search/messages'),
              );
            },
      );

      await tester.pumpWidget(_buildTestApp(repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Tìm kiếm'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'hi');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      loadingCompleter.complete(_searchResponse([]));
      await tester.pumpAndSettle();

      expect(find.text('Không tìm thấy tin nhắn phù hợp'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'bug');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Không thể tải kết quả tìm kiếm'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });

    testWidgets('maps server results, paginates, and retries load more', (
      tester,
    ) async {
      final repo = _FakeChatRepository(
        onSearchMessages:
            ({
              required String query,
              String? cursor,
              required int limit,
            }) async {
              if (cursor == null) {
                return _searchResponse(
                  [
                    _searchResult(
                      id: 'msg-1',
                      convId: 'conv-1',
                      convName: 'Nguyễn Tất Hiên',
                      convType: 'GROUP',
                      senderName: 'Văn An',
                      content: 'hi raw content',
                      snippet: '',
                    ),
                  ],
                  nextCursor: 'cursor-1',
                  hasMore: true,
                );
              }
              if (cursor == 'cursor-1') {
                return _searchResponse([
                  _searchResult(
                    id: 'msg-2',
                    convId: 'conv-1',
                    convName: 'Báo cáo hàng ngày',
                    senderName: 'Báo cáo hàng ngày',
                    content: 'follow up',
                    snippet: '<mark>follow</mark> up',
                  ),
                ], hasMore: false);
              }
              throw DioException(
                requestOptions: RequestOptions(path: '/search/messages'),
              );
            },
      );

      await tester.pumpWidget(_buildTestApp(repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Tìm kiếm'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'hi');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Tất cả tin nhắn'), findsOneWidget);
      expect(find.text('Nguyễn Tất Hiên'), findsOneWidget);
      expect(find.text('Văn An:'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('hi raw content'),
        ),
        findsOneWidget,
      );
      expect(find.text('Tải thêm'), findsOneWidget);

      await tester.tap(find.text('Tải thêm'));
      await tester.pumpAndSettle();

      expect(repo.searchCalls.length, 2);
      expect(repo.searchCalls.last.cursor, 'cursor-1');
      expect(find.text('Báo cáo hàng ngày'), findsOneWidget);
      expect(find.text('Tải thêm'), findsNothing);
    });

    testWidgets('tapping a result opens the target conversation message', (
      tester,
    ) async {
      final repo = _FakeChatRepository(
        onSearchMessages:
            ({
              required String query,
              String? cursor,
              required int limit,
            }) async => _searchResponse([
              _searchResult(
                id: 'msg-1',
                convId: 'conv-42',
                convName: 'Văn An',
                senderName: 'Văn An',
                content: 'hello there',
                snippet: '<mark>hello</mark> there',
              ),
            ]),
      );
      final router = GoRouter(
        initialLocation: '/chat',
        routes: [
          GoRoute(
            path: '/chat',
            builder: (context, state) => const ChatListScreen(),
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

      await tester.pumpWidget(_buildRouterApp(router: router, repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Tìm kiếm'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Văn An'));
      await tester.pumpAndSettle();

      expect(find.text('chat:conv-42:msg-1'), findsOneWidget);
    });

    testWidgets(
      'embedded search updates the messageId when re-targeting the same conversation',
      (tester) async {
        final repo = _FakeChatRepository(
          onSearchMessages:
              ({
                required String query,
                String? cursor,
                required int limit,
              }) async => _searchResponse([
                _searchResult(
                  id: 'msg-2',
                  convId: 'conv-42',
                  convName: 'Văn An',
                  senderName: 'Văn An',
                  content: 'follow up',
                  snippet: '<mark>follow</mark> up',
                ),
              ]),
        );
        final router = GoRouter(
          initialLocation: '/chat/conv-42?messageId=msg-1',
          routes: [
            GoRoute(
              path: '/chat/:id',
              builder: (context, state) => Scaffold(
                body: Column(
                  children: [
                    Text(
                      'chat:${state.pathParameters['id']}:${state.uri.queryParameters['messageId']}',
                    ),
                    const Expanded(
                      child: ChatListScreen(
                        isEmbedded: true,
                        selectedConversationId: 'conv-42',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

        await tester.pumpWidget(_buildRouterApp(router: router, repo: repo));
        await tester.pumpAndSettle();

        expect(find.text('chat:conv-42:msg-1'), findsOneWidget);

        await tester.tap(find.byTooltip('Tìm kiếm'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'follow');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Văn An'));
        await tester.pumpAndSettle();

        expect(find.text('chat:conv-42:msg-2'), findsOneWidget);
      },
    );

    testWidgets('closing search returns to the normal chat list', (
      tester,
    ) async {
      final repo = _FakeChatRepository(
        onSearchMessages:
            ({
              required String query,
              String? cursor,
              required int limit,
            }) async => _searchResponse([
              _searchResult(
                id: 'msg-1',
                convId: 'conv-42',
                convName: 'Kết quả search',
                senderName: 'Kết quả search',
                content: 'hello there',
                snippet: '<mark>hello</mark> there',
              ),
            ]),
      );

      await tester.pumpWidget(
        _buildTestApp(
          repo: repo,
          conversations: [
            LocalConversation(
              id: 'conv-local',
              type: 'DIRECT',
              name: null,
              avatarUrl: null,
              createdBy: 'user-2',
              otherMemberName: 'Chat của tôi',
              otherMemberAvatar: null,
              otherMemberLastSeenAt: null,
              lastMessageAt: DateTime.parse('2026-05-04T06:00:00.000Z'),
              createdAt: DateTime.parse('2026-05-04T05:00:00.000Z'),
              lastMessageContent: 'Tin nhắn gần nhất',
              lastMessageSenderId: 'user-2',
              unreadCount: 0,
              unreadMentionCount: 0,
              lastViewedAt: null,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Tìm kiếm'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Kết quả search'), findsOneWidget);

      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();

      expect(find.text('Chat của tôi'), findsOneWidget);
      expect(find.text('Kết quả search'), findsNothing);
    });
  });
}

Widget _buildTestApp({
  required _FakeChatRepository repo,
  List<LocalConversation> conversations = const [],
}) {
  return _buildRouterApp(
    router: GoRouter(
      initialLocation: '/chat',
      routes: [
        GoRoute(
          path: '/chat',
          builder: (context, state) => const ChatListScreen(),
        ),
      ],
    ),
    repo: repo,
    conversations: conversations,
  );
}

Widget _buildRouterApp({
  required GoRouter router,
  required _FakeChatRepository repo,
  List<LocalConversation> conversations = const [],
}) {
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
      chatRepositoryProvider.overrideWithValue(repo),
      chatListProvider.overrideWith(() => _FakeChatListNotifier(conversations)),
    ],
    child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
  );
}

Map<String, dynamic> _searchResponse(
  List<Map<String, dynamic>> results, {
  String? nextCursor,
  bool hasMore = false,
}) {
  return {'results': results, 'next_cursor': nextCursor, 'has_more': hasMore};
}

Map<String, dynamic> _searchResult({
  required String id,
  String convId = 'conv-1',
  String convName = 'Conversation',
  String convType = 'DIRECT',
  String? senderName,
  String content = 'content',
  String snippet = '<mark>content</mark>',
}) {
  return {
    'id': id,
    'conv_id': convId,
    'sender_id': 'sender-1',
    'type': 'text',
    'content': content,
    'created_at': '2026-05-04T06:00:00.000Z',
    'snippet': snippet,
    'conv_name': convName,
    'conv_type': convType,
    'conv_avatar_url': null,
    'sender_name': senderName,
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
  _FakeChatRepository({required this.onSearchMessages}) : super(Dio());

  final Future<Map<String, dynamic>> Function({
    required String query,
    String? cursor,
    required int limit,
  })
  onSearchMessages;

  final List<_SearchCall> searchCalls = [];

  @override
  Future<Map<String, dynamic>> searchMessages({
    required String query,
    String? convId,
    String? cursor,
    int limit = 20,
  }) {
    searchCalls.add(_SearchCall(query: query, cursor: cursor, limit: limit));
    return onSearchMessages(query: query, cursor: cursor, limit: limit);
  }
}

class _SearchCall {
  const _SearchCall({
    required this.query,
    required this.cursor,
    required this.limit,
  });

  final String query;
  final String? cursor;
  final int limit;
}
