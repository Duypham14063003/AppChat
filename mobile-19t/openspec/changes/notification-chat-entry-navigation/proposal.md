## Why

Opening a chat from a push notification currently lands the user on the conversation without a clear back path on mobile. That makes notification entry feel like an abrupt route replacement instead of a temporary drill-in from the current app context.

## What Changes

- Define notification-driven chat entry behavior so opening a conversation from a chat notification preserves a back affordance on mobile.
- Scope notification chat entry separately from broader notification work such as badge sync, preferences, or notification center features.
- Add verification coverage for notification routing behavior when a chat notification is opened.

## Capabilities

### New Capabilities
- `notification-chat-entry-navigation`: Notification tap navigation into chat that preserves an exit path back to the previous app shell on mobile.

### Modified Capabilities
<!-- No existing capability requirements are being modified. -->

## Impact

- **Flutter app entry routing**: `apps/mobile/lib/app.dart`
- **GoRouter navigation flow**: `apps/mobile/lib/core/router/app_router.dart`
- **Notification navigation tests**: `apps/mobile/test/app_notification_routing_test.dart`
