## 1. API: Batch Load Reply Data in getMessages

- [x] 1.1 In `ChatService.getMessages()` (`apps/api/src/modules/chat/services/chat.service.ts`):
  - After fetching messages, collect all non-null `reply_to_id` values into a Set
  - If set is non-empty: query `SELECT m.id, m.sender_id, m.content, m.type, u.name as sender_name FROM messages m LEFT JOIN users u ON u.id = m.sender_id WHERE m.id IN (:...ids)`
  - Build lookup map: `Map<string, { id, sender_id, sender_name, content, type }>`
  - Attach `reply_to` object to each message in the returned array
  - If reply_to_id exists but message not found (deleted): set `reply_to: null`
- [x] 1.2 In `ChatService.sendMessage()`:
  - After saving message, if `replyToId` is non-null:
    - Query the replied-to message: `SELECT m.id, m.sender_id, m.content, m.type, u.name as sender_name FROM messages m LEFT JOIN users u ON u.id = m.sender_id WHERE m.id = $1`
    - Attach `reply_to` snapshot to the object published via `redisPubSub.publish()`
- [ ] 1.3 Verify: `GET /conversations/:id/messages` returns `reply_to` for messages with `reply_to_id`

## 2. Flutter: Update ChatNotifier to Handle Reply Data

- [x] 2.1 In `ChatNotifier.sendMessage()` (`lib/features/chat/providers/chat_providers.dart`):
  - Add optional `String? replyToId` parameter
  - Add optional `LocalMessage? replyToMessage` parameter (for building local snapshot)
  - Include `'reply_to_id': replyToId` in WS payload when non-null
  - Include `replyToId: Value(replyToId)` in local message insert
  - Build reply snapshot from `replyToMessage` and merge into metadata JSON
- [x] 2.2 In `ChatNotifier.sendImageMessage()`:
  - Add optional `String? replyToId` and `LocalMessage? replyToMessage` parameters
  - Same WS payload and local insert changes as sendMessage
- [x] 2.3 In `ChatNotifier._onNewMessage()`:
  - If WS data contains `reply_to` object: merge into metadata JSON before saving to SQLite
  - Metadata: `{ ...existing, "reply_to": { id, sender_id, sender_name, content, type } }`
- [x] 2.4 In `ChatNotifier._refreshFromApi()`:
  - If API response message contains `reply_to` object: merge into metadata JSON before saving

## 3. Flutter: SwipeToReply Widget

- [x] 3.1 Create `SwipeToReply` widget in `lib/features/chat/widgets/swipe_to_reply.dart`:
  - Props: `child: Widget`, `onReply: VoidCallback`, `enabled: bool`
  - `GestureDetector` with `onHorizontalDragUpdate` and `onHorizontalDragEnd`
  - Only respond to positive dx (right swipe), clamp to 0–80px
  - `Transform.translate(offset: Offset(dragX, 0))` on child
  - Behind child: reply icon (`Icons.reply`) with `Transform.scale` based on drag progress
  - Icon scale: `(dragX / 60).clamp(0.0, 1.0)`
  - Icon color: `dragX >= 60 ? AppColors.gold : AppColors.textSecondary`
  - Haptic: `HapticFeedback.lightImpact()` when dragX first crosses 60px threshold
  - On drag end: if dragX >= 60 → call `onReply()`, animate back to 0
  - On drag end: if dragX < 60 → animate back to 0 (no reply)
  - Spring-back animation: `AnimationController` with `Curves.easeOut`, 200ms

## 4. Flutter: Long-Press Context Menu

- [x] 4.1 In `ChatScreen`, add `_showMessageActions(LocalMessage message)` method:
  - `showModalBottomSheet` with rounded top corners (16px), `AppColors.surface` background
  - Actions list:
    - "Trả lời" — `Icons.reply` — always shown — calls `setState(() => _replyingTo = message)`
    - "Sao chép" — `Icons.copy` — only if `message.type == 'text'` and `message.content != null` — copies to clipboard, shows SnackBar "Đã sao chép"
  - Each action: `ListTile(leading: Icon(...), title: Text(...), onTap: ...)`
  - Pop bottom sheet after action
- [x] 4.2 Wire long-press: in `_buildMessageItems()`, wrap non-system `MessageBubble` with `GestureDetector(onLongPress: () => _showMessageActions(msg))`
  - Combine with `SwipeToReply` wrapper (SwipeToReply wraps GestureDetector wraps MessageBubble, or SwipeToReply handles both)

## 5. Flutter: ReplyPreviewBar Widget

- [x] 5.1 Create `ReplyPreviewBar` widget in `lib/features/chat/widgets/reply_preview_bar.dart`:
  - Props: `LocalMessage message`, `String senderName`, `Color? senderNameColor`, `VoidCallback onClose`
  - Layout: `Container` with top border → `Row`:
    - Gold accent bar: `Container(width: 4, color: AppColors.gold)` full height
    - `SizedBox(width: 8)`
    - `Expanded` column: sender name (bold, 13px, colored) + content preview (1 line, 13px, textSecondary)
    - Close button: `IconButton(icon: Icon(Icons.close, size: 18), onPressed: onClose)`
  - Content preview logic:
    - `text`: show `message.content` (max 1 line, ellipsis)
    - `image`: "📷 Ảnh"
    - `album`: "📷 N ảnh" (parse metadata for image count)
  - Background: `AppColors.surface`
  - Height: intrinsic (auto-sized)

## 6. Flutter: Wire Reply Preview to MessageInputBar

- [x] 6.1 Add props to `MessageInputBar`:
  - `LocalMessage? replyTo`
  - `String? replyToSenderName`
  - `Color? replyToSenderColor`
  - `VoidCallback? onCancelReply`
- [x] 6.2 In `MessageInputBar.build()`:
  - Above the input row Container: if `replyTo != null`, show `ReplyPreviewBar`
  - Use `AnimatedCrossFade` or `AnimatedSize` for smooth appear/disappear (150ms)
- [x] 6.3 In `ChatScreen`:
  - Add `LocalMessage? _replyingTo` state
  - Pass `_replyingTo` and related props to `MessageInputBar`
  - Resolve sender name: from `members` map (group) or `otherName` (direct) or "Bạn" (own message)
  - Resolve sender color: `AppColors.gold` for own, `senderColors[hash]` for group others
  - On send callback: call `sendMessage(text, replyToId: _replyingTo?.id, replyToMessage: _replyingTo)`, then `setState(() => _replyingTo = null)`
  - On cancel: `setState(() => _replyingTo = null)`
  - On image send: same — pass replyToId, clear after send

## 7. Flutter: Quoted Reply Block in MessageBubble

- [x] 7.1 Add parameters to `MessageBubble`:
  - `String? replyToSenderName`
  - `String? replyToContent`
  - `String? replyToType`
  - `Color? replyToSenderColor`
  - `VoidCallback? onReplyTap`
  - `bool isHighlighted` (default false)
- [x] 7.2 Add `_buildQuotedReply()` method in `MessageBubble`:
  - Returns `GestureDetector(onTap: onReplyTap)` wrapping a Container:
    - Background: `AppColors.surfaceVariant.withOpacity(0.5)`
    - Left border: 4px `AppColors.gold` (use `BoxDecoration` with `Border(left: ...)`)
    - Rounded corners: 8px
    - Padding: 8px horizontal, 6px vertical
    - Margin: only bottom 4px
    - Content: Column with sender name (bold, 12px, colored) + preview (1 line, 13px, textSecondary)
    - Preview text: text → content, image → "📷 Ảnh", album → "📷 N ảnh"
  - Only render if `replyToSenderName != null` (reply data available)
- [x] 7.3 In `_buildBubble()`: insert `_buildQuotedReply()` at top of Column children (before sender name, before content)
- [x] 7.4 Add highlight overlay support:
  - When `isHighlighted`: wrap entire bubble Container in a Stack with a semi-transparent gold overlay
  - Or use `TweenAnimationBuilder` for animated highlight

## 8. Flutter: ChatScreen — Extract Reply Data & Pass to Bubbles

- [x] 8.1 In `_buildMessageItems()`: for each message with `replyToId != null`:
  - Parse `message.metadata` JSON → extract `reply_to` object
  - If found: extract `sender_name`, `content`, `type`, `sender_id`
  - If not found in metadata: search current `messages` list for message with `id == replyToId` as fallback
  - Resolve sender color from `reply_to.sender_id`
  - Pass `replyToSenderName`, `replyToContent`, `replyToType`, `replyToSenderColor` to `MessageBubble`
  - Pass `onReplyTap: () => _scrollToMessage(replyToId)` to `MessageBubble`
  - Pass `isHighlighted: message.id == _highlightedMessageId` to `MessageBubble`

## 9. Flutter: Scroll-to-Original & Highlight

- [x] 9.1 Add state to `_ChatScreenState`:
  - `String? _highlightedMessageId`
  - `Timer? _highlightTimer`
- [x] 9.2 Implement `_scrollToMessage(String messageId)`:
  - Get current messages list from provider state
  - Find index of message with matching ID
  - If found:
    - Estimate scroll offset: since list is reversed, index 0 = newest (bottom). Use `_scrollController.position.maxScrollExtent` and index ratio for rough estimate, or iterate item extents if available
    - `_scrollController.animateTo(offset, duration: 300ms, curve: Curves.easeInOut)`
    - After scroll completes: `setState(() => _highlightedMessageId = messageId)`
    - Start timer: 2200ms → `setState(() => _highlightedMessageId = null)`
  - If not found:
    - Show `SnackBar(content: Text('Tin nhắn không trong phạm vi hiển thị'))`
- [x] 9.3 Dispose `_highlightTimer` in `dispose()`

## 10. Integration & Verification

- [ ] 10.1 Verify: swipe right on text message → reply preview appears above input
- [ ] 10.2 Verify: long-press on text message → bottom sheet with "Trả lời" + "Sao chép"
- [ ] 10.3 Verify: long-press on image message → bottom sheet with "Trả lời" only (no copy)
- [ ] 10.4 Verify: send reply → message appears with quoted block showing original
- [ ] 10.5 Verify: reply to image → quoted block shows "📷 Ảnh"
- [ ] 10.6 Verify: tap quoted block → scrolls to original message with highlight
- [ ] 10.7 Verify: tap quoted block for message not in range → shows toast
- [ ] 10.8 Verify: reply works in both direct and group conversations
- [ ] 10.9 Verify: group chat quoted reply shows correct sender color
- [ ] 10.10 Verify: receiving a reply message via WS → quoted block renders correctly
- [ ] 10.11 Run `flutter analyze` in apps/mobile — no errors
- [ ] 10.12 Run `npm run lint && npm run build` in apps/api — no errors
