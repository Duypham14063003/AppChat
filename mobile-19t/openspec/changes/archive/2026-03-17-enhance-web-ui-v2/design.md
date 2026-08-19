# Design: Enhance Web UI v2

## Design Decisions

### D1: Message Grouping Strategy

Consecutive messages from the same sender within a 5-minute window are grouped:
- First message in group: show avatar + sender name (in group chats)
- Middle messages: hide avatar (use SizedBox placeholder for alignment), hide sender name, reduce vertical margin to 1px
- Last message in group: show avatar at bottom (like Telegram)
- A new group starts when: different sender, time gap > 5 minutes, date changes, or system message interrupts

Implementation: Add `showAvatar`, `showSenderName`, `isFirstInGroup`, `isLastInGroup` boolean params to `MessageBubble`. Compute grouping logic in `ChatScreen`'s `itemBuilder` by comparing adjacent messages.

### D2: Date Separator Format

Insert date separator widgets between messages from different calendar days:
- Today: "Hôm nay"
- Yesterday: "Hôm qua"
- This year: "16 tháng 3" (Vietnamese format)
- Other years: "16/03/2025"

Visual: centered text in a pill-shaped container with `surfaceVariant` background, `textSecondary` color, `fontSize: 12`. Horizontal lines on each side (divider style).

Implementation: Build a combined list of messages + date separators in `ChatScreen` before passing to `ListView.builder`. Since the list is reversed, insert separators when `messages[i].createdAt.day != messages[i+1].createdAt.day`.

### D3: Outgoing Bubble Color

Replace `AppColors.gold.withOpacity(0.15)` (renders as ~#1A1710, nearly invisible) with a new constant:

```dart
static const Color bubbleMine = Color(0xFF2A2210); // dark warm gold tint
```

This provides clear visual distinction from incoming bubbles (`#141418` surface) while staying within the dark theme. Contrast ratio between the two: ~1.5:1 which is sufficient for decorative/container differentiation.

### D4: Sender Name Color Palette (Telegram-style)

8-color palette for group chat sender names, assigned by hashing sender ID:

```dart
static const List<Color> senderColors = [
  Color(0xFFE57373), // red
  Color(0xFF81C784), // green
  Color(0xFF64B5F6), // blue
  Color(0xFFFFB74D), // orange
  Color(0xFFBA68C8), // purple
  Color(0xFF4DD0E1), // cyan
  Color(0xFFF06292), // pink
  Color(0xFFAED581), // lime
];
```

Assignment: `senderColors[senderId.hashCode.abs() % 8]`

All colors chosen to pass WCAG AA (4.5:1) against `#141418` surface background.

### D5: Input Bar Redesign

Layout change:
```
BEFORE: [TextField                              ] [Send]
AFTER:  [Emoji] [ ┌─────────────────────┐ ] [Attach] [Send]
                 │ Nhập tin nhắn...      │
                 └─────────────────────┘
```

- TextField wrapped in a rounded container: `surfaceVariant` (#1E1E24) background, `BorderRadius.circular(22)`, 1px border `#28282F`
- Emoji button: `Icons.emoji_emotions_outlined`, left of text field, opens `emoji_picker_flutter` bottom sheet
- Attach button: `Icons.attach_file`, right of text field, shows "Coming soon" SnackBar for now
- Preserve existing Enter-to-send / Shift+Enter behavior

### D6: Conversation Header Enhancement

AppBar actions added:
- Search icon: `Icons.search` — placeholder, shows SnackBar "Coming soon"
- Info icon: `Icons.info_outline` — navigates to group info (groups) or user profile (DMs)

Group subtitle change:
- Current: hardcoded "Nhóm chat"
- New: fetch member count from conversation members API, display "N thành viên"
- Fallback: "Nhóm chat" if count unavailable

Bottom border: Add `bottom` property to AppBar's `shape` or use a `PreferredSize` widget with a bottom border.

### D7: Chat List Enhancements

Online presence dot:
- 10px green circle (#2ECC71) with 2px dark border, positioned bottom-right of avatar using `Stack` + `Positioned`
- Show for DIRECT conversations where `otherMemberLastSeenAt` is within 2 minutes

Group preview prefix:
- For GROUP conversations, prepend sender name to lastMessageContent: "An: hello"
- Requires `lastMessageSenderId` (already stored) + a way to resolve sender name
- Approach: store `lastMessageSenderName` in local conversation table, or use a simple lookup

Initials fix:
- Split name by spaces, take first character of first and last word: "Nguyễn Văn An" → "NA"
- Fallback to single character if only one word

Tile spacing:
- Add 1px divider between tiles using `ListView.separated` or `Divider` widget

### D8: Accessibility Fixes

textHint color change:
- Current: `#5A5648` (2.8:1 contrast on #0A0A0A — fails WCAG AA)
- New: `#7A7568` (4.5:1 contrast on #0A0A0A — passes WCAG AA)

Tooltips:
- Add `tooltip` parameter to all `IconButton` widgets across the app
- Vietnamese labels: "Tìm kiếm", "Thêm mới", "Đóng", "Gửi", "Emoji", "Đính kèm", "Thông tin"

### D9: Navigation Stub Handling

Current: HR/Tasks/Profile tabs do nothing on tap.
New: Navigate to a shared `ComingSoonScreen` placeholder:
- Centered icon + "Tính năng đang phát triển" text
- Consistent with the app's empty state pattern
- Route: each tab navigates to its own route that renders the placeholder

## Files to Modify

| File | Changes |
|------|---------|
| `lib/core/theme/app_colors.dart` | Add `bubbleMine`, `senderColors`, update `textHint` |
| `lib/features/chat/widgets/message_bubble.dart` | Grouping params, new bubble color, sender color |
| `lib/features/chat/widgets/message_input_bar.dart` | Rounded field, emoji button, attach button |
| `lib/features/chat/widgets/conversation_tile.dart` | Online dot, initials fix, group prefix, divider |
| `lib/features/chat/screens/chat_screen.dart` | Fix sender name bug, message grouping logic, date separators, header actions, member count |
| `lib/core/router/main_shell.dart` | Wire stub tabs to coming-soon routes |
| `lib/core/router/app_router.dart` | Add coming-soon routes |
| `lib/shared/widgets/coming_soon_screen.dart` | New placeholder screen (small) |

## Dependencies

- `emoji_picker_flutter` package for emoji picker (D5)
- No backend changes required
- No database schema changes required
