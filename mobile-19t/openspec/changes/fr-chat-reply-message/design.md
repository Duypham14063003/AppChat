## Context

Chat messaging supports text, image, and album types. Reply infrastructure exists end-to-end but has no UI:
- PostgreSQL `messages.reply_to_id` (uuid, nullable) — populated on insert
- SQLite `local_messages.replyToId` (text, nullable) — synced from API and WS
- `ChatService.sendMessage()` reads `reply_to_id` from WS data and inserts it
- `ChatNotifier.sendMessage()` does NOT send `reply_to_id` — needs wiring
- `MessageBubble` has no reply display — needs quoted reply block
- `MessageInputBar` has no reply state — needs reply preview bar
- `ChatScreen` has no swipe gesture — needs swipe-to-reply
- `getMessages()` API returns raw `reply_to_id` UUID but not the referenced message data

Target: Telegram-style reply UX — swipe right to reply, quoted block in bubble, tap to scroll to original.

## Goals / Non-Goals

**Goals:**
- Telegram-style swipe-to-reply with haptic feedback and reply icon animation
- Long-press context menu with "Trả lời" option (bottom sheet, not popup menu)
- Reply preview bar above input showing sender name + content preview + close button
- Quoted reply block in message bubble with gold accent bar, sender name, content preview
- Tap quoted reply → scroll to original message + highlight animation
- Support reply to text, image, album message types
- Works in both direct and group conversations
- API eager-loads reply_to data to avoid N+1 client lookups

**Non-Goals:**
- Reply to voice messages (voice message feature not yet implemented)
- Reply to system messages
- Forward messages
- Edit or delete a reply specifically
- Nested reply display (reply to a reply shows flat — same as Telegram)
- Reply from notification (push notification tap → open chat, not reply inline)

## Decisions

### D1: Swipe gesture — Custom implementation with GestureDetector
**Choice**: Build custom swipe-to-reply using `GestureDetector` with `onHorizontalDragUpdate/End`. Not using `Dismissible` or `flutter_slidable`.
**Rationale**: `Dismissible` is designed to remove items — wrong semantics. `flutter_slidable` shows action buttons — wrong UX. Telegram's swipe is a drag-right that reveals a reply icon behind the bubble, snaps back on release, and triggers reply when threshold is crossed. This requires:
- `Transform.translate` on the bubble during drag (max ~80px)
- Animated reply icon (↩) appearing behind the bubble with scale animation
- Haptic feedback (`HapticFeedback.lightImpact()`) when crossing threshold (~60px)
- Spring animation to snap back on release
- Only horizontal drag right (positive dx), ignore left swipe
- Threshold: 60px to activate, max drag: 80px

### D2: Long-press context menu — Bottom sheet (not popup)
**Choice**: Long-press on message bubble shows a `showModalBottomSheet` with action list. First action: "Trả lời" with reply icon.
**Rationale**: Telegram uses a custom popup with blur background. A bottom sheet is simpler, accessible, and follows Material conventions. Future actions (copy, forward, delete, pin) can be added to the same sheet. The sheet shows:
- "Trả lời" (Reply) — always visible
- "Sao chép" (Copy) — only for text messages
- Future: more actions
Bottom sheet avoids the complexity of a custom overlay with blur.

### D3: Reply preview bar — Inline above input bar
**Choice**: When replying, show a preview bar between the message list and `MessageInputBar`. The bar contains: gold left accent (4px wide), sender name (bold, gold for own messages, sender color for others in group), content preview (1 line, ellipsis), and close (X) button on the right.
**Rationale**: Telegram pattern. The preview bar is part of the input area, not floating. It slides in with a short animation (150ms). Pressing X or sending the message clears the reply state. The bar must handle different message types:
- Text: show content text (max 1 line)
- Image: show "📷 Ảnh" + thumbnail if available
- Album: show "📷 N ảnh"

### D4: Quoted reply block in bubble — Gold accent bar with sender + preview
**Choice**: Inside `MessageBubble`, when the message has `reply_to_id` and reply data is available, render a quoted block above the message content:
- Container with `AppColors.surfaceVariant` background and 4px gold left border
- Sender name (bold, color-coded in group chats using same `senderColors` array)
- Content preview (1 line, ellipsis, `AppColors.textSecondary`)
- For image replies: small thumbnail (40x40) on the right side of the quote block
- Entire quote block is tappable (→ scroll to original)
- Rounded corners (8px) on the quote container

**Rationale**: Matches Telegram exactly. The gold accent bar provides visual consistency with the app's gold theme. Color-coded sender names in groups help identify who was replied to without reading the name.

### D5: API reply data — Eager load with LEFT JOIN
**Choice**: In `ChatService.getMessages()`, after fetching messages, batch-load all referenced `reply_to_id` messages in a single query. Return as `reply_to` object on each message: `{ id, sender_id, sender_name, content, type }`.
**Rationale**:
- Option A (JOIN in main query): Complex with partitioned table, risk of performance issues
- Option B (batch load after): Simple — collect all non-null `reply_to_id` values, do one `WHERE id IN (...)` query, map results back. Max 30 messages per page = max 30 reply lookups in one query.
- Option C (client lookup): Unreliable — original message may not be in local cache (older than 7 days)

Chose Option B. The batch query is simple and bounded (max 30 IDs). No schema changes needed.

### D6: Reply data in WebSocket events — Include reply_to snapshot
**Choice**: When broadcasting `new_message` via Redis pub/sub, include a `reply_to` snapshot object if the message has `reply_to_id`. The snapshot contains `{ id, sender_id, sender_name, content, type }`.
**Rationale**: Without this, receiving clients would need to look up the replied message from local cache or make an API call. Including the snapshot in the WS event ensures the quoted reply renders immediately. The snapshot is small (~200 bytes) and bounded to one per message.

### D7: Scroll-to-original — Reuse existing ScrollController (no scrollable_positioned_list yet)
**Choice**: When user taps a quoted reply block:
1. Search current loaded messages list for the original message ID
2. If found: calculate approximate scroll offset based on index, animate scroll, highlight
3. If not found: show a brief toast "Tin nhắn không trong phạm vi hiển thị" (message not in visible range)

**Rationale**: The `scrollable_positioned_list` migration is planned in `fr-chat-message-search`. Until that lands, we use a pragmatic approach:
- Most replies are to recent messages (within the loaded range)
- For the minority case where the original is not loaded, a toast is acceptable
- When `fr-chat-message-search` lands with `ScrollablePositionedList`, scroll-to-original can be upgraded to use `scrollTo(index)` with a small follow-up task
- This avoids duplicating the ListView→ScrollablePositionedList migration across two changes

Highlight animation: same pattern as search — `AppColors.gold.withOpacity(0.15)` background, fade in 200ms, hold 1.5s, fade out 500ms.

### D8: Reply state management — Local state in ChatScreen, not Riverpod
**Choice**: The "currently replying to" state lives in `_ChatScreenState` as `LocalMessage? _replyingTo`. Not a separate Riverpod provider.
**Rationale**: Reply state is ephemeral UI state — it exists only while composing a message and is cleared on send or cancel. It doesn't need to survive widget rebuilds, be shared across screens, or be persisted. Keeping it as local state is simpler and avoids unnecessary provider complexity. The state flows: `ChatScreen._replyingTo` → passed to `MessageInputBar` as prop → cleared on send/cancel.

### D9: Local storage of reply data — Store in metadata JSON
**Choice**: When saving a message with reply data to local SQLite, store the reply snapshot in the `metadata` JSON field as `reply_to: { id, sender_id, sender_name, content, type }`. The `replyToId` column stores just the ID (already exists).
**Rationale**: Adding new columns to `LocalMessages` requires a Drift schema migration. Storing in metadata avoids migration and leverages the existing flexible JSON field. The reply snapshot is small and read-only. When rendering, `MessageBubble` reads `replyToId` to know a reply exists, then extracts `reply_to` from parsed metadata for display data.

## Risks / Trade-offs

- **[Scroll-to-original limited without scrollable_positioned_list]** → Cannot scroll to messages outside the loaded range. Acceptable for now — most replies target recent messages. Will be upgraded when search change lands.
- **[Reply data in metadata JSON]** → Slightly denormalized. If the original message is edited/deleted, the snapshot becomes stale. Acceptable — Telegram has the same behavior (quoted text doesn't update if original is edited).
- **[Bottom sheet vs custom popup]** → Less visually similar to Telegram's blur popup. Acceptable — simpler implementation, accessible, extensible for future actions.
- **[Haptic feedback on iOS vs Android]** → `HapticFeedback.lightImpact()` works on both but feels slightly different. Acceptable — platform-native feel is actually preferred.

## Open Questions

- None — all decisions made during exploration phase.
