import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nineteen_tech_app/core/database/app_database.dart';
import 'package:nineteen_tech_app/core/router/chat_route_utils.dart';
import 'package:nineteen_tech_app/core/router/main_shell.dart';
import 'package:nineteen_tech_app/core/theme/app_theme.dart';
import 'package:nineteen_tech_app/features/auth/data/auth_repository.dart';
import 'package:nineteen_tech_app/features/auth/providers/auth_notifier.dart';
import 'package:nineteen_tech_app/features/chat/providers/chat_providers.dart';
import 'package:nineteen_tech_app/features/chat/screens/chat_list_screen.dart';

void main() {
  group('root tab helpers', () {
    test('maps root locations to the expected tab index for employees', () {
      expect(rootTabIndexForLocation('/chat', false), 0);
      expect(rootTabIndexForLocation('/hr', false), 1);
      expect(rootTabIndexForLocation('/tasks', false), 2);
      expect(rootTabIndexForLocation('/profile', false), 3);
      expect(rootTabIndexForLocation('/chat/123', false), 0);
      expect(rootTabIndexForLocation('/unknown', false), -1);
    });

    test('maps root locations to the expected tab index for admins', () {
      expect(rootTabIndexForLocation('/chat', true), 0);
      expect(rootTabIndexForLocation('/hr', true), 1);
      expect(rootTabIndexForLocation('/overview', true), 2);
      expect(rootTabIndexForLocation('/tasks', true), 3);
      expect(rootTabIndexForLocation('/profile', true), 4);
    });

    test('maps employee management tab only for authorized HR roles', () {
      expect(rootTabIndexForLocation('/employees', false), -1);
      expect(
        rootTabIndexForLocation('/employees', false, canManageEmployees: true),
        -1,
      );
      expect(
        rootTabIndexForLocation('/overview', true, canManageEmployees: true),
        2,
      );
      expect(
        rootTabIndexForLocation('/profile', true, canManageEmployees: true),
        4,
      );
      expect(
        rootTabIndexForLocation('/employees', true, canManageEmployees: true),
        -1,
      );
    });

    test('shows bottom navigation only on root tab pages', () {
      expect(shouldShowRootBottomNavigation('/chat', false), isTrue);
      expect(shouldShowRootBottomNavigation('/hr', false), isTrue);
      expect(shouldShowRootBottomNavigation('/tasks', false), isTrue);
      expect(shouldShowRootBottomNavigation('/profile', false), isTrue);
      expect(shouldShowRootBottomNavigation('/employees', false), isFalse);
      expect(
        shouldShowRootBottomNavigation(
          '/employees',
          false,
          canManageEmployees: true,
        ),
        isFalse,
      );
      expect(shouldShowRootBottomNavigation('/chat/123', false), isFalse);
      expect(shouldShowRootBottomNavigation('/hr/history', false), isFalse);
    });

    test('extracts the active chat conversation id from route locations', () {
      expect(conversationIdForChatLocation('/chat/conv-123'), 'conv-123');
      expect(conversationIdForChatLocation('/chat'), isNull);
      expect(conversationIdForChatLocation('/hr'), isNull);
    });
  });

  testWidgets('switches root tabs through the shell branch', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/chat',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              MainShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/chat',
                  builder: (context, state) =>
                      const _RootScreen(label: 'Chat Root'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/hr',
                  builder: (context, state) =>
                      const _RootScreen(label: 'HR Root'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/employees',
                  builder: (context, state) =>
                      const _RootScreen(label: 'Employees Root'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/overview',
                  builder: (context, state) =>
                      const _RootScreen(label: 'Overview Root'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/tasks',
                  builder: (context, state) =>
                      const _RootScreen(label: 'Tasks Root'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, state) =>
                      const _RootScreen(label: 'Profile Root'),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
        ],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chat Root'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/chat');

    await tester.tap(find.text('HR'));
    await tester.pump();

    expect(find.text('HR Root'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/hr');
  });

  testWidgets('keeps wide chat detail inside the shell right pane', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/chat',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              MainShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/chat',
                  builder: (context, state) => const SizedBox.shrink(),
                  routes: [
                    GoRoute(
                      path: ':id',
                      builder: (context, state) => Scaffold(
                        body: Center(
                          child: Text(
                            'Chat Detail: ${state.pathParameters['id']}',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/hr',
                  builder: (context, state) =>
                      const _RootScreen(label: 'HR Root'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/employees',
                  builder: (context, state) =>
                      const _RootScreen(label: 'Employees Root'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/overview',
                  builder: (context, state) =>
                      const _RootScreen(label: 'Overview Root'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/tasks',
                  builder: (context, state) =>
                      const _RootScreen(label: 'Tasks Root'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, state) =>
                      const _RootScreen(label: 'Profile Root'),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
          chatListProvider.overrideWith(
            () => _FakeChatListNotifier([
              LocalConversation(
                id: 'conv-123',
                type: 'GROUP',
                name: 'Design Team',
                avatarUrl: null,
                createdBy: 'user-1',
                lastMessageAt: DateTime(2026, 4, 24, 10, 0),
                createdAt: DateTime(2026, 4, 24, 9, 0),
                lastMessageContent: 'Xin chao',
                lastMessageSenderId: 'user-1',
                unreadCount: 0,
                unreadMentionCount: 0,
                otherMemberName: null,
                otherMemberAvatar: null,
                otherMemberLastSeenAt: null,
                lastViewedAt: DateTime(2026, 4, 24, 10, 0),
              ),
            ]),
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chọn cuộc trò chuyện'), findsOneWidget);
    expect(find.text('Design Team'), findsOneWidget);

    await tester.tap(find.text('Design Team'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/chat/conv-123');
    expect(find.text('Design Team'), findsOneWidget);
    expect(find.text('Chat Detail: conv-123'), findsOneWidget);
    expect(find.text('Chọn cuộc trò chuyện'), findsNothing);
  });

  testWidgets('hides bottom navigation on narrow chat detail routes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/chat/conv-123',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              MainShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/chat',
                  builder: (context, state) => const SizedBox.shrink(),
                  routes: [
                    GoRoute(
                      path: ':id',
                      builder: (context, state) => Scaffold(
                        body: Center(
                          child: Text(
                            'Chat Detail: ${state.pathParameters['id']}',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/hr',
                  builder: (context, state) =>
                      const _RootScreen(label: 'HR Root'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/employees',
                  builder: (context, state) =>
                      const _RootScreen(label: 'Employees Root'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/overview',
                  builder: (context, state) =>
                      const _RootScreen(label: 'Overview Root'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/tasks',
                  builder: (context, state) =>
                      const _RootScreen(label: 'Tasks Root'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, state) =>
                      const _RootScreen(label: 'Profile Root'),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
        ],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/chat/conv-123');
    expect(find.text('Chat Detail: conv-123'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('hides bottom navigation after opening a chat from mobile list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/chat',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              MainShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/chat',
                  builder: (context, state) => const ChatListScreen(),
                  routes: [
                    GoRoute(
                      path: ':id',
                      builder: (context, state) => Scaffold(
                        body: Center(
                          child: Text(
                            'Chat Detail: ${state.pathParameters['id']}',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/hr',
                  builder: (context, state) =>
                      const _RootScreen(label: 'HR Root'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/employees',
                  builder: (context, state) =>
                      const _RootScreen(label: 'Employees Root'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/overview',
                  builder: (context, state) =>
                      const _RootScreen(label: 'Overview Root'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/tasks',
                  builder: (context, state) =>
                      const _RootScreen(label: 'Tasks Root'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, state) =>
                      const _RootScreen(label: 'Profile Root'),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
          chatListProvider.overrideWith(
            () => _FakeChatListNotifier([
              LocalConversation(
                id: 'conv-123',
                type: 'GROUP',
                name: 'Design Team',
                avatarUrl: null,
                createdBy: 'user-1',
                lastMessageAt: DateTime(2026, 4, 24, 10, 0),
                createdAt: DateTime(2026, 4, 24, 9, 0),
                lastMessageContent: 'Xin chao',
                lastMessageSenderId: 'user-1',
                unreadCount: 0,
                unreadMentionCount: 0,
                otherMemberName: null,
                otherMemberAvatar: null,
                otherMemberLastSeenAt: null,
                lastViewedAt: DateTime(2026, 4, 24, 10, 0),
              ),
            ]),
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Design Team'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('Design Team'));
    await tester.pumpAndSettle();

    expect(find.text('Chat Detail: conv-123'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}

class _RootScreen extends StatelessWidget {
  const _RootScreen({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
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
