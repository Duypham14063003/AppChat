## Why

Users want a familiar chat-app behavior similar to Facebook Messenger or Telegram: preview a conversation from the chat list without immediately marking the conversation as read. Today, tapping a conversation opens `ChatScreen`, which sets the active conversation and triggers the existing read-sync flow. That clears local unread counters and sends `mark_read` through the websocket path.

This is correct for fully opening a conversation, but it does not support a lightweight "peek" interaction. Users should be able to inspect recent messages while preserving unread badges until they explicitly enter the conversation.

## What Changes

- Add a conversation peek/preview interaction from the chat list, triggered by long-press on a conversation row.
- Show a read-only preview surface with recent messages, conversation identity, unread context, and an explicit action to open the full chat.
- Ensure the preview path does not mark messages as read locally or remotely.
- Preserve current single-tap behavior: opening the full chat still marks the conversation as read through the existing read-sync flow.
- Keep preview loading separate from the existing `chatMessagesProvider` path because that provider intentionally performs read reconciliation for active conversations.

## Capabilities

### New Capabilities
- `chat-conversation-peek-preview`: Users can preview recent messages from a conversation without changing read/unread state.

### Modified Capabilities
- `chat-read-sync`: Distinguish between full conversation entry and read-only conversation preview so read state only changes on actual entry.

## Impact

- Mobile chat list interaction: `apps/mobile/lib/features/chat/screens/chat_list_screen.dart`
- Conversation row gestures: `apps/mobile/lib/features/chat/widgets/conversation_tile.dart`
- Preview UI/widget surface under `apps/mobile/lib/features/chat/`
- Preview message loading path in `apps/mobile/lib/features/chat/providers/chat_providers.dart` and/or `apps/mobile/lib/features/chat/data/chat_repository.dart`
- Read-state guardrails around `activeChatConversationIdProvider`, `markConversationViewed`, and websocket `sendMarkRead`
- Tests for gesture behavior, preview loading, and read-state preservation
