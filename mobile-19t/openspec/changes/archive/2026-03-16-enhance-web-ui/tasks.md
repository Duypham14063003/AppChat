## 1. Bubble Width Cap

- [x] 1.1 In `message_bubble.dart`: change `maxWidth: MediaQuery.of(context).size.width * 0.75` to `maxWidth: min(MediaQuery.of(context).size.width * 0.75, 480)`. Import `dart:math` for `min`.
- [ ] 1.2 Verify: on a wide browser window, bubbles do not exceed 480px width. On mobile-width window, bubbles still use 75% of screen width.

## 2. Enter-to-Send on Web

- [x] 2.1 In `message_input_bar.dart`: import `package:flutter/foundation.dart` for `kIsWeb`. Add a `FocusNode _focusNode` field, initialize in `initState`, dispose in `dispose`, attach to the `TextField` via `focusNode: _focusNode`.
- [x] 2.2 In `message_input_bar.dart`: set `_focusNode.onKeyEvent` callback. On `kIsWeb`: if `KeyDownEvent` with `LogicalKeyboardKey.enter` and NOT `HardwareKeyboard.instance.isShiftPressed` → call `_send()`, return `KeyEventResult.handled`. Otherwise return `KeyEventResult.ignored`. On non-web: return `KeyEventResult.ignored` (no change).
- [x] 2.3 In `message_input_bar.dart`: on web, change `textInputAction` to `TextInputAction.none` (prevent default Enter behavior). On mobile, keep `TextInputAction.newline`.
- [x] 2.4 In `message_input_bar.dart`: after `_send()`, call `_focusNode.requestFocus()` to retain focus in the input field.
- [ ] 2.5 Verify: on web, Enter sends message, Shift+Enter inserts newline, focus stays in input after send. On mobile, Enter inserts newline as before.

## 3. Responsive Shell — NavigationRail

- [x] 3.1 In `main_shell.dart`: wrap the `build` method body with `LayoutBuilder`. Check `constraints.maxWidth >= 768`. If wide: render a `Row` with `NavigationRail` (left) + `Expanded(child)` (right). If narrow: render current `Scaffold` with bottom `NavigationBar`.
- [x] 3.2 `NavigationRail` config: `selectedIndex: _currentIndex`, `backgroundColor: AppColors.surface`, `indicatorColor: AppColors.gold.withOpacity(0.15)`, `labelType: NavigationRailLabelType.all`, destinations matching the 4 existing tabs (Chat, HR, Tasks, Profile) with same icons and colors.
- [ ] 3.3 Verify: on wide screen, NavigationRail appears on left, no bottom bar. On narrow screen, bottom NavigationBar appears, no rail. Resizing window toggles between them.

## 4. Master-Detail Chat Layout

- [x] 4.1 In `main_shell.dart`: on wide screens, when the current route starts with `/chat`, render a `Row` with: (a) `SizedBox(width: 320, child: ChatListScreen())` as left panel, (b) `VerticalDivider(width: 1, color: AppColors.surfaceVariant)`, (c) `Expanded(child: child)` as right panel. The `child` from the router is the `ChatScreen` or empty state.
- [x] 4.2 In `main_shell.dart`: when on wide screen and route is exactly `/chat` (no conversation selected), show an empty state widget in the right panel: centered `Column` with chat icon and "Chọn cuộc trò chuyện" text.
- [x] 4.3 In `chat_list_screen.dart`: accept an optional `isEmbedded` parameter (default false). When `isEmbedded` is true: remove the `Scaffold`/`AppBar` wrapper (return just the body content), and use `context.go('/chat/$id')` instead of `context.push('/chat/$id')` for navigation.
- [x] 4.4 In `chat_list_screen.dart`: when `isEmbedded` is true, accept an optional `selectedConversationId` parameter. Highlight the selected conversation tile with `AppColors.surfaceVariant` background in `ConversationTile`.
- [x] 4.5 In `conversation_tile.dart`: add an optional `isSelected` parameter. When true, set `ListTile.tileColor` to `AppColors.surfaceVariant`.
- [x] 4.6 In `chat_screen.dart`: on wide screens (≥768px), hide the AppBar back button (no `leading` back arrow) since navigation is via the sidebar.
- [ ] 4.7 Verify: on wide screen, chat list is persistent on the left, selecting a conversation shows it on the right, selected tile is highlighted. On narrow screen, full-screen push navigation works as before.

## 5. Dialog Screens on Wide Screens

- [x] 5.1 In `chat_list_screen.dart`: on wide screens (≥768px), replace `showModalBottomSheet` with `showMenu` or a custom popup positioned near the FAB. Show "Chat mới" and "Tạo nhóm" as menu items.
- [x] 5.2 In `chat_list_screen.dart`: on wide screens, "Chat mới" opens `ContactPickerScreen` content via `showDialog()` with a constrained `Dialog(child: SizedBox(width: 480, height: 600, child: ...))`. On narrow screens, keep `context.push('/contacts/pick')`.
- [x] 5.3 In `chat_list_screen.dart`: on wide screens, "Tạo nhóm" opens `GroupCreateMembersScreen` content via `showDialog()` similarly. On narrow screens, keep `context.push('/group/create/members')`.
- [x] 5.4 In `contact_picker_screen.dart`: extract the body content into a reusable widget (e.g., `ContactPickerBody`) that can be used both in the full-screen `Scaffold` and inside a `Dialog`. The `onConversationCreated` callback navigates appropriately (dialog: close dialog + `context.go('/chat/$id')`, full-screen: `context.pushReplacement('/chat/$id')`).
- [x] 5.5 In `group_create_members_screen.dart`: similarly extract body content. On wide screen dialog, "Tiếp" opens the name screen as another dialog (close current, open new). On narrow screen, keep `context.push`.
- [x] 5.6 In `group_create_name_screen.dart`: similarly extract body content. On wide screen dialog, after group creation, close dialog and navigate to the new conversation.
- [ ] 5.7 Verify: on wide screen, contact picker and group creation appear as centered dialogs. On narrow screen, they appear as full-screen pages. Full flow works end-to-end in both modes.

## 6. Final Verification

- [ ] 6.1 Run `flutter analyze` in `apps/mobile` — no errors.
- [ ] 6.2 Test on Chrome (wide window): NavigationRail visible, master-detail chat works, Enter sends, dialogs for contact/group, bubbles capped at 480px.
- [ ] 6.3 Test on Chrome (narrow window / mobile emulation): bottom nav, full-screen push, Enter inserts newline, bottom sheet for new chat, bubbles at 75%.
- [ ] 6.4 Test window resize across 768px threshold — layout switches smoothly.
