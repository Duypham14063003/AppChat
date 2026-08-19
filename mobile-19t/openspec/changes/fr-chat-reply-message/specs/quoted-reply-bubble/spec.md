## quoted-reply-bubble

Quoted reply block inside MessageBubble showing the original message's sender name and content preview with a gold left accent bar. Tappable to scroll to the original message.

### Requirements

1. **Quoted reply block in MessageBubble**
   - When `message.replyToId` is not null AND reply data is available in metadata:
     - Render a quoted block ABOVE the message content (inside the bubble)
     - Block layout:
       - Container with `AppColors.surfaceVariant.withOpacity(0.5)` background (slightly different from bubble bg)
       - 4px gold left border (`AppColors.gold`)
       - Rounded corners: 8px
       - Padding: 8px horizontal, 6px vertical
       - Margin: bottom 4px (space between quote and message content)
     - Content:
       - Sender name: bold, 12px, color-coded (gold for own, senderColors for group others)
       - Message preview: 1 line, ellipsis, 13px, `AppColors.textSecondary`
         - Text: show content
         - Image: "📷 Ảnh" + optional 40x40 thumbnail on right
         - Album: "📷 N ảnh" + optional thumbnail of first image on right
     - Entire block wrapped in `GestureDetector` → `onTap` triggers scroll-to-original

2. **MessageBubble changes**
   - Add new optional parameters:
     - `replyToSenderName: String?`
     - `replyToContent: String?`
     - `replyToType: String?`
     - `replyToSenderColor: Color?`
     - `onReplyTap: VoidCallback?`
   - In `_buildBubble()`: if `message.replyToId != null` and reply data props are provided, render `_buildQuotedReply()` at the top of the Column (before sender name and content)

3. **Extract reply data from metadata**
   - In `ChatScreen._buildMessageItems()`: for each message with `replyToId`:
     - Parse `metadata` JSON → look for `reply_to` object: `{ id, sender_id, sender_name, content, type }`
     - Resolve sender name and color from the reply_to data
     - Pass as props to `MessageBubble`
   - Fallback: if `reply_to` not in metadata (old messages), try to find the original message in the current loaded list by ID

4. **Scroll-to-original on tap**
   - `onReplyTap` callback in `MessageBubble` → handled by `ChatScreen`
   - `ChatScreen._scrollToMessage(String messageId)`:
     - Search `messages` list for the message with matching ID
     - If found: calculate index, estimate scroll offset (index * ~estimated_height), animate scroll
     - After scroll: set `_highlightedMessageId = messageId`, trigger highlight animation
     - If not found: show `SnackBar` with "Tin nhắn không trong phạm vi hiển thị"
   - Highlight animation: same as search feature pattern
     - Background overlay: `AppColors.gold.withOpacity(0.15)` → transparent
     - Duration: fade in 200ms, hold 1.5s, fade out 500ms
     - Clear `_highlightedMessageId` after animation completes

5. **Highlight support in MessageBubble**
   - Add `isHighlighted: bool` parameter (default false)
   - When true: wrap bubble in `TweenAnimationBuilder<double>` that animates opacity of a gold overlay
   - The overlay is a `Container` with `AppColors.gold.withOpacity(value * 0.15)` positioned over the bubble

### Integration Points

- `MessageBubble` — new reply props, quoted block rendering, highlight support
- `ChatScreen` — extract reply data from metadata, pass to bubbles, handle scroll-to-original
- `ChatScreen` — highlight state management (`_highlightedMessageId`)

### Acceptance Criteria

- Message with reply_to_id shows quoted block above content in bubble
- Quoted block has gold left accent bar, sender name (color-coded), content preview
- Reply to image shows "📷 Ảnh" in quote
- Tap quoted block → scrolls to original message (if in loaded range) with highlight
- Tap quoted block → shows toast if original not in loaded range
- Highlight animation: gold overlay fades in, holds, fades out (~2.2s total)
- Quoted block renders correctly in both own and other's bubbles
- Group chat: sender name in quote uses correct color
