## Context

The 19T app has basic push notification infrastructure: `FirebaseService` (Admin SDK, `sendPush()`), `PushNotificationProcessor` (BullMQ worker, checks mute, iterates sessions), `NotificationJobService` (enqueue from ChatService), `PushNotificationService` (Flutter, FCM token registration, VAPID for web). The `user_sessions` table stores `fcm_token` per device. FCM is initialized in all Flutter entry points. A web service worker (`firebase-messaging-sw.js`) handles background web push.

Current gaps: foreground messages just `debugPrint`, no `flutter_local_notifications`, no desktop system tray, no background handler, no notification center, no preferences, no badge sync, no grouping.

Target platforms: Android, iOS, Web (Chrome), Windows desktop, macOS desktop. Company <50 employees.

## Goals / Non-Goals

**Goals:**
- Reliable notification delivery across Android, iOS, Web, Windows, macOS
- Foreground notification banner (suppress if user is viewing target conversation)
- Desktop: system tray + WS-based notification (Slack/Discord pattern)
- Notification center with history
- User preferences (quiet hours, per-type toggles)
- Badge count sync (iOS/macOS/Android)
- Notification grouping for multiple messages from same conversation
- Default system sounds

**Non-Goals:**
- Custom notification sounds (use OS defaults)
- VoIP push for calls (future change)
- Rich notification actions (reply from notification — future)
- Linux desktop support
- Notification for HR/Task/Reminder events (only chat messages for now — other event types added when those modules are built)
- End-to-end encrypted notification content

## Decisions

### D1: Desktop notification — System tray + WebSocket (Slack/Discord pattern)

**Decision**: Desktop apps minimize to system tray on close. WebSocket `new_message` events trigger `flutter_local_notifications` toast when app is not focused on target conversation.

**Why**: Industry standard — Slack, Discord, Telegram, Teams all use this pattern. No major chat app uses WNS/APNs as primary desktop push channel. FCM doesn't support Windows. Users expect chat apps to live in the tray.

**Alternative**: WNS for Windows + APNs for macOS. Rejected — complex setup (MSIX packaging, Store registration for WNS; Apple Developer certs for APNs), and still doesn't work when app is fully quit.

### D2: `flutter_local_notifications` as unified display layer

**Decision**: Use `flutter_local_notifications` on all platforms (Android, iOS, macOS, Windows) for foreground notification display. Web uses the existing service worker.

**Why**: Single API for all platforms. Mature package (v21+), supports Android channels, iOS categories, macOS UNUserNotificationCenter, Windows toast. Compatible with `firebase_messaging` since v6.0.13.

### D3: `system_tray` package for desktop tray

**Decision**: Use `system_tray` package for Windows/macOS system tray integration.

**Why**: Supports both Windows and macOS. Allows custom tray icon, context menu (Show/Quit), and tooltip with unread count. Override close button to minimize to tray.

### D4: Notification preferences — database table vs user metadata

**Decision**: Dedicated `notification_preferences` table with one row per user.

**Why**: Structured columns for each preference (quiet_hours_start, quiet_hours_end, chat_enabled, call_enabled, etc.) are easier to query in the push processor than parsing JSONB. Single row per user, simple upsert.

### D5: Notification center — separate `notifications` table

**Decision**: New `notifications` table storing notification history (id, user_id, type, title, body, data jsonb, is_read, created_at). Populated by PushNotificationProcessor after sending.

**Why**: Decoupled from messages table. Supports future non-chat notifications (HR, tasks). Lightweight — only stores notification metadata, not full message content.

### D6: Notification grouping — server-side with Redis counter

**Decision**: Track recent notification count per (user, conversation) in Redis with 30s TTL. If count > 1 within window, send grouped notification "{sender} sent N new messages" instead of individual ones.

**Why**: Simple, no schema changes. Redis TTL auto-expires. Prevents notification spam in active group chats. 30s window balances responsiveness vs grouping.

### D7: Badge count — server-calculated, sent in FCM payload

**Decision**: Calculate total unread count server-side (sum of unread across all conversations for user), include in FCM payload as `badge` (iOS/macOS APNs) and `data.badge_count` (Android). Flutter client updates app icon badge on receipt.

**Why**: Server is source of truth for unread counts. Avoids client-side calculation drift. iOS requires badge count in APNs payload. Android uses `flutter_local_notifications` to set badge.

## Risks / Trade-offs

- **[Risk] Windows notification when app quit** → No notification. Same as Slack/Discord. Mitigated by system tray (close = minimize, not quit). Document this behavior for users.

- **[Risk] `flutter_local_notifications` + `firebase_messaging` conflict on macOS** → Resolved since firebase_messaging 6.0.13. Both can coexist. Test during implementation.

- **[Risk] `system_tray` package maturity** → Package is community-maintained. If issues arise, fallback to `tray_manager` or `bitsdojo_window` for close-to-tray behavior.

- **[Risk] Notification grouping race condition** → Two BullMQ workers could process messages for same conversation simultaneously. Redis INCR is atomic, so counter is safe. Worst case: slightly inaccurate count in grouped notification (acceptable).

- **[Trade-off] No notification when desktop app fully quit** → Industry standard limitation. Mobile devices still receive FCM push. Desktop users are expected to keep app in tray.

- **[Trade-off] Chat-only notifications for now** → HR/Task/Reminder notifications deferred until those modules are implemented. Notification center and preferences are designed to support future event types.

