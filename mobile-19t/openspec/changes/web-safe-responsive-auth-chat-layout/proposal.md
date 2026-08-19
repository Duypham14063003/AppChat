## Why

The Flutter app is beginning to run on the web, but several screens still behave like stretched mobile layouts on large viewports. The current login and chat experiences look broken on desktop-sized canvases, while the mobile layout is already stable and must remain unchanged.

## What Changes

- Add wide-screen layout rules for the login screen so authentication content renders inside a centered, bounded frame instead of stretching across the full browser width.
- Add wide-screen conversation layout rules for the chat screen so the message timeline, pinned bar, typing indicator, composer, and related controls share a centered content frame inside the existing desktop chat pane.
- Keep the desktop shell split behavior with navigation rail and embedded chat list, while refining only the conversation pane internals.
- Preserve existing mobile and narrow-tablet behavior so current phone layouts, spacing, and interaction patterns do not regress.
- Verify that adjacent chat surfaces such as search mode, empty state, scroll-to-bottom FAB, and bookmark/pin affordances continue to align correctly after the responsive layout changes.

## Capabilities

### New Capabilities
- `responsive-auth-web-layout`: Defines how the authentication UI should adapt to wide web/desktop viewports without changing mobile behavior.
- `responsive-chat-web-layout`: Defines how the chat conversation pane should constrain and align content on wide web/desktop viewports while preserving current mobile interaction patterns.

### Modified Capabilities
- None.

## Impact

- Affected Flutter UI code in `apps/mobile/lib/features/auth/screens/login_screen.dart`
- Affected Flutter chat layout code in `apps/mobile/lib/features/chat/screens/chat_screen.dart`, `apps/mobile/lib/features/chat/widgets/message_input_bar.dart`, and nearby chat presentation widgets
- Uses existing wide-screen shell behavior in `apps/mobile/lib/core/router/main_shell.dart` as an integration constraint
- No backend, API, database, or websocket contract changes
