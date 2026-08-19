## Why

The mobile chat client currently treats a conversation as "actively viewed" based on screen lifecycle alone, clearing that state only when `ChatScreen` is disposed. In the current router setup, chat routes can remain mounted while no longer visible, which causes off-screen conversations to keep sending read receipts and incorrectly auto-seeing new messages.

## What Changes

- Replace dispose-only active chat tracking with visibility/route-based tracking for mobile chat conversations.
- Ensure a conversation is considered actively viewed only while the chat route is foregrounded in the current navigation branch and the app is in an interactive state.
- Stop automatic `mark_read` websocket sends for conversations that remain mounted but are no longer visible.
- Keep existing chat read and unread reconciliation behavior for truly active conversations.

## Capabilities

### New Capabilities
- `chat-active-visibility-tracking`: Define when a mobile chat conversation is allowed to auto-mark messages as read based on route visibility and app foreground state.

### Modified Capabilities
- None.

## Impact

- Affected mobile chat screen lifecycle handling in `apps/mobile/lib/features/chat/screens/chat_screen.dart`.
- Affected chat active-state and read-receipt gating in `apps/mobile/lib/features/chat/providers/chat_providers.dart`.
- Affected router/navigation integration in `apps/mobile/lib/core/router/app_router.dart` and `apps/mobile/lib/core/router/main_shell.dart`.
- No backend API changes are required; websocket `mark_read` behavior remains the transport, but it is triggered under stricter client-side conditions.
