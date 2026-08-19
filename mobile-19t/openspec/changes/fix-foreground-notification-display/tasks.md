## 1. Shared Foreground Notification Infrastructure

- [x] 1.1 Review and update `PushNotificationService` and `LocalNotificationService` so foreground notifications use one explicit shared display path.
- [x] 1.2 Harden platform-specific foreground presentation prerequisites for Android and iOS, including a valid Android local-notification icon/resource strategy and explicit iOS foreground presentation configuration.
- [x] 1.3 Add explicit error handling and diagnostic logging around notification initialization, permission state, and local notification display calls.

## 2. App-Level Integration

- [x] 2.1 Ensure the app bootstrap / authenticated-session flow initializes the shared foreground notification path reliably before foreground events need to be displayed.
- [x] 2.2 Preserve current route-aware chat suppression and message-id dedupe behavior while reusing the hardened shared display path.
- [x] 2.3 Preserve existing non-chat side effects, including attendance refresh hooks, badge sync hooks, and notification tap navigation.

## 3. Verification

- [x] 3.1 Add or update focused tests for shared foreground notification decision logic and failure-safe notification handling where feasible in this repo.
- [ ] 3.2 Manually verify on Android: while the app is open on HR, chat, and profile screens, trigger chat / HR / leave / reminder notifications and confirm a single foreground banner appears when appropriate.
- [ ] 3.3 Manually verify on iOS: repeat the same scenarios and confirm foreground presentation appears without duplicate banners and active-chat suppression still works.
