## Why

The 19T app has basic FCM push infrastructure (FirebaseService, PushNotificationProcessor, token management) but critical gaps remain: no foreground notification banner, no desktop notification support (Windows/macOS), no background message handler, no notification center, no user preferences, no badge sync. Users on PC, macOS, Android, and iOS all need to receive notifications when messages arrive. The SRS defines 10 notification FRs (NOTIF-FR-001 through 010), all P0-P2.

## What Changes

Backend (NestJS — enhance existing):
- Add `notification_preferences` table and entity for per-user notification settings (quiet hours, per-type toggles)
- Enhance `PushNotificationProcessor` to check quiet hours and user preferences before sending
- Add notification grouping logic: collapse multiple messages from same conversation into single push
- Add `notifications` table for notification center history (persisted notifications)
- Add REST endpoints: GET/PATCH notification preferences, GET notification history, PATCH mark-as-read
- Enhance FCM payload with platform-specific config: Android notification channel, iOS badge count, macOS category

Frontend (Flutter — all platforms):
- Integrate `flutter_local_notifications` for foreground notification display on Android, iOS, macOS, Windows
- Add background message handler (`@pragma('vm:entry-point')` top-level function) for Android/iOS
- Add notification tap → deep link navigation to target conversation
- Desktop: integrate `system_tray` package for minimize-to-tray behavior (Windows/macOS)
- Desktop: WebSocket-based notification — when new_message arrives and app is minimized, show system notification via `flutter_local_notifications`
- Add Notification Center screen (history list, mark read/unread, filter by type)
- Add Notification Preferences screen (toggle per type, quiet hours config)
- Add badge count sync: iOS/macOS app icon badge, Android notification badge
- Default system notification sounds (no custom sounds)

## Capabilities

### New Capabilities
- `foreground-notification`: Display local notification banner when app is in foreground across all platforms (Android, iOS, Web, Windows, macOS) using flutter_local_notifications
- `desktop-notification`: System tray integration + WebSocket-based notification for Windows/macOS desktop — minimize on close, show toast/notification center alerts when messages arrive
- `notification-center`: Persisted notification history with REST API + Flutter UI — list, filter by type, mark read/unread
- `notification-preferences`: Per-user notification settings — quiet hours, per-type toggles (chat, call, HR, task), mute override for mentions
- `background-push-handler`: Top-level background message handler for Android/iOS — process data-only FCM messages when app is terminated/backgrounded
- `notification-deep-link`: Tap notification → navigate to target conversation/screen across all platforms and app states (foreground, background, terminated)
- `badge-count-sync`: Sync unread count to app icon badge (iOS/macOS) and notification badge (Android)
- `notification-grouping`: Server-side grouping of multiple messages from same conversation into single push notification

### Modified Capabilities
<!-- No existing spec-level requirements are changing. Existing FCM infrastructure is enhanced, not modified at spec level. -->

## Impact

- **Database**: New `notification_preferences` table, new `notifications` table (notification center history). No changes to existing tables.
- **API**: New REST endpoints under `/notifications` (preferences, history). No changes to existing endpoints.
- **Backend services**: Enhanced `PushNotificationProcessor` with preference/quiet-hours checks. New `NotificationHistoryService`.
- **Flutter packages**: New dependencies: `flutter_local_notifications`, `system_tray` (or `tray_manager`). Existing: `firebase_messaging` (already installed).
- **Flutter UI**: New screens: NotificationCenterScreen, NotificationPreferencesScreen. Modified: all entry points (main_*.dart) for background handler registration.
- **Platform config**: Android notification channel setup, iOS/macOS entitlements for push, Windows system tray manifest.
- **Web**: Enhanced `firebase-messaging-sw.js` for notification click handling.

