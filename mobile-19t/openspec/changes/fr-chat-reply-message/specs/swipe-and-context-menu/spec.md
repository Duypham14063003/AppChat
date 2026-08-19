## swipe-and-context-menu

Swipe-right gesture on message bubbles to trigger reply, plus long-press bottom sheet context menu with "Trả lời" action. Telegram-style UX with haptic feedback and animated reply icon.

### Requirements

1. **Swipe-to-reply gesture wrapper**
   - Create `SwipeToReply` widget that wraps each `MessageBubble` in `ChatScreen`
   - Uses `GestureDetector.onHorizontalDragUpdate` and `onHorizontalDragEnd`
   - Only responds to right-swipe (positive dx), ignores left-swipe
   - During drag: `Transform.translate` the bubble by `dx` (clamped to 0–80px)
   - Behind the bubble: reply icon (Icons.reply) with scale animation
     - Icon starts at scale 0.0, grows to 1.0 as drag approaches threshold (60px)
     - Icon color: `AppColors.textSecondary` → `AppColors.gold` when threshold crossed
   - Threshold: 60px — when crossed, trigger `HapticFeedback.lightImpact()`
   - On drag end: if threshold was crossed → call `onReply(message)` callback
   - On drag end: spring animation to snap bubble back to x=0 (duration ~200ms, `Curves.easeOut`)
   - Do NOT trigger swipe on system messages

2. **Long-press context menu**
   - Long-press on `MessageBubble` → `showModalBottomSheet`
   - Bottom sheet content:
     - "Trả lời" (Reply) — `Icons.reply` — always visible, calls `onReply(message)`
     - "Sao chép" (Copy) — `Icons.copy` — only for text messages, copies `message.content` to clipboard
   - Bottom sheet style: `AppColors.surface` background, rounded top corners (16px)
   - Each action: ListTile with leading icon, title text
   - Dismiss on action tap
   - Do NOT show context menu on system messages

3. **Integration with ChatScreen**
   - In `_buildMessageItems()`: wrap each `MessageBubble` with `SwipeToReply` widget
   - Pass `onReply: (msg) => setState(() => _replyingTo = msg)` callback
   - Pass `onLongPress: (msg) => _showMessageActions(msg)` callback
   - `_showMessageActions()` method shows the bottom sheet
   - Both swipe and long-press set `_replyingTo` state → triggers reply preview in input bar

### Integration Points

- `ChatScreen` — wraps bubbles with SwipeToReply, handles onReply callback
- `MessageBubble` — no changes needed (wrapped externally)
- New widget: `SwipeToReply` in `lib/features/chat/widgets/swipe_to_reply.dart`

### Acceptance Criteria

- Swipe right on any non-system message bubble → reply icon appears, haptic at threshold, reply activates on release
- Bubble snaps back smoothly after swipe
- Left swipe does nothing
- Long-press on message → bottom sheet with "Trả lời" option
- Long-press on text message → bottom sheet also shows "Sao chép"
- Tapping "Trả lời" → sets reply state (reply preview appears above input)
- System messages: no swipe, no long-press menu
