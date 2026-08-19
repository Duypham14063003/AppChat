import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/core/database/app_database.dart';
import 'package:nineteen_tech_app/core/theme/app_theme.dart';
import 'package:nineteen_tech_app/features/auth/data/auth_repository.dart';
import 'package:nineteen_tech_app/features/auth/providers/auth_notifier.dart';
import 'package:nineteen_tech_app/features/chat/data/chat_repository.dart';
import 'package:nineteen_tech_app/features/chat/providers/chat_providers.dart';
import 'package:nineteen_tech_app/features/chat/screens/group_info_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GroupInfoScreen membership controls', () {
    testWidgets('shows add button and creator-only remove controls', (
      tester,
    ) async {
      await _pumpGroupInfoScreen(tester, currentUserRole: 'creator');

      expect(find.text('Thêm'), findsOneWidget);
      expect(find.byTooltip('Xóa thành viên'), findsWidgets);
      await _scrollToBottom(tester);
      expect(find.text('Rời nhóm'), findsOneWidget);
      expect(find.text('Xóa nhóm'), findsOneWidget);
    });

    testWidgets('shows add button but hides remove controls for admin', (
      tester,
    ) async {
      await _pumpGroupInfoScreen(tester, currentUserRole: 'admin');

      expect(find.text('Thêm'), findsOneWidget);
      expect(find.byTooltip('Xóa thành viên'), findsNothing);
      await _scrollToBottom(tester);
      expect(find.text('Rời nhóm'), findsOneWidget);
      expect(find.text('Xóa nhóm'), findsNothing);
    });

    testWidgets('shows add button but hides remove controls for member', (
      tester,
    ) async {
      await _pumpGroupInfoScreen(tester, currentUserRole: 'member');

      expect(find.text('Thêm'), findsOneWidget);
      expect(find.byTooltip('Xóa thành viên'), findsNothing);
      await _scrollToBottom(tester);
      expect(find.text('Rời nhóm'), findsOneWidget);
      expect(find.text('Xóa nhóm'), findsNothing);
    });
  });
}

Future<void> _pumpGroupInfoScreen(
  WidgetTester tester, {
  required String currentUserRole,
}) async {
  const conversationId = 'conv-1';
  final conversation = LocalConversation(
    id: conversationId,
    type: 'GROUP',
    name: 'Backend Team',
    avatarUrl: null,
    createdBy: 'user-1',
    lastMessageAt: null,
    createdAt: DateTime(2026, 7, 13, 8),
    lastMessageContent: null,
    lastMessageSenderId: null,
    unreadCount: 0,
    unreadMentionCount: 0,
    otherMemberName: null,
    otherMemberAvatar: null,
    otherMemberLastSeenAt: null,
    lastViewedAt: null,
  );
  final members = <String, Map<String, String?>>{
    'user-1': {'name': 'Tester', 'avatar': null, 'role': currentUserRole},
    'user-2': {'name': 'Alice', 'avatar': null, 'role': 'admin'},
    'user-3': {'name': 'Bob', 'avatar': null, 'role': 'member'},
  };

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
        chatRepositoryProvider.overrideWithValue(_FakeChatRepository()),
        conversationDetailProvider(
          conversationId,
        ).overrideWith((ref) async => conversation),
        conversationMembersProvider(
          conversationId,
        ).overrideWith((ref) async => members),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const GroupInfoScreen(conversationId: conversationId),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> _scrollToBottom(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
  await tester.pumpAndSettle();
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
  Future<Object?> getConversationMedia({
    required String convId,
    String? cursor,
    int limit = 20,
    String type = 'all',
  }) async {
    return const [];
  }

  @override
  Future<Object?> getConversationFiles({
    required String convId,
    String? cursor,
    int limit = 20,
  }) async {
    return const [];
  }

  @override
  Future<Object?> getConversationLinks({
    required String convId,
    String? cursor,
    int limit = 20,
  }) async {
    return const [];
  }

  @override
  Future<Map<String, dynamic>> getConversationAssetsSummary({
    required String convId,
  }) async {
    return const {
      'members_count': 3,
      'media_count': 0,
      'files_count': 0,
      'links_count': 0,
    };
  }
}
