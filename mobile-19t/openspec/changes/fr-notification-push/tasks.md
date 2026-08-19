## 1. Backend: Database & Entities

- [ ] 1.1 Create migration `apps/api/src/migrations/1710600000007-NotificationPreferences.ts`: `notification_preferences` table — `user_id` (uuid PK, FK→users ON DELETE CASCADE), `chat_enabled` (boolean DEFAULT true), `call_enabled` (boolean DEFAULT true), `hr_enabled` (boolean DEFAULT true), `task_enabled` (boolean DEFAULT true), `quiet_hours_enabled` (boolean DEFAULT false), `quiet_hours_start` (time DEFAULT '22:00'), `quiet_hours_end` (time DEFAULT '07:00'), `created_at` (timestamptz DEFAULT now()), `updated_at` (timestamptz DEFAULT now())
- [ ] 1.2 Create migration `apps/api/src/migrations/1710600000008-Notifications.ts`: `notifications` table — `id` (uuid PK), `user_id` (uuid FK→users ON DELETE CASCADE), `type` (varchar(30) NOT NULL), `title` (varchar NOT NULL), `body` (text), `data` (jsonb), `is_read` (boolean DEFAULT false), `created_at` (timestamptz DEFAULT now()). Index on `(user_id, created_at DESC)`, index on `(user_id, is_read)`
- [ ] 1.3 Create `NotificationPreference` TypeORM entity at `apps/api/src/modules/notification/entities/notification-preference.entity.ts`
- [ ] 1.4 Create `Notification` TypeORM entity at `apps/api/src/modules/notification/entities/notification.entity.ts`
- [ ] 1.5 Register both entities in `NotificationModule`'s `TypeOrmModule.forFeature()`

## 2. Backend: Notification Preferences API

- [ ] 2.1 Create `NotificationPreferenceService` at `apps/api/src/modules/notification/services/notification-preference.service.ts`: `getPreferences(userId)` (upsert default if not exists), `updatePreferences(userId, dto)`, `isQuietHours(userId)` (check current time against user's quiet hours in their timezone)
- [ ] 2.2 Create DTOs: `UpdateNotificationPreferencesDto` with optional fields for each preference column
- [ ] 2.3 Create `NotificationController` at `apps/api/src/modules/notification/notification.controller.ts`: `GET /notifications/preferences`, `PATCH /notifications/preferences`
- [ ] 2.4 Register controller and service in `NotificationModule`

## 3. Backend: Notification Center API

- [ ] 3.1 Create `NotificationHistoryService` at `apps/api/src/modules/notification/services/notification-history.service.ts`: `createNotification(userId, type, title, body, data)`, `getNotifications(userId, cursor, type, limit)`, `markRead(userId, notificationId)`, `markAllRead(userId)`, `getUnreadCount(userId)`
- [ ] 3.2 Add endpoints to `NotificationController`: `GET /notifications` (paginated history), `GET /notifications/unread-count`, `PATCH /notifications/:id/read`, `PATCH /notifications/read-all`
- [ ] 3.3 Integrate `NotificationHistoryService` into `PushNotificationProcessor`: after sending push, call `createNotification()` to persist in history

## 4. Backend: Enhanced Push Processor

- [ ] 4.1 Inject `NotificationPreferenceService` into `PushNotificationProcessor`
- [ ] 4.2 Add preference check: before sending push, verify `chat_enabled` is true for the recipient (skip if disabled)
- [ ] 4.3 Add quiet hours check: before sending push, call `isQuietHours(userId)` — skip push if in quiet hours (still persist to notification history)
- [ ] 4.4 Add notification grouping: use Redis INCR on `notif:group:{userId}:{convId}` with 30s TTL. If count > 1, send grouped body "{sender} sent {N} new messages". Use conv_id as Android `tag` for notification replacement
- [ ] 4.5 Enhance FCM payload: calculate total unread count for user, include as `apns.payload.aps.badge` and `data.badge_count`. Add `data.conv_id`, `data.sender_name`, `data.conv_type`, `data.conv_name` for client-side formatting
- [ ] 4.6 Add mention-aware notification: if message metadata contains mentions and user is mentioned, override mute and send with title "{sender} mentioned you in {group}"

## 5. Flutter: Install Dependencies

- [ ] 5.1 Add `flutter_local_notifications` package to `apps/mobile/pubspec.yaml`
- [ ] 5.2 Add `system_tray` package to `apps/mobile/pubspec.yaml`
- [ ] 5.3 Android: configure notification channel in `AndroidManifest.xml` — add `<meta-data android:name="com.google.firebase.messaging.default_notification_channel_id" android:value="chat_messages"/>`
- [ ] 5.4 iOS: verify push notification entitlement in `Runner.entitlements`, add `UIBackgroundModes` (remote-notification) to `Info.plist`
- [ ] 5.5 macOS: add push notification entitlement in `Runner.entitlements`, enable `com.apple.security.network.client` and push capabilities in Xcode

## 6. Flutter: Local Notification Service

- [ ] 6.1 Create `LocalNotificationService` at `apps/mobile/lib/core/notifications/local_notification_service.dart`: initialize `FlutterLocalNotificationsPlugin` with platform-specific settings (Android channel, iOS/macOS presentation options, Windows app name)
- [ ] 6.2 Add `showNotification(id, title, body, payload)` method — payload is JSON string with conv_id for navigation
- [ ] 6.3 Add notification tap callback: parse payload, extract conv_id, trigger navigation via GoRouter
- [ ] 6.4 Add `activeConversationId` tracking: set when user enters ChatScreen, clear when leaves. Suppress notification if incoming conv_id matches active conversation
- [ ] 6.5 Create Riverpod provider `localNotificationServiceProvider`

## 7. Flutter: Foreground Notification Handler

- [ ] 7.1 Update `PushNotificationService._handleForegroundMessage()`: instead of debugPrint, call `LocalNotificationService.showNotification()` with title/body from FCM message, suppressing if active conversation matches
- [ ] 7.2 Add desktop-specific handler: register WS `new_message` listener that calls `LocalNotificationService.showNotification()` when app is minimized or user is not in target conversation (Windows/macOS only)
- [ ] 7.3 Format notification content: DM → title: sender name, body: message preview. Group → title: group name, body: "{sender}: {preview}"

## 8. Flutter: Background Message Handler

- [ ] 8.1 Create top-level `@pragma('vm:entry-point')` function `firebaseMessagingBackgroundHandler` in a separate file `apps/mobile/lib/core/notifications/background_handler.dart`
- [ ] 8.2 Register handler in all entry points (main.dart, main_dev.dart, main_staging.dart, main_prod.dart): `FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler)`
- [ ] 8.3 In background handler: show local notification via `flutter_local_notifications` (must re-initialize plugin in isolate)

## 9. Flutter: Desktop System Tray

- [ ] 9.1 Create `SystemTrayService` at `apps/mobile/lib/core/notifications/system_tray_service.dart`: initialize system tray with app icon, context menu (Show/Quit), tooltip
- [ ] 9.2 Override window close behavior on desktop: intercept close event, minimize to tray instead of quitting (use `window_manager` or `system_tray` API)
- [ ] 9.3 Update tray tooltip with unread count when new messages arrive
- [ ] 9.4 Handle "Show" menu item: restore and focus window
- [ ] 9.5 Handle "Quit" menu item: properly dispose WebSocket, close app
- [ ] 9.6 Initialize `SystemTrayService` only on desktop platforms (Windows/macOS) in app startup

## 10. Flutter: Notification Deep Link

- [ ] 10.1 Update `PushNotificationService.initialize()` `onNotificationTap` callback: ensure it navigates to `/chat/:convId` via GoRouter
- [ ] 10.2 Wire `LocalNotificationService` tap callback to same navigation logic
- [ ] 10.3 Handle terminated state: `getInitialMessage()` + `getNotificationAppLaunchDetails()` → navigate on app cold start
- [ ] 10.4 Update `firebase-messaging-sw.js`: add `notificationclick` handler that opens/focuses the app window and navigates to conversation

## 11. Flutter: Badge Count

- [ ] 11.1 Parse `badge_count` from FCM data payload in foreground handler
- [ ] 11.2 On iOS/macOS: badge is auto-set by APNs `badge` field — no client action needed
- [ ] 11.3 On Android: use `flutter_local_notifications` or `flutter_app_badger` to set app icon badge from `badge_count` data field
- [ ] 11.4 Clear badge on app open: when app comes to foreground and user has no unread conversations, set badge to 0
- [ ] 11.5 Update system tray tooltip with unread count on desktop

## 12. Flutter: Notification Center Screen

- [ ] 12.1 Create `notificationHistoryProvider` AsyncNotifier in `apps/mobile/lib/features/notifications/providers/notification_providers.dart`: fetch from `GET /notifications`, paginated, with type filter
- [ ] 12.2 Create `NotificationCenterScreen` at `apps/mobile/lib/features/notifications/screens/notification_center_screen.dart`: AppBar with "Thông báo" title, filter chips (All/Chat/HR/Task), scrollable list grouped by date
- [ ] 12.3 Each notification item: icon (by type), title, body, relative timestamp, read/unread indicator (bold for unread). Tap → mark read + navigate
- [ ] 12.4 Add "Mark all read" action in AppBar
- [ ] 12.5 Add notification bell icon with unread badge to main app bar (chat list screen). Tap → push NotificationCenterScreen
- [ ] 12.6 Add route for NotificationCenterScreen in GoRouter

## 13. Flutter: Notification Preferences Screen

- [ ] 13.1 Create `notificationPreferencesProvider` AsyncNotifier: fetch from `GET /notifications/preferences`, update via `PATCH /notifications/preferences`
- [ ] 13.2 Create `NotificationPreferencesScreen` at `apps/mobile/lib/features/notifications/screens/notification_preferences_screen.dart`: SwitchListTile for each toggle (Chat, Call, HR, Task), quiet hours section with time pickers
- [ ] 13.3 Add navigation to preferences screen from settings or notification center
- [ ] 13.4 Add route in GoRouter

## 14. Verification

- [ ] 14.1 Run `npm run lint` in `apps/api` — fix any issues
- [ ] 14.2 Run `npm run build` in `apps/api` — fix TypeScript errors
- [ ] 14.3 Run `npm test` in `apps/api` — fix broken tests
- [ ] 14.4 Run `flutter analyze` in `apps/mobile` — fix any issues
- [ ] 14.5 Test on Android: send message → verify foreground banner, background push, tap navigation, badge
- [ ] 14.6 Test on iOS: same as Android + verify APNs badge
- [ ] 14.7 Test on Web: verify service worker notification + click handling
- [ ] 14.8 Test on Windows: verify system tray, WS notification toast, tap → focus + navigate
- [ ] 14.9 Test on macOS: verify system tray, notification center alert, badge

