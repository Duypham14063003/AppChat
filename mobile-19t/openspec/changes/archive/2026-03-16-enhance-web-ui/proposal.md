## Why

The Flutter app is built with a mobile-first layout — full-screen push navigation, bottom NavigationBar, ModalBottomSheet for actions, and no responsive breakpoints. When run on web (`flutter run -d chrome`), the UI stretches awkwardly: message bubbles span up to 75% of a 1440px screen (1080px wide), the bottom nav wastes horizontal space, and users must click the send button instead of pressing Enter. The app needs a responsive web layout that feels native on desktop browsers while preserving the existing mobile experience.

## What Changes

Flutter (Mobile) — all changes are in `apps/mobile/lib/`:

- Add a responsive breakpoint utility (`isWideScreen` at ≥768px) using `MediaQuery` or `LayoutBuilder`
- Refactor `MainShell` to use `NavigationRail` on wide screens instead of bottom `NavigationBar`
- Implement master-detail layout for chat: wide screens show `ChatListScreen` as a persistent left sidebar with `ChatScreen` as the right panel, eliminating full-screen push navigation for `/chat/:id`
- Cap `MessageBubble` max-width at `min(screenWidth * 0.75, 480)` instead of unbounded 75%
- Add Enter-to-send / Shift+Enter-for-newline keyboard handling in `MessageInputBar` on web/desktop platforms
- Convert `ContactPickerScreen` and group creation screens to render as dialogs on wide screens instead of full-screen pushes
- Replace `ModalBottomSheet` for new chat action with a `PopupMenuButton` or dialog on wide screens

## Capabilities

### New Capabilities
- `responsive-shell`: Adaptive MainShell that switches between NavigationBar (mobile) and NavigationRail (wide) based on screen width breakpoint
- `master-detail-chat`: Side-by-side chat list + chat screen layout on wide screens with synchronized selection state
- `web-input-behavior`: Platform-aware keyboard handling — Enter sends on web/desktop, Shift+Enter for newline
- `web-dialog-screens`: Contact picker and group creation screens render as constrained dialogs on wide screens
- `bubble-width-cap`: Message bubble max-width capped at 480px regardless of screen size

### Modified Capabilities
- None (all new capabilities layered on top of existing mobile UI)

## Impact

- **Flutter**: Modified files: `main_shell.dart`, `app_router.dart`, `chat_list_screen.dart`, `chat_screen.dart`, `message_input_bar.dart`, `message_bubble.dart`, `contact_picker_screen.dart`, `group_create_members_screen.dart`, `group_create_name_screen.dart`. Possibly new file: responsive utility helper.
- **Backend**: No changes.
- **Database**: No changes.
- **Dependencies**: No new dependencies — uses `dart:foundation` (`kIsWeb`), `MediaQuery`, `LayoutBuilder`, `NavigationRail`, all built into Flutter SDK.
