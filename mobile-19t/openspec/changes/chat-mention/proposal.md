## Why

Chat messaging (CHAT-FR-001) is complete with text, image, album, and voice messages. Group conversations work with member management, system messages, and real-time delivery. However, there is no way to directly address a specific person in a group chat. Users cannot draw attention to a particular member or ensure they see a message in a busy group.

Mention (CHAT-FR-034, P2 COULD) enables users to type `@` in a group chat to see a member list, select a user, and send a message that highlights the mentioned user. The mentioned user receives a push notification even if they have muted the group — matching Telegram's behavior. This is critical for an internal company app where important messages must reach specific people.

The existing `metadata` JSONB field on messages already stores structured data for images, albums, and voice messages. Mentions will use the same pattern — no schema migration needed for the core feature.

## What Changes

Frontend (Flutter):
- Detect `@` character in `MessageInputBar` TextField and show autocomplete overlay with conversation members
- Track mention entities (offset, length, user_id, name) as user selects members from autocomplete
- Update `sendMessage()` in `ChatNotifier` to accept and transmit `metadata.mentions` array
- Replace plain `Text()` with `Text.rich()` in `MessageBubble` to render mentions with accent color and tap-to-profile
- Add `@all` option in autocomplete for admin/creator users
- Add `unreadMentionCount` column to `LocalConversations` Drift table
- Show `@` badge on `ConversationTile` when unread mentions exist
- Fix `_flushQueue()` in `OfflineQueueService` to include metadata for text messages (existing bug)

Backend (NestJS):
- Extract mentioned user IDs from `metadata.mentions` in `ChatService.enqueueOfflinePush()`
- Override `is_muted` check for mentioned users — push notification even if muted
- Add `mentionedUserIds` to push job data in `NotificationJobService`
- Update `PushNotificationProcessor` to use mention-aware notification title ("X đã nhắc đến bạn")
- Handle `@all` mention: push to all members regardless of mute status
- Compute `unread_mention_count` in `getConversations()` response using JSONB query

## Capabilities

### New Capabilities
- `mention-autocomplete`: `@` trigger detection, member search overlay, mention entity tracking in MessageInputBar
- `mention-rendering`: RichText rendering of mention spans in MessageBubble with accent color and tap handler
- `mention-notifications`: Mention-aware push notifications that override mute, custom notification titles, @all support
- `mention-badge`: Unread mention count tracking and `@` badge display on ConversationTile

### Modified Capabilities
- `flutter-chat-ui`: MessageInputBar autocomplete overlay, MessageBubble RichText, ConversationTile badge
- `chat-message-send`: sendMessage() accepts metadata.mentions, offline queue includes metadata
- `push-notifications`: Mention override mute, custom title, @all fan-out

## Impact

- **Database (PostgreSQL)**: No schema migration for messages — uses existing `metadata` JSONB. Optional GIN index on `metadata->'mentions'` for unread count query performance.
- **Database (SQLite/Drift)**: Add `unreadMentionCount` column to `LocalConversations` — requires schema version bump and `build_runner` codegen.
- **API endpoints**: No new endpoints. `GET /conversations` response adds `unreadMentionCount` field.
- **WebSocket**: No protocol changes — `metadata` field already supported in `send_message` event.
- **Packages (Flutter)**: None — uses built-in `TextField`, `OverlayEntry`, `TextSpan`.
- **Packages (API)**: None — uses existing TypeORM JSONB support.
- **Performance**: JSONB query for unread mention count may need GIN index at scale. For <50 users, negligible impact.
- **Offline queue**: Fix existing bug where `_flushQueue()` drops metadata for text messages.

