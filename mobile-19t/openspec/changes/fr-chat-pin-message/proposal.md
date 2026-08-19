## Why

The SRS defines CHAT-FR-013 (P1 SHOULD): users can pin messages in conversations, with a pinned bar at the top showing up to 5 pinned messages per conversation. No pin-related code exists anywhere in the codebase. The `database-schema.md` ER diagram references a `pinned_messages` table but no implementation exists. This feature is a core Telegram-like interaction expected by users for surfacing important messages in busy conversations.

## What Changes

Backend (NestJS):
- New `pinned_messages` PostgreSQL table with migration (conv_id, message_id, pinned_by, pinned_at, pin_order)
- New `PinnedMessage` TypeORM entity
- REST endpoints on ConversationController: pin message, unpin message, list pinned messages, unpin all
- Permission enforcement: any member can pin in DIRECT, only admin/creator in GROUP
- Max 5 pinned messages per conversation (server-enforced)
- System message on pin/unpin ("X pinned a message", "X unpinned a message")
- `pin_update` event broadcast via Redis PubSub to all conversation members

Frontend (Flutter):
- `PinnedMessageBar` widget at top of chat screen — shows current pin, tap to scroll to message, tap again to cycle through pins
- Pinned messages list screen — accessible from chat header, shows all pinned messages with tap-to-jump
- Unified long-press context menu replacing current reaction-picker-only overlay — includes Pin/Unpin, reaction row, and forward-compatible slots for Reply/Copy/Delete
- `LocalPinnedMessages` Drift table, schema version 5→6
- `pinnedMessagesProvider` Riverpod provider for state management
- Pin/unpin via ChatRepository HTTP calls
- Real-time pin updates via WebSocket `pin_update` event handler

## Capabilities

### New Capabilities
- `pin-message-backend`: Server-side pin/unpin logic — database table, REST API, permission checks, limit enforcement, system messages, real-time broadcast
- `pin-message-ui`: Flutter pinned message bar, pinned messages list screen, context menu integration, local storage, real-time updates
- `message-context-menu`: Unified long-press context menu replacing reaction-picker overlay — extensible action list (Pin/Unpin now, Reply/Copy/Delete slots for future)

### Modified Capabilities
<!-- No existing spec-level requirements are changing. The context menu is a new UI pattern replacing an ad-hoc overlay, not modifying an existing spec. -->

## Impact

- **Database**: New `pinned_messages` table + migration. No changes to existing tables.
- **API**: New REST endpoints under `/conversations/:id/pins`. No changes to existing endpoints.
- **WebSocket**: New `pin_update` event in gateway switch + Redis PubSub broadcast. No changes to existing events.
- **Flutter UI**: `MessageItem.onLongPress` changes from reaction picker overlay to unified context menu bottom sheet. `ChatScreen` build method gains `PinnedMessageBar` between WS banner and message list. New `PinnedMessagesListScreen` route.
- **Drift**: Schema version 5→6, new `LocalPinnedMessages` table, new migration block.
- **Overlap**: The `fr-chat-reply-message` change (not yet implemented) plans a similar context menu. This change builds the unified menu first, making reply-message's context menu tasks redundant when it's implemented later.

