## ADDED Requirements

### Requirement: Server includes badge count in FCM payload
The system SHALL calculate the total unread message count across all conversations for the recipient user and include it in the FCM payload as `apns.payload.aps.badge` (iOS/macOS) and `data.badge_count` (Android). The count SHALL be calculated as the sum of unread messages per conversation where the user is a member and the conversation is not muted.

#### Scenario: Badge count in iOS push
- **WHEN** a push notification is sent to an iOS user with 7 total unread messages
- **THEN** the APNs payload includes `badge: 7` and the app icon shows badge "7"

#### Scenario: Badge count in Android push
- **WHEN** a push notification is sent to an Android user with 3 total unread messages
- **THEN** the FCM data payload includes `badge_count: "3"`

### Requirement: Flutter client updates app icon badge on notification receipt
The system SHALL update the app icon badge count when a push notification or WebSocket event is received. On iOS and macOS, the badge SHALL be set via the APNs badge field. On Android, the badge SHALL be set via `flutter_local_notifications` or `flutter_app_badger`.

#### Scenario: Badge updated on new message
- **WHEN** a new message notification arrives
- **THEN** the app icon badge count is updated to reflect total unread messages

### Requirement: Badge cleared when all messages read
The system SHALL clear the app icon badge (set to 0) when the user has read all messages. The client SHALL send a badge reset when the user opens the app and has no unread conversations.

#### Scenario: Badge cleared on read all
- **WHEN** the user reads all unread messages
- **THEN** the app icon badge is set to 0

### Requirement: Badge count on desktop tray icon
On Windows and macOS desktop, the system SHALL display the unread count as a badge overlay on the system tray icon. The count SHALL update in real-time as WebSocket events arrive.

#### Scenario: Tray icon badge on Windows
- **WHEN** the user has 5 unread messages and the app is in the system tray
- **THEN** the tray icon tooltip shows "19T - 5 unread messages"

