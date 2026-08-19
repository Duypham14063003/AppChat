## Context

Chat messaging is complete with text, image, album, and voice messages. Group conversations support member management (add/remove/leave), system messages, and real-time delivery via WebSocket + Redis Pub/Sub. Push notifications work for offline users via BullMQ + FCM, with mute support (`is_muted` on `conversation_members`).

Current message data model: `messages` table has `content` (text), `metadata` (JSONB), `type`, `reply_to_id`. The `metadata` field is already used by image/album/voice messages to store structured data. No mention-related code exists anywhere in the codebase.

Key existing infrastructure:
- `conversationMembersProvider` fetches all members with name/avatar for a conversation (Flutter)
- `MessageBubble` renders content as plain `Text()` widget
- `MessageInputBar` has `TextEditingController` with `onChanged` handler
- `enqueueOfflinePush()` iterates members, skips muted, enqueues BullMQ job
- `PushNotificationProcessor` checks mute again, builds title/body, sends FCM
- `ConversationTile` shows unread count badge (gold circle with number)
- Reply UI is NOT implemented (data layer supports `reply_to_id` but no UI exists)

This change implements CHAT-FR-034 (Mention @user, P2 COULD). Follows Telegram's mention pattern: entity-based metadata, mute override for mentions, @all for group-wide notifications.

## Goals / Non-Goals

**Goals:**
- `@` trigger in MessageInputBar shows autocomplete overlay with conversation members
- Member search by name prefix (case-insensitive, Vietnamese diacritics)
- Selected mention inserts styled text and tracks entity metadata (offset, length, user_id, name)
- Multiple mentions per message supported
- `@all` option for admin/creator users — notifies all members
- Message metadata stores mentions array: `{mentions: [{offset, length, user_id, name}]}`
- MessageBubble renders mentions with accent color (AppColors.gold) and tap-to-profile
- Push notification overrides mute for mentioned users
- Custom notification title: "Name đã nhắc đến bạn" / "Name đã nhắc đến mọi người"
- Unread mention count tracked per conversation, displayed as `@` badge on ConversationTile
- Offline queue preserves mention metadata (fix existing bug)
- Scope: group chat only (DIRECT conversations don't show autocomplete)

**Non-Goals:**
- Auto-mention on reply (reply UI doesn't exist yet — defer to reply feature)
- Mention in message captions (image/voice captions — future enhancement)
- @channel or @here variants (only @all and @user)
- Mention analytics or history
- Server-side mention parsing/validation (client constructs entities, server stores as-is)
- Mention in search results highlighting (FTS already indexes content text which includes @Name)
- Mention suggestions based on message context (AI-powered)

## Decisions

### D1: Data model — Mention entities in metadata JSONB
**Choice**: Store mentions as an array in the existing `metadata` JSONB field: `{mentions: [{offset, length, user_id, name}]}`.
**Rationale**: Reuses existing infrastructure — no schema migration needed. Consistent with how image/album/voice metadata is stored. The `offset` and `length` use Dart's UTF-16 string indices (same as `String.length`), which matches Flutter's `TextSpan` positioning. Denormalized `name` avoids lookup on render. Telegram uses the same entity-based approach (MessageEntity with offset/length).
**Alternative considered**: Separate `message_mentions` join table — rejected due to added complexity, extra queries, and migration overhead for a simple feature.

### D2: Autocomplete data source — conversationMembersProvider (client-side)
**Choice**: Use existing `conversationMembersProvider` which already fetches all members with name/avatar for the current conversation. Filter client-side by name prefix.
**Rationale**: Company has <50 employees, so all members fit in memory. No new API endpoint needed. Data is already cached from conversation load. Prefix search on name is trivial in Dart. Matches Telegram behavior where autocomplete is instant (no network call).
**Alternative considered**: Server-side search endpoint `GET /conversations/:id/members?search=` — rejected as overkill for <50 users.

### D3: Autocomplete trigger — `@` character detection
**Choice**: Monitor `TextEditingController.text` changes. When `@` is typed (and preceded by whitespace or is at position 0), activate autocomplete. Track the `@` position. Characters typed after `@` filter the member list. Autocomplete dismisses on: member selection, backspace past `@`, space without selection, or tap outside.
**Rationale**: Standard pattern used by Telegram, Slack, Discord. Position tracking ensures correct entity offset calculation even with multiple mentions.

### D4: Mention text insertion — Replace @query with @Name + trailing space
**Choice**: When user selects a member from autocomplete, replace the `@query` text with `@DisplayName ` (with trailing space). Record the entity: `{offset: @position, length: "@DisplayName".length, user_id, name}`. For `@all`, insert `@Tất cả `.
**Rationale**: Trailing space prevents the autocomplete from re-triggering. Display name is human-readable. Entity metadata enables styled rendering independent of text content.

### D5: Mention rendering — Text.rich with styled TextSpan
**Choice**: Replace `Text(message.content)` in MessageBubble with `Text.rich(TextSpan(children: [...]))`. Parse `metadata.mentions` to split content into normal text spans and mention spans. Mention spans use `AppColors.gold` color and `GestureRecognizer` for tap-to-profile.
**Rationale**: `Text.rich` is Flutter's standard approach for mixed-style text. No external packages needed. Gold color matches the app's accent theme. Tap handler enables navigation to user profile (future) or showing user info.

### D6: @all — Admin/creator only, special user_id
**Choice**: `@all` mention uses `user_id: "all"` in the entity. Only shown in autocomplete if current user's role is `admin` or `creator` in the conversation. Backend treats `user_id: "all"` as "notify everyone".
**Rationale**: Prevents spam from regular members. Admin/creator restriction matches Telegram's pin-message pattern (only admins can pin, which is Telegram's equivalent of @all). Special `user_id` value is simple to check on both client and server.

### D7: Push notification — Mention overrides mute at enqueue level
**Choice**: In `ChatService.enqueueOfflinePush()`, extract `mentionedUserIds` from `message.metadata.mentions`. For each member: if `is_muted` but user is in `mentionedUserIds` (or mentions contain `user_id: "all"`), still enqueue push. Pass `isMentioned: true` in job data. In `PushNotificationProcessor`, use custom title when `isMentioned`.
**Rationale**: The enqueue method is the gatekeeper — fixing it there ensures mentions always reach users. Passing `isMentioned` flag to processor avoids re-parsing metadata in the worker. Matches Telegram behavior where mentions override mute.

### D8: Notification title — Vietnamese, context-aware
**Choice**:
- Normal message: `"Sender Name"` (existing)
- Mentioned: `"Sender Name đã nhắc đến bạn"`
- @all: `"Sender Name đã nhắc đến mọi người"`
- Body remains: message content preview (truncated 100 chars)
**Rationale**: Vietnamese UI strings match the app's existing pattern (inline Vietnamese, no i18n). Distinct title helps user understand why they got notified despite muting.

### D9: Unread mention count — Server-side JSONB query
**Choice**: In `ChatService.getConversations()`, compute `unreadMentionCount` alongside existing `unreadCount`. Query: count messages where `created_at > last_read_at` AND (`metadata->'mentions' @> '[{"user_id": "USER_ID"}]'` OR `metadata->'mentions' @> '[{"user_id": "all"}]'`). Add `unreadMentionCount` to `LocalConversations` Drift table.
**Rationale**: Leverages existing unread count pattern. JSONB containment operator `@>` is efficient with GIN index. For <50 users and 7-day message window, query is fast even without index. Drift column addition requires schema version bump + codegen.

### D10: Mention badge — `@` icon on ConversationTile
**Choice**: When `unreadMentionCount > 0`, show a small `@` badge next to (or replacing) the unread count badge. Use same gold color. Badge shows `@` symbol, not a number.
**Rationale**: Matches Telegram's `@` badge pattern. Simpler than showing a count — user just needs to know "someone mentioned me". The `@` symbol is universally understood.

### D11: Offline queue fix — Include metadata in _flushQueue
**Choice**: Fix `OfflineQueueService._flushQueue()` to include `metadata` field when replaying queued text messages. Parse `msg.metadata` from JSON string and include in WS payload.
**Rationale**: This is an existing bug — image messages include metadata but text messages don't. Mentions stored in metadata would be lost on offline replay without this fix. The fix benefits all future metadata-bearing text messages.

### D12: Scope — Group chat only
**Choice**: Autocomplete overlay only activates in group conversations (`conversation.type == 'GROUP'`). In DIRECT conversations, `@` is treated as normal text.
**Rationale**: Matches SRS requirement ("When gõ `@` trong group"). DIRECT conversations have only 2 people — mentioning is redundant. Notification override for mentions still applies if a DIRECT message somehow contains mention metadata (defensive).

## Risks / Trade-offs

- **[UTF-16 offset accuracy with Vietnamese text]** → Vietnamese diacritics (Ngọc, Hải) are single UTF-16 code units, so Dart `String.length` is accurate. Emoji (👍) are 2 UTF-16 units — offset calculation must account for this. Mitigated by: using Dart string operations which natively handle UTF-16.
- **[Mention entity drift on message edit]** → If message editing is added later, mention offsets may become invalid after text changes. Mitigated by: message editing is not implemented; when it is, mention entities should be recalculated or stripped.
- **[JSONB query performance for unread mention count]** → `@>` containment query on `metadata` scans all unread messages per conversation. Mitigated by: <50 users, 7-day local cache, `last_read_at` filter limits scan. Add GIN index on `metadata->'mentions'` if needed.
- **[@all spam potential]** → Admin/creator restriction limits who can use @all. Mitigated by: company has <50 employees, social norms apply. Can add rate limiting later if needed.
- **[Autocomplete overlay z-index conflicts]** → Overlay may conflict with emoji picker or other overlays. Mitigated by: dismiss autocomplete when emoji picker opens, use `OverlayEntry` with proper insertion point.
- **[Offline mention metadata loss (existing bug)]** → `_flushQueue()` currently drops metadata for text messages. Mitigated by: this change fixes the bug as part of scope.

## Open Questions

- None — all decisions made during exploration phase.

