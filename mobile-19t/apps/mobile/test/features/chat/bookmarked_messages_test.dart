import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/core/database/app_database.dart';
import 'package:nineteen_tech_app/core/theme/app_theme.dart';
import 'package:nineteen_tech_app/features/chat/providers/chat_providers.dart';
import 'package:nineteen_tech_app/features/chat/widgets/message_context_menu.dart';

void main() {
  group('bookmark helpers', () {
    test('parses bookmark payloads from the backend', () {
      final bookmark = bookmarkedMessageFromJson({
        'message_id': 'msg-1',
        'user_id': 'user-1',
        'marked_at': '2026-04-21T10:30:00.000Z',
        'message_content': 'Important note',
        'message_type': 'text',
        'sender_id': 'user-2',
        'sender_name': 'Jane Doe',
        'message_created_at': '2026-04-20T09:00:00.000Z',
      }, 'conv-1');

      expect(bookmark.messageId, 'msg-1');
      expect(bookmark.convId, 'conv-1');
      expect(bookmark.userId, 'user-1');
      expect(bookmark.messageContent, 'Important note');
      expect(bookmark.senderName, 'Jane Doe');
      expect(
        bookmark.messageCreatedAt,
        DateTime.parse('2026-04-20T09:00:00.000Z'),
      );
    });

    test('builds a drift companion from bookmark data', () {
      final bookmark = BookmarkedMessageData(
        messageId: 'msg-1',
        convId: 'conv-1',
        userId: 'user-1',
        markedAt: DateTime.parse('2026-04-21T10:30:00.000Z'),
        messageContent: 'Important note',
        messageType: 'text',
        senderId: 'user-2',
        senderName: 'Jane Doe',
        messageCreatedAt: DateTime.parse('2026-04-20T09:00:00.000Z'),
      );

      final companion = buildBookmarkedMessageCompanion(bookmark);

      expect(companion.convId.value, 'conv-1');
      expect(companion.messageId.value, 'msg-1');
      expect(companion.userId.value, 'user-1');
      expect(companion.messageContent.value, 'Important note');
      expect(companion.senderName.value, 'Jane Doe');
    });
  });

  group('message context menu bookmark action', () {
    testWidgets('shows bookmark action for unbookmarked messages', (
      tester,
    ) async {
      await tester.pumpWidget(const _MenuHarness(isBookmarked: false));

      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();

      expect(find.text('Đánh dấu tin nhắn'), findsOneWidget);
      expect(find.text('Bỏ đánh dấu'), findsNothing);
    });

    testWidgets('shows unbookmark action for bookmarked messages', (
      tester,
    ) async {
      await tester.pumpWidget(const _MenuHarness(isBookmarked: true));

      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();

      expect(find.text('Bỏ đánh dấu'), findsOneWidget);
      expect(find.text('Đánh dấu tin nhắn'), findsNothing);
    });

    testWidgets('shows edit and recall for my text message', (tester) async {
      await tester.pumpWidget(
        const _MenuHarness(isBookmarked: false, isMine: true),
      );

      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();

      expect(find.text('Sửa'), findsOneWidget);
      expect(find.text('Thu hồi'), findsOneWidget);
      expect(find.text('Sao chép'), findsOneWidget);
    });

    testWidgets('shows recall but not edit for my non-text message', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _MenuHarness(
          isBookmarked: false,
          isMine: true,
          messageType: 'image',
        ),
      );

      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();

      expect(find.text('Thu hồi'), findsOneWidget);
      expect(find.text('Sửa'), findsNothing);
    });

    testWidgets('hides edit and recall for someone else message', (
      tester,
    ) async {
      await tester.pumpWidget(const _MenuHarness(isBookmarked: false));

      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();

      expect(find.text('Sửa'), findsNothing);
      expect(find.text('Thu hồi'), findsNothing);
    });

    testWidgets('hides copy for text messages without copyable content', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _MenuHarness(isBookmarked: false, isMine: true, content: null),
      );

      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();

      expect(find.text('Sao chép'), findsNothing);
    });
  });
}

class _MenuHarness extends StatelessWidget {
  final bool isBookmarked;
  final bool isMine;
  final String messageType;
  final String? content;

  const _MenuHarness({
    required this.isBookmarked,
    this.isMine = false,
    this.messageType = 'text',
    this.content = 'hello',
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () {
                showMessageContextMenu(
                  context: context,
                  message: _message(type: messageType, content: content),
                  isMine: isMine,
                  conversationId: 'conv-1',
                  conversationType: 'DIRECT',
                  userRole: null,
                  isPinned: false,
                  isBookmarked: isBookmarked,
                  onReaction: (_) {},
                  onPin: () {},
                  onUnpin: () {},
                  onBookmark: () {},
                  onUnbookmark: () {},
                  onReply: () {},
                  onCopy: () {},
                  onForward: () {},
                  onEdit: () {},
                  onRecall: () {},
                );
              },
              child: const Text('Open menu'),
            ),
          ),
        ),
      ),
    );
  }
}

LocalMessage _message({String type = 'text', String? content = 'hello'}) {
  return LocalMessage(
    id: 'msg-1',
    convId: 'conv-1',
    senderId: 'user-2',
    type: type,
    content: content,
    createdAt: DateTime(2026, 4, 21, 10, 0),
    status: 'sent',
    retryCount: 0,
  );
}
