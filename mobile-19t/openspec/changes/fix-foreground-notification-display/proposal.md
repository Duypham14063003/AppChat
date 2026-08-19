## Why

The mobile app does not reliably surface notifications while it is already open. Users currently report the same symptom across chat, HR reminders, leave-related notifications, and reminder-style events: no banner appears until the app is backgrounded or closed. This makes time-sensitive notifications easy to miss during normal in-app use.

The current codebase already routes foreground events through shared mobile notification infrastructure (`PushNotificationService`, `LocalNotificationService`, and app-level notification handling in `app.dart`). Because the symptom spans multiple notification types, the problem should be treated as a shared foreground-display bug rather than a feature-specific issue.

The production backend source now lives outside this repository, so this change should stay focused on the mobile foreground presentation path available in this repo.

## What Changes

- Fix the shared mobile foreground notification display flow so notifications can appear while the app is open.
- Harden platform-specific foreground notification configuration for Android and iOS instead of relying on implicit plugin defaults.
- Preserve existing app-level behaviors that already work: notification tap routing, attendance refresh hooks, badge sync hooks, and active-chat suppression for the currently open conversation.
- Add observability around foreground notification initialization and display so silent failures can be diagnosed quickly.
- Add focused verification coverage for shared foreground notification handling and manual validation steps for real-device testing.

## Capabilities

### New Capabilities
<!-- No brand-new product capability is introduced. This is a reliability fix for existing foreground notification behavior. -->

### Modified Capabilities
- `foreground-notification`: Make shared mobile foreground notifications reliable for chat, HR, leave, and reminder events while the app is open.
- `notification-foreground-chat-suppression`: Preserve exact-conversation suppression while moving foreground display onto a hardened shared presentation path.

## Impact

- **Mobile notification infrastructure**: `apps/mobile/lib/core/notifications/push_notification_service.dart`, `apps/mobile/lib/core/notifications/local_notification_service.dart`
- **App bootstrap / integration**: `apps/mobile/lib/app.dart`, auth-driven initialization paths, platform entry points if foreground presentation setup must move earlier
- **Platform configuration**: Android notification icon/resource handling and iOS foreground presentation configuration
- **Verification**: focused mobile notification tests and manual device verification for foreground behavior
