## Why

Chat currently shows inconsistent state between the conversation list and the conversation detail view. Users can see a new-message preview in the list but not see that message after opening the conversation, and conversations can remain marked unread even after the user has already opened and viewed them.

A follow-up regression also appeared: unread count badges in the conversation list can disappear for conversations that should still be unread. The current read-sync logic includes a local timestamp-based override that can force unread counters to `0` even when the server still reports unread messages, especially when local and server message timelines diverge.

## What Changes

- Align conversation-list updates and conversation-detail message loading so newly received messages are visible immediately after entering a conversation.
- Define a reliable read-state synchronization flow so unread badges and mention badges clear once a conversation has been viewed.
- Add guardrails for stale provider state, local cache refresh timing, and server reconciliation after `mark_read`.
- Remove or narrowly scope local read overrides that can zero unread counters for conversations the user has not actively viewed in the current state.
- Ensure inbound message handling keeps conversation-list unread state accurate even before a full API reconciliation round completes.

## Capabilities

### New Capabilities
- `chat-read-sync`: Keeps chat message visibility and unread state consistent across the conversation list, conversation detail, local cache, and realtime updates.

### Modified Capabilities
- `chat-read-sync`: Add regression-hardening rules so unread counters are not suppressed by non-authoritative local heuristics.

## Impact

- Affected mobile chat state management in `apps/mobile/lib/features/chat/providers/chat_providers.dart`
- Affected chat screens and list/detail coordination in `apps/mobile/lib/features/chat/screens/`
- Affected local persistence and unread-count handling in `apps/mobile/lib/core/database/chat_dao.dart`
- Affected websocket event coordination in `apps/mobile/lib/core/network/websocket_manager.dart`
- Affected unread badge rendering inputs in `apps/mobile/lib/features/chat/widgets/conversation_tile.dart`
