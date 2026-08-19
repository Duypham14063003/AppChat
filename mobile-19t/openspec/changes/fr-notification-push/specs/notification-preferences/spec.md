## ADDED Requirements

### Requirement: Notification preferences database table
The system SHALL store per-user notification preferences in a `notification_preferences` table: user_id (uuid PK FK→users), chat_enabled (boolean DEFAULT true), call_enabled (boolean DEFAULT true), hr_enabled (boolean DEFAULT true), task_enabled (boolean DEFAULT true), quiet_hours_enabled (boolean DEFAULT false), quiet_hours_start (time DEFAULT '22:00'), quiet_hours_end (time DEFAULT '07:00'), created_at (timestamptz), updated_at (timestamptz).

#### Scenario: Default preferences for new user
- **WHEN** a user has no row in notification_preferences
- **THEN** the system treats all notifications as enabled with quiet hours disabled

### Requirement: Get notification preferences via REST API
The system SHALL expose `GET /notifications/preferences` returning the authenticated user's notification preferences. If no preferences exist, return defaults.

#### Scenario: Fetch preferences
- **WHEN** a user sends `GET /notifications/preferences`
- **THEN** the system returns the user's preferences or defaults

### Requirement: Update notification preferences via REST API
The system SHALL expose `PATCH /notifications/preferences` accepting partial updates to notification preferences. The system SHALL upsert (create if not exists, update if exists).

#### Scenario: Enable quiet hours
- **WHEN** a user sends `PATCH /notifications/preferences { quiet_hours_enabled: true, quiet_hours_start: "23:00", quiet_hours_end: "07:00" }`
- **THEN** the preferences are updated and future notifications respect quiet hours

### Requirement: Push processor checks preferences before sending
The `PushNotificationProcessor` SHALL check the recipient's notification preferences before sending a push. If the notification type is disabled, the push SHALL be skipped. If quiet hours are active (current server time is within quiet_hours_start..quiet_hours_end), the push SHALL be skipped unless it's a mention notification.

#### Scenario: Chat notifications disabled
- **WHEN** a user has chat_enabled=false and a chat message push is enqueued
- **THEN** the push is skipped

#### Scenario: Quiet hours active
- **WHEN** it is 23:30 and the user has quiet hours 23:00-07:00 enabled
- **THEN** regular chat pushes are skipped but mention notifications are still sent

### Requirement: Notification Preferences Flutter screen
The system SHALL provide a NotificationPreferencesScreen accessible from Settings. The screen SHALL show toggles for each notification type (Chat, Call, HR, Task) and quiet hours configuration (enable/disable, start time, end time).

#### Scenario: Toggle chat notifications off
- **WHEN** the user disables the Chat toggle
- **THEN** the app sends PATCH to update chat_enabled=false and the user stops receiving chat push notifications

