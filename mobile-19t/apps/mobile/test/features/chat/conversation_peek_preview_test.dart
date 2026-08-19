import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/core/database/app_database.dart';
import 'package:nineteen_tech_app/core/theme/app_theme.dart';
import 'package:nineteen_tech_app/features/chat/widgets/conversation_peek_preview.dart';
import 'package:nineteen_tech_app/features/chat/widgets/conversation_tile.dart';

void main() {
  testWidgets('long press opens peek preview and open chat action fires', (
    tester,
  ) async {
    var openedChat = false;
    late BuildContext tileContext;
    final conversation = _conversation();
    final previewMessages = [
      _message(
        id: 'msg-1',
        senderId: 'user-2',
        content: 'Tin nhắn xem trước',
        createdAt: DateTime(2026, 4, 22, 10, 0),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                tileContext = context;
                return ConversationTile(
                  conversation: conversation,
                  currentUserId: 'user-1',
                  onTap: () {},
                  onLongPress: () => showConversationPeekPreview(
                    context: tileContext,
                    conversation: conversation,
                    currentUserId: 'user-1',
                    onOpenChat: () => openedChat = true,
                    previewMessagesOverride: AsyncValue.data(previewMessages),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.byType(ConversationTile));
    await tester.pumpAndSettle();

    expect(find.text('Tin nhắn xem trước'), findsOneWidget);
    expect(find.text('Mở chat'), findsOneWidget);

    await tester.tap(find.text('Mở chat'));
    await tester.pumpAndSettle();

    expect(openedChat, isTrue);
    expect(find.text('Tin nhắn xem trước'), findsNothing);
  });
}

LocalConversation _conversation() {
  return LocalConversation(
    id: 'conv-1',
    type: 'DIRECT',
    name: null,
    avatarUrl: null,
    createdBy: 'user-2',
    lastMessageAt: DateTime(2026, 4, 22, 10, 0),
    createdAt: DateTime(2026, 4, 20, 9, 0),
    lastMessageContent: 'Xin chao',
    lastMessageSenderId: 'user-2',
    unreadCount: 3,
    unreadMentionCount: 0,
    otherMemberName: 'Nguyen Van A',
    otherMemberAvatar: null,
    otherMemberLastSeenAt: DateTime(2026, 4, 22, 10, 1),
    lastViewedAt: DateTime(2026, 4, 22, 9, 0),
  );
}

LocalMessage _message({
  required String id,
  required String senderId,
  required String content,
  required DateTime createdAt,
}) {
  return LocalMessage(
    id: id,
    convId: 'conv-1',
    senderId: senderId,
    type: 'text',
    content: content,
    createdAt: createdAt,
    status: 'sent',
    retryCount: 0,
  );
}
