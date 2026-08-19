## Why

When a user taps a chat notification from the lock screen or background state, the mobile app can navigate directly into the chat conversation while the WebSocket session is still disconnected. The chat UI then remains stuck on the "No connection" state until the user force-closes and reopens the app.

This needs to be fixed now because notification-driven chat entry is a primary path for replying to messages, and it must recover the realtime connection reliably after device lock, app resume, token refresh, and deep-link navigation races.

## What Changes

- Ensure chat notification taps trigger or verify WebSocket reconnection for authenticated sessions before or immediately after navigating into the conversation.
- Ensure app resume from lock screen/background also prompts WebSocket recovery when the user is authenticated and the connection is not connected.
- Harden WebSocket auth/reconnect behavior so token refresh and auth-error paths do not leave the manager permanently disconnected.
- Keep existing notification routing behavior and chat navigation destinations unchanged.
- Add focused tests for notification tap reconnect, lifecycle resume reconnect, and stale-token/auth-error recovery behavior.

## Capabilities

### New Capabilities
- `notification-tap-websocket-reconnect`: Mobile chat notification entry restores realtime WebSocket connectivity after lock screen/background notification taps.

### Modified Capabilities
<!-- No existing archived capability requirements are being modified. -->

## Impact

- Mobile app lifecycle handling in `apps/mobile/lib/app.dart`.
- Notification tap routing through `PushNotificationService` and app-level handlers.
- WebSocket connection management in `apps/mobile/lib/core/network/websocket_manager.dart` and `websocket_provider.dart`.
- Auth token refresh coordination in `apps/mobile/lib/features/auth/data/auth_interceptor.dart`.
- Mobile tests covering lifecycle, notification routing, and WebSocket reconnect state.
