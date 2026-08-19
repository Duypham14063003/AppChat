## Why

Chat notifications currently behave as if foreground presence does not exist: when the user is online inside the app, the backend skips push delivery entirely, so they receive no notification feedback unless the app is backgrounded or terminated. This creates the wrong user experience for chat because users should not be disturbed while actively reading the same conversation, but they still need a foreground alert when they are elsewhere in the app and another conversation receives a reply.

## What Changes

- Define foreground chat-notification behavior based on the conversation the user is currently viewing.
- Add mobile-side suppression rules so no foreground notification is shown when the user is already inside the matching chat conversation.
- Add mobile-side foreground notification behavior so a local notification is shown when the app is open but the user is on a different screen or a different conversation.
- Align chat notification handling with existing route and conversation context instead of relying only on app background state.
- Add verification coverage for route-aware suppression and foreground notification presentation.

## Capabilities

### New Capabilities
- `notification-foreground-chat-suppression`: Route-aware foreground notification behavior for chat messages that suppresses alerts only for the currently open conversation.

### Modified Capabilities
<!-- No existing capability requirements are being modified. -->

## Impact

- **Mobile notification handling**: `apps/mobile/lib/core/notifications/push_notification_service.dart`, `apps/mobile/lib/core/notifications/local_notification_service.dart`
- **App-level routing context**: `apps/mobile/lib/app.dart`, `apps/mobile/lib/core/router/main_shell.dart`
- **Chat realtime state**: app/chat integration points that can determine the active conversation and incoming `conv_id`
- **Potential backend coordination**: chat push / presence assumptions in `apps/api/src/modules/chat/services/chat.service.ts`
- **Verification**: mobile notification routing / suppression tests
