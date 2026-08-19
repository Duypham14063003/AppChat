# Tasks: Enhance Web UI v2

## Foundation

- [x] T1: Add `bubbleMine` (#2A2210), `senderColors` (8-color list), update `textHint` to #7A7568 in `app_colors.dart`
- [x] T2: Add `emoji_picker_flutter` dependency to `pubspec.yaml` and run `flutter pub get`

## Message Area

- [x] T3: Fix group sender name bug — in `chat_screen.dart` line 230, pass actual sender name and avatar for group messages instead of null. Requires looking up sender info from message data or a members map.
- [x] T4: Add message grouping params to `MessageBubble` — `isFirstInGroup`, `isLastInGroup`, `showAvatar`, `showSenderName`. Adjust margins: 1px for grouped, 8px for first-in-group. Adjust border radius: tail only on last-in-group.
- [x] T5: Implement grouping logic in `ChatScreen` itemBuilder — compare adjacent messages by senderId and createdAt (5-min window). Compute and pass grouping booleans to each MessageBubble.
- [x] T6: Add date separator widgets — insert between messages from different calendar days. Format: "Hôm nay", "Hôm qua", "dd tháng M", "dd/MM/yyyy". Centered pill with surfaceVariant background.
- [x] T7: Apply `bubbleMine` color to outgoing bubbles in `message_bubble.dart` (replace `gold.withOpacity(0.15)`)
- [x] T8: Add sender name color coding — accept `senderNameColor` param in MessageBubble, use it for sender name text. In ChatScreen, compute color from `senderColors[senderId.hashCode.abs() % 8]`.

## Input Bar

- [x] T9: Wrap TextField in rounded container (surfaceVariant bg, radius 22, 1px card border) in `message_input_bar.dart`
- [x] T10: Add emoji button (left of text field) that toggles an emoji picker panel below the input bar using `emoji_picker_flutter`
- [x] T11: Add attach button (between text field and send) with "Coming soon" SnackBar placeholder

## Conversation Header

- [x] T12: Add search and info action buttons to ChatScreen AppBar with tooltips
- [x] T13: Replace hardcoded "Nhóm chat" subtitle with dynamic member count ("N thành viên") — fetch from conversation detail members list
- [x] T14: Add bottom border (surfaceVariant, 1px) to ChatScreen AppBar for visual separation

## Chat List

- [x] T15: Add online presence dot
- [x] T16: Add group message preview prefix
- [x] T17: Fix avatar initials
- [x] T18: Add subtle separator

## Accessibility & Polish

- [x] T19: Add tooltips to all IconButton widgets across chat_list_screen, chat_screen, message_input_bar, main_shell
- [x] T20: Create `ComingSoonScreen` shared widget (icon + "Tính năng đang phát triển" + "Coming soon")
- [x] T21: Add /hr, /tasks, /profile routes to app_router.dart pointing to ComingSoonScreen
- [x] T22: Wire MainShell navigation destinations to actually navigate to /hr, /tasks, /profile routes

## Verification

- [ ] T23: (Manual) Test on Chrome web — verify message grouping, date separators, bubble contrast
- [ ] T24: (Manual) Test group chat — verify sender names, color coding, avatar display
- [ ] T25: (Manual) Test input bar — emoji picker, attach placeholder, Enter/Shift+Enter behavior
- [ ] T26: (Manual) Test narrow screen (<768px) — verify no regressions on mobile layout
