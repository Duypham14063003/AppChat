## Context

The app is a Flutter mobile/web chat application with a mobile-only layout. All screens use full-screen push/pop navigation via `go_router` `ShellRoute`. The shell (`MainShell`) wraps all authenticated routes with a bottom `NavigationBar`. Chat screens (`ChatListScreen`, `ChatScreen`) are separate full-screen routes. `MessageBubble` uses `MediaQuery.of(context).size.width * 0.75` for max-width. `MessageInputBar` has no keyboard shortcut handling. `ContactPickerScreen` and group creation screens are full-screen pushes.

Current file structure:
- `lib/core/router/main_shell.dart` — shell with bottom NavigationBar
- `lib/core/router/app_router.dart` — GoRouter with ShellRoute
- `lib/features/chat/screens/chat_list_screen.dart` — conversation list
- `lib/features/chat/screens/chat_screen.dart` — message view
- `lib/features/chat/widgets/message_input_bar.dart` — text input + send button
- `lib/features/chat/widgets/message_bubble.dart` — message bubble widget
- `lib/features/chat/screens/contact_picker_screen.dart` — single contact picker
- `lib/features/chat/screens/group_create_members_screen.dart` — multi-select picker
- `lib/features/chat/screens/group_create_name_screen.dart` — group name input

## Goals / Non-Goals

**Goals:**
- Responsive layout that adapts at 768px breakpoint
- Master-detail chat layout on wide screens (list + conversation side by side)
- NavigationRail on wide screens, NavigationBar on narrow
- Enter-to-send on web/desktop, Shift+Enter for newline
- Capped bubble width (max 480px)
- Dialog-based contact picker and group creation on wide screens
- Preserve existing mobile UX unchanged on narrow screens

**Non-Goals:**
- Light theme / theme switching
- Drag-to-resize panels
- Keyboard shortcuts beyond Enter/Shift+Enter (e.g., Ctrl+K for search)
- Desktop-specific features (system tray, native menus)
- Rewriting navigation to use a different router

## Decisions

### D1: Breakpoint strategy
**Decision**: Single breakpoint at 768px. Use `MediaQuery.of(context).size.width >= 768` check. No intermediate breakpoints.
**Rationale**: The app has 4 nav tabs (only Chat active). 768px is standard tablet/desktop threshold. A single breakpoint keeps complexity low — the app is for <50 employees, not a public product needing pixel-perfect responsive tiers.

### D2: Master-detail implementation approach
**Decision**: Implement master-detail inside `MainShell` using a `Row` layout. On wide screens, `MainShell` renders `ChatListScreen` as a fixed-width left panel (320px) and the router's `child` as the right panel. When on `/chat` route (no conversation selected), show an empty state in the right panel. When on `/chat/:id`, show `ChatScreen` in the right panel. On narrow screens, keep current full-screen push behavior.
**Rationale**: Implementing at the shell level avoids deep changes to the router. The `ShellRoute` already passes `child` — we just need to conditionally render it alongside the chat list. This is the simplest approach that doesn't require nested navigators or `StatefulShellRoute`.

### D3: Wide-screen navigation for chat list
**Decision**: On wide screens, tapping a conversation in `ChatListScreen` uses `context.go('/chat/$id')` (replace, not push) so the right panel updates without stacking routes. On narrow screens, keep `context.push('/chat/$id')`.
**Rationale**: `go()` replaces the current route, which is correct for master-detail — we don't want a back stack of conversations in the right panel. `push()` is correct for mobile where we need the back button.

### D4: Enter-to-send platform detection
**Decision**: Use `kIsWeb` from `dart:foundation` to detect web platform. On web, intercept `KeyDownEvent` on the `TextField`'s `FocusNode.onKeyEvent`. If Enter without Shift → call `_send()` and return `KeyEventResult.handled`. If Shift+Enter → return `KeyEventResult.ignored` (TextField handles newline). On non-web, no change.
**Rationale**: `kIsWeb` is the simplest and most reliable check. Desktop platforms (macOS, Windows, Linux) could also benefit from Enter-to-send, but the user specifically asked for web. Can extend later with `Platform` checks if needed.

### D5: Dialog screens on wide screens
**Decision**: `ContactPickerScreen`, `GroupCreateMembersScreen`, and `GroupCreateNameScreen` will check `isWideScreen` in their build methods. On wide screens, wrap their content in a `Dialog` (constrained to 480px width, 600px height) shown via `showDialog()`. The navigation from `ChatListScreen` will call `showDialog()` directly on wide screens instead of `context.push()`.
**Rationale**: Dialogs feel natural on desktop for picker/creation flows. Constraining to 480x600 keeps them compact. The screens already have their own `Scaffold` — on wide screens we wrap the body content in a `Dialog` instead.

### D6: New chat action on wide screens
**Decision**: Replace `ModalBottomSheet` with `PopupMenuButton` on wide screens. The FAB stays but its `onPressed` shows a popup menu anchored to the FAB position instead of a bottom sheet.
**Rationale**: Bottom sheets are a mobile pattern. Popup menus are the desktop equivalent for contextual actions. Anchoring to the FAB keeps the interaction consistent.

### D7: Chat list sidebar width
**Decision**: Fixed 320px width for the chat list sidebar on wide screens.
**Rationale**: 320px fits conversation tiles well (avatar + name + preview + timestamp). Matches common sidebar widths in Slack/Teams/Telegram desktop. No need for resizable panels at this stage.

### D8: Selected conversation highlighting
**Decision**: In `ChatListScreen`, when in wide-screen master-detail mode, highlight the currently selected conversation tile using `AppColors.surfaceVariant` background. Derive the selected conversation ID from the current route location.
**Rationale**: Visual feedback for which conversation is active is essential in master-detail layouts. Using the route as source of truth avoids extra state management.
