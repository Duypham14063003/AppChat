## Why

Chat already supports sending, replying, forwarding, reactions, pinning, and bookmarks, but it still lacks two baseline messaging controls that users expect in day-to-day conversations: editing a sent message and recalling a message they no longer want visible. The database schema already reserves `edited_at` and `deleted_at`, so now is a good time to turn that latent support into a complete product flow instead of leaving message correction and recall as dead ends.

## What Changes

- Add backend support for editing a previously sent text message, including permission checks, validation, and persisted `edited_at` metadata.
- Add backend support for recalling a previously sent message via soft delete semantics and a conversation-safe response model.
- Add realtime chat events for edited and recalled messages so open conversations update without a manual refresh.
- Add mobile repository, provider, and local database update flows for edit and recall mutations.
- Extend the mobile message context menu with `Sửa` and `Thu hồi` actions when the current user is allowed to perform them.
- Add chat UI states for edited messages and recalled messages, including a visible recalled-message placeholder instead of silently removing the message from the timeline.
- Keep the conversation-list preview synchronized when the latest message in a chat is edited or recalled, so the list does not keep showing stale content snapshots.
- Add verification coverage for sender permissions, mutation sync, and timeline rendering after edit or recall actions.

## Capabilities

### New Capabilities
- `message-edit-and-recall-backend`: Server-side edit and recall APIs, validation, persistence, and realtime event publication for chat messages.
- `message-edit-and-recall-ui`: Flutter chat actions, local sync, and message rendering for edited and recalled messages.

### Modified Capabilities
<!-- No existing capability requirements are being modified. -->

## Impact

- **Backend API**: new message mutation endpoints and/or websocket mutation handling under the chat module.
- **Backend services**: `apps/api/src/modules/chat/services/chat.service.ts`, controllers/DTOs, websocket gateway, and message serialization.
- **Realtime**: websocket event contract for `message_updated` and `message_recalled`-style updates.
- **Mobile data layer**: `chat_repository.dart`, chat providers, websocket manager bindings, and Drift DAO update logic.
- **Mobile UI**: `message_context_menu.dart`, `chat_screen.dart`, `message_input_bar.dart`, message bubble rendering, and conversation list preview tiles.
- **Local storage behavior**: existing `deletedAt` handling must change from "hide deleted messages" to "render recalled placeholder" for recalled messages that remain in the visible timeline.
