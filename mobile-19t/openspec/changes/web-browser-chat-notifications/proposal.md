## Why

Web chat users currently do not receive visible browser notifications for incoming messages while the app is open, even though mobile clients already surface foreground notifications. This makes desktop chat easier to miss and creates an inconsistent notification experience across platforms.

## What Changes

- Add a web-specific browser notification path for incoming chat messages.
- Request and track browser notification permission on web so the app can surface message alerts intentionally.
- Route eligible foreground chat events on web through the Browser Notification API instead of relying only on the native-focused local notification plugin.
- Reuse existing chat notification suppression logic so notifications are not shown when the user is already viewing the active conversation.
- Keep the current Android, iOS, and macOS local foreground notification behavior unchanged.

## Capabilities

### New Capabilities
- `web-browser-chat-notifications`: Browser notification delivery, permission handling, and foreground chat alert display for web clients.

### Modified Capabilities
- `notification-foreground-chat-suppression`: Extend the existing suppression behavior so it also governs whether web browser notifications appear for active chat routes.

## Impact

- Affected code will center on `apps/mobile/lib/app.dart`, notification services under `apps/mobile/lib/core/notifications/`, and web notification bootstrap behavior.
- The change will rely on the browser Notification API for web foreground alerts while preserving the current Firebase service worker flow for background notifications.
- No backend API contract changes are required if the existing incoming chat data continues to include sender, conversation, and message identifiers.
