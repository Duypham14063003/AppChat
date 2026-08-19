## reply-input-preview

Reply preview bar above MessageInputBar showing the message being replied to — sender name, content preview, close button. Slides in with animation. Cleared on send or cancel.

### Requirements

1. **Reply preview bar widget**
   - Create `ReplyPreviewBar` widget in `lib/features/chat/widgets/reply_preview_bar.dart`
   - Layout: Row with gold left accent bar (4px wide, full height) + content column + close button
   - Content column:
     - Sender name: bold, 13px
       - Own messages: `AppColors.gold` color
       - Other's messages in group: use `AppColors.senderColors[senderId.hashCode]` (same as bubble)
       - Other's messages in direct: `AppColors.gold`
     - Content preview: 1 line, ellipsis, 13px, `AppColors.textSecondary`
       - Text messages: show content text
       - Image messages: "📷 Ảnh"
       - Album messages: "📷 N ảnh" (extract count from metadata)
   - Close button: `Icons.close`, 18px, `AppColors.textSecondary`, right-aligned
   - Background: `AppColors.surface`
   - Top border: 1px `AppColors.surfaceVariant`
   - Height: ~48px (auto-sized by content)
   - Slide-in animation: `AnimatedSize` or `AnimatedCrossFade` — 150ms when appearing/disappearing

2. **Props**
   ```dart
   class ReplyPreviewBar extends StatelessWidget {
     final LocalMessage message;
     final String senderName;
     final Color? senderNameColor;
     final VoidCallback onClose;
   }
   ```

3. **Integration with MessageInputBar**
   - `MessageInputBar` gains new optional props:
     - `replyTo: LocalMessage?` — the message being replied to
     - `replyToSenderName: String?` — display name of the sender
     - `replyToSenderColor: Color?` — color for sender name
     - `onCancelReply: VoidCallback?` — called when close button tapped
   - When `replyTo` is not null: show `ReplyPreviewBar` above the input row
   - When `replyTo` is null: hide the preview bar (animated)

4. **Integration with ChatScreen**
   - `_ChatScreenState` adds: `LocalMessage? _replyingTo`
   - Pass `_replyingTo` and related props to `MessageInputBar`
   - On send: include `replyToId` in the send call, then clear `_replyingTo`
   - On cancel: `setState(() => _replyingTo = null)`
   - Resolve sender name from `members` map or `otherName` for display

5. **Send with reply_to_id**
   - `MessageInputBar.onSend` callback signature stays `void Function(String text)` — the reply context is managed by ChatScreen
   - `ChatScreen` wraps the send: when `_replyingTo != null`, call `sendMessage(text, replyToId: _replyingTo!.id)` then clear reply state
   - `ChatNotifier.sendMessage()` updated to accept optional `String? replyToId` parameter
   - Include `reply_to_id` in WS payload and local message insert
   - Same for `sendImageMessage()` — accept optional `replyToId`

### Integration Points

- `MessageInputBar` — new optional reply props, renders ReplyPreviewBar
- `ChatScreen` — manages `_replyingTo` state, passes to input bar, sends with reply_to_id
- `ChatNotifier` — `sendMessage()` and `sendImageMessage()` accept `replyToId` parameter
- New widget: `ReplyPreviewBar` in `lib/features/chat/widgets/reply_preview_bar.dart`

### Acceptance Criteria

- Set reply state → preview bar slides in above input with sender name + content preview
- Tap X → preview bar slides out, reply state cleared
- Send message while replying → message sent with reply_to_id, preview bar clears
- Reply to image → preview shows "📷 Ảnh"
- Reply to album → preview shows "📷 N ảnh"
- Sender name color matches bubble sender color in group chats
- Gold accent bar visible on left side of preview
