# Implementation Tasks

## Phase 1: Backend — Mention-aware Push Notifications

### Task 1.1: Extract mentions in enqueueOfflinePush
- [x] Open `apps/api/src/modules/chat/services/chat.service.ts`
- [x] In `enqueueOfflinePush()`, parse `message.metadata` to extract mentions array
- [x] Build `Set<string>` of mentioned user IDs
- [x] Detect `user_id: "all"` → set `isMentionAll` boolean
- [x] Handle null/undefined/malformed metadata gracefully

### Task 1.2: Override mute for mentioned users
- [x] In `enqueueOfflinePush()` member loop, compute `isMentioned` per member
- [x] Change mute check: `if (member.is_muted && !isMentioned) continue;`
- [x] When `isMentionAll`: all members bypass mute check

### Task 1.3: Update NotificationJobService
- [x] Open `apps/api/src/modules/chat/services/notification-job.service.ts`
- [x] Add `isMentioned` parameter to `enqueuePush()` method (default `false`)
- [x] Include `isMentioned` in job data object

### Task 1.4: Update PushNotificationProcessor
- [x] Open `apps/api/src/modules/notification/services/push-notification.processor.ts`
- [x] Read `isMentioned` from `job.data`
- [x] Update mute check: `if (membership?.is_muted && !isMentioned) return;`
- [x] Build mention-aware title: `"${senderName} đã nhắc đến bạn"` when `isMentioned`
- [x] Add `is_mention: 'true'` to FCM data payload when `isMentioned`

### Task 1.5: Add unread mention count to getConversations
- [x] In `ChatService.getConversations()`, add subquery for unread mention count
- [x] JSONB containment query: `metadata->'mentions' @> '[{"user_id": "USER_ID"}]'::jsonb`
- [x] Also check for `@all`: `metadata->'mentions' @> '[{"user_id": "all"}]'::jsonb`
- [x] Filter: `created_at > last_read_at`, `deleted_at IS NULL`, `sender_id != userId`
- [x] Return `unreadMentionCount` alongside existing `unreadCount`

## Phase 2: Flutter — Drift Schema Update

### Task 2.1: Add unreadMentionCount to LocalConversations
- [x] Open `apps/mobile/lib/core/database/tables.dart`
- [x] Add `IntColumn get unreadMentionCount => integer().withDefault(const Constant(0))();` to `LocalConversations`

### Task 2.2: Bump schema version and add migration
- [x] Open `apps/mobile/lib/core/database/app_database.dart`
- [x] Change `schemaVersion` from 4 to 5
- [x] Add migration: `if (from < 5) { ... }`

### Task 2.3: Add resetUnreadMentionCount to ChatDao
- [x] Open `apps/mobile/lib/core/database/chat_dao.dart`
- [x] Add `resetUnreadMentionCount(String convId)` method
- [x] Update `local_conversations` set `unread_mention_count = 0` where `id = convId`

### Task 2.4: Run build_runner codegen
- [x] Run `dart run build_runner build --delete-conflicting-outputs` in `apps/mobile/`
- [x] Verify generated files compile without errors

## Phase 3: Flutter — Mention Autocomplete

### Task 3.1: Add mention state to MessageInputBar
- [x] Add parameters: `bool isGroup`, `Map<String, Map<String, String?>>? members`, `String? currentUserId`, `String? currentUserRole`
- [x] Add state: `List<Map<String, dynamic>> _mentions = []`
- [x] Add state: `int? _mentionStartIndex`
- [x] Add state: `OverlayEntry? _overlayEntry`
- [x] Add state: `String _mentionQuery = ''`

### Task 3.2: Implement @ detection in onChanged
- [x] In `onChanged` handler, detect `@` character
- [x] Check if `@` is at position 0 or preceded by whitespace
- [x] Set `_mentionStartIndex` to the `@` position
- [x] Extract query text after `@` up to cursor position
- [x] Update `_mentionQuery` and show/update overlay
- [x] Dismiss overlay when: backspace past `@`, space without selection, cursor moves before `@`

### Task 3.3: Create mention autocomplete overlay
- [x] Create `_showMentionOverlay()` method using `OverlayEntry`
- [x] Position overlay above the input bar
- [x] Build scrollable list of matching members (max height 200px)
- [x] Each row: CircleAvatar + name
- [x] Filter members by `_mentionQuery` prefix (case-insensitive)
- [x] Exclude current user from list
- [x] Add `@all` row at top if `currentUserRole` is `admin` or `creator`
- [x] Style: `AppColors.surface` background, `AppColors.surfaceVariant` border, 12px radius

### Task 3.4: Implement member selection
- [x] On member tap: replace `@query` text with `@DisplayName ` (trailing space)
- [x] Add mention entity to `_mentions`: `{offset, length, user_id, name}`
- [x] Update cursor position to after trailing space
- [x] Dismiss overlay
- [x] For `@all`: insert `@Tất cả `, entity with `user_id: "all"`

### Task 3.5: Handle mention offset recalculation
- [x] On text change: recalculate offsets for existing mentions
- [x] If text inserted/deleted before a mention: shift offset accordingly
- [x] If backspace into a mention span: remove entire mention entity and its text
- [x] Validate all mention offsets are still within content bounds

### Task 3.6: Update onSend callback signature
- [x] Change `onSend` to include `List<Map<String, dynamic>>? mentions`
- [x] On send: pass `_mentions` as list of `{offset, length, user_id, name}` maps
- [x] Clear `_mentions` after send
- [x] Dismiss overlay on send

### Task 3.7: Update ChatScreen to pass new params
- [x] Pass `isGroup`, `members`, `currentUserId`, `currentUserRole` to MessageInputBar
- [x] Update `onSend` handler to accept mentions parameter

## Phase 4: Flutter — Send Message with Mentions

### Task 4.1: Update ChatNotifier.sendMessage()
- [x] Add optional `List<Map<String, dynamic>>? mentions` parameter to `sendMessage()`
- [x] Build metadata: `{'mentions': mentions}` when mentions is non-empty
- [x] Include metadata in local Drift insert and WS payload

### Task 4.2: Update ChatScreen onSend handler
- [x] Update `onSend` callback in ChatScreen to pass mentions to `sendMessage()`

### Task 4.3: Fix OfflineQueueService._flushQueue()
- [x] In `_flushQueue()`, include `metadata` in WS payload for text messages
- [x] Parse `msg.metadata` from JSON string if not null
- [x] Add `'metadata': parsedMetadata` to the sendMessage map

## Phase 5: Flutter — Mention Rendering

### Task 5.1: Add _buildMentionText helper to MessageBubble
- [x] Add `_parseMentions()` method: extract mentions array from parsed metadata
- [x] Add `_buildMentionText()` method returning `TextSpan`
- [x] Sort mentions by offset ascending
- [x] Build TextSpan children: normal text + styled mention spans
- [x] Mention style: `AppColors.gold`, `FontWeight.w600`
- [x] Handle edge cases: overlapping mentions, out-of-bounds offsets

### Task 5.2: Replace Text with Text.rich in MessageBubble
- [x] In `_buildRichText()`, check for mentions first and use `_buildMentionText()`
- [x] Ensure no visual regression for messages without mentions

### Task 5.3: Manage GestureRecognizer lifecycle
- [x] MessageBubble is already StatefulWidget — recognizers created in build (acceptable for ListView items)

## Phase 6: Flutter — Mention Badge on ConversationTile

### Task 6.1: Map unreadMentionCount in chatListProvider
- [x] In `_refreshFromApi()`, map `conv['unreadMentionCount']` to `LocalConversationsCompanion`
- [x] Handle missing field gracefully (default to 0)

### Task 6.2: Reset mention count on conversation open
- [x] In `ChatMessagesNotifier.build()`, call `dao.resetUnreadMentionCount(convId)`

### Task 6.3: Add @ badge to ConversationTile
- [x] Add `@` badge when `conversation.unreadMentionCount > 0`
- [x] Badge: Container with `@` text, gold background, border radius 10
- [x] Position: next to unread count badge in a Row

## Phase 7: Testing

### Task 7.1: Backend unit tests
- [ ] Test `enqueueOfflinePush` with mention metadata — mentioned user gets push even if muted
- [ ] Test `enqueueOfflinePush` with @all — all members get push
- [ ] Test `enqueueOfflinePush` with no mentions — existing behavior preserved
- [ ] Test `PushNotificationProcessor` mention title: "Name đã nhắc đến bạn"
- [ ] Test `PushNotificationProcessor` @all title: "Name đã nhắc đến mọi người"
- [ ] Test malformed metadata doesn't crash

### Task 7.2: Flutter widget tests
- [ ] Test MessageBubble renders mentions in gold color
- [ ] Test MessageBubble renders plain text when no mentions
- [ ] Test mention autocomplete overlay appears on `@` in group chat
- [ ] Test autocomplete filters by name prefix
- [ ] Test `@all` only shown for admin/creator
- [ ] Test ConversationTile shows `@` badge when unreadMentionCount > 0

### Task 7.3: Flutter unit tests
- [ ] Test mention entity offset tracking with multiple mentions
- [ ] Test offset recalculation on text insertion/deletion
- [ ] Test sendMessage includes metadata.mentions in WS payload
- [ ] Test offline queue includes metadata for text messages

## Phase 8: Documentation

### Task 8.1: Update CLAUDE.md
- [x] Document mention feature in chat module description
- [x] Note metadata.mentions format: `[{offset, length, user_id, name}]`
- [x] Note @all uses `user_id: "all"`
- [x] Note mention overrides mute for push notifications
- [x] Note Drift schema version 5
