import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/core/database/app_database.dart';
import 'package:nineteen_tech_app/features/chat/providers/chat_providers.dart';

void main() {
  group('shouldMarkConversationReadForEntry', () {
    test('marks read only for full conversation entry', () {
      expect(
        shouldMarkConversationReadForEntry(ChatConversationEntryMode.full),
        isTrue,
      );
      expect(
        shouldMarkConversationReadForEntry(ChatConversationEntryMode.preview),
        isFalse,
      );
    });
  });

  group('normalizeConversationPreviewMessages', () {
    test('keeps the newest messages and returns them oldest-to-newest', () {
      final normalized = normalizeConversationPreviewMessages([
        _message('msg-1', DateTime(2026, 4, 20, 10, 0)),
        _message('msg-3', DateTime(2026, 4, 20, 10, 2)),
        _message('msg-2', DateTime(2026, 4, 20, 10, 1)),
      ], limit: 2);

      expect(normalized.map((message) => message.id).toList(), [
        'msg-2',
        'msg-3',
      ]);
    });
  });

  group('shouldTreatConversationAsRead', () {
    test('returns false when there is no local lastViewedAt watermark', () {
      final lastMessageAt = DateTime(2026, 4, 20, 10, 0);

      expect(shouldTreatConversationAsRead(null, lastMessageAt), isFalse);
    });

    test(
      'returns true when the latest message is at or before lastViewedAt',
      () {
        final lastViewedAt = DateTime(2026, 4, 20, 10, 0);

        expect(
          shouldTreatConversationAsRead(
            lastViewedAt,
            DateTime(2026, 4, 20, 9, 59),
          ),
          isTrue,
        );
        expect(
          shouldTreatConversationAsRead(
            lastViewedAt,
            DateTime(2026, 4, 20, 10, 0),
          ),
          isTrue,
        );
      },
    );

    test('returns false when a newer message arrived after lastViewedAt', () {
      final lastViewedAt = DateTime(2026, 4, 20, 10, 0);
      final lastMessageAt = DateTime(2026, 4, 20, 10, 1);

      expect(
        shouldTreatConversationAsRead(lastViewedAt, lastMessageAt),
        isFalse,
      );
    });

    test(
      'returns true when the conversation has no remote last message timestamp',
      () {
        final lastViewedAt = DateTime(2026, 4, 20, 10, 0);

        expect(shouldTreatConversationAsRead(lastViewedAt, null), isTrue);
      },
    );
  });

  group('resolveConversationUnreadCount', () {
    test(
      'keeps server unread for inactive conversation even when local watermark says read',
      () {
        final resolved = resolveConversationUnreadCount(
          conversationId: 'conv-2',
          activeConversationId: 'conv-1',
          lastViewedAt: DateTime(2026, 4, 20, 10, 5),
          lastMessageAt: DateTime(2026, 4, 20, 10, 0),
          serverUnreadCount: 4,
        );

        expect(resolved, 4);
      },
    );

    test('forces unread to zero only for the active conversation', () {
      final resolved = resolveConversationUnreadCount(
        conversationId: 'conv-1',
        activeConversationId: 'conv-1',
        lastViewedAt: DateTime(2026, 4, 20, 10, 5),
        lastMessageAt: DateTime(2026, 4, 20, 10, 0),
        serverUnreadCount: 4,
      );

      expect(resolved, 0);
    });
  });

  group('nextUnreadCountForInboundMessage', () {
    test('increments unread for inactive inbound messages from another user', () {
      final nextCount = nextUnreadCountForInboundMessage(
        currentUnreadCount: 0,
        conversationId: 'conv-2',
        activeConversationId: 'conv-1',
        senderId: 'user-2',
        currentUserId: 'user-1',
      );

      expect(nextCount, 1);
    });

    test('does not increment unread for the currently active conversation', () {
      final nextCount = nextUnreadCountForInboundMessage(
        currentUnreadCount: 0,
        conversationId: 'conv-1',
        activeConversationId: 'conv-1',
        senderId: 'user-2',
        currentUserId: 'user-1',
      );

      expect(nextCount, 0);
    });

    test('does not increment unread for messages sent by the current user', () {
      final nextCount = nextUnreadCountForInboundMessage(
        currentUnreadCount: 2,
        conversationId: 'conv-2',
        activeConversationId: null,
        senderId: 'user-1',
        currentUserId: 'user-1',
      );

      expect(nextCount, 2);
    });
  });

  group('buildIncomingMessageCompanion', () {
    test('merges reply snapshot into persisted metadata', () {
      final companion = buildIncomingMessageCompanion({
        'id': 'msg-1',
        'conv_id': 'conv-1',
        'sender_id': 'user-2',
        'created_at': '2026-04-20T10:00:00.000Z',
        'type': 'text',
        'content': 'hello',
        'metadata': {
          'mentions': [
            {'id': 'user-1'},
          ],
        },
        'reply_to_id': 'msg-0',
        'reply_to': {'id': 'msg-0', 'content': 'older', 'type': 'text'},
      });

      expect(companion.id.value, 'msg-1');
      expect(companion.convId.value, 'conv-1');
      expect(companion.status.value, 'delivered');
      expect(
        companion.metadata.value,
        contains('"reply_to":{"id":"msg-0","content":"older","type":"text"}'),
      );
      expect(companion.metadata.value, contains('"mentions"'));
    });

    test(
      'uses provided default status and leaves metadata null when absent',
      () {
        final companion = buildIncomingMessageCompanion({
          'id': 'msg-2',
          'conv_id': 'conv-2',
          'sender_id': 'user-1',
          'created_at': '2026-04-20T10:01:00.000Z',
        }, defaultStatus: 'sent');

        expect(companion.status.value, 'sent');
        expect(companion.metadata.value, isNull);
        expect(companion.type.value, 'text');
      },
    );
  });

  group('shouldScheduleChatListReconciliation', () {
    test('schedules reconciliation for valid inbound conversation updates', () {
      expect(
        shouldScheduleChatListReconciliation(
          conversationId: 'conv-1',
          hasRefreshInFlight: false,
        ),
        isTrue,
      );
    });

    test('skips reconciliation when conversation id is missing', () {
      expect(
        shouldScheduleChatListReconciliation(
          conversationId: null,
          hasRefreshInFlight: false,
        ),
        isFalse,
      );
      expect(
        shouldScheduleChatListReconciliation(
          conversationId: '',
          hasRefreshInFlight: false,
        ),
        isFalse,
      );
    });

    test(
      'avoids duplicate reconciliation while refresh is already running',
      () {
        expect(
          shouldScheduleChatListReconciliation(
            conversationId: 'conv-1',
            hasRefreshInFlight: true,
          ),
          isFalse,
        );
      },
    );
  });
}

LocalMessage _message(String id, DateTime createdAt) {
  return LocalMessage(
    id: id,
    convId: 'conv-1',
    senderId: 'user-2',
    type: 'text',
    content: id,
    createdAt: createdAt,
    status: 'sent',
    retryCount: 0,
  );
}
