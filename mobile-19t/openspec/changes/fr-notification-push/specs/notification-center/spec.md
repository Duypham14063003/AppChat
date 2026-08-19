## ADDED Requirements

### Requirement: Notifications database table
The system SHALL store notification history in a `notifications` table with columns: id (uuid PK), user_id (uuid FK→users), type (varchar — chat_message, mention, call, hr, task, system), title (varchar), body (text), data (jsonb — conv_id, message_id, etc.), is_read (boolean DEFAULT false), created_at (timestamptz).

#### Scenario: Notification persisted after push
- **WHEN** a push notification is sent to a user
- **THEN** a corresponding row is inserted into the notifications table

### Requirement: List notification history via REST API
The system SHALL expose `GET /notifications` returning paginated notification history for the authenticated user, ordered by created_at DESC. Supports cursor-based pagination and optional type filter.

#### Scenario: Fetch notification history
- **WHEN** a user sends `GET /notifications?limit=20`
- **THEN** the system returns the 20 most recent notifications for that user

#### Scenario: Filter by type
- **WHEN** a user sends `GET /notifications?type=chat_message`
- **THEN** only chat_message notifications are returned

### Requirement: Mark notification as read
The system SHALL expose `PATCH /notifications/:id/read` to mark a single notification as read, and `PATCH /notifications/read-all` to mark all notifications as read for the authenticated user.

#### Scenario: Mark single as read
- **WHEN** a user sends `PATCH /notifications/abc-123/read`
- **THEN** the notification's is_read is set to true

#### Scenario: Mark all as read
- **WHEN** a user sends `PATCH /notifications/read-all`
- **THEN** all unread notifications for the user are marked as read

### Requirement: Notification Center Flutter screen
The system SHALL provide a NotificationCenterScreen accessible from the main navigation. The screen SHALL display a scrollable list of notifications grouped by date, with unread indicators. Each item shows icon (by type), title, body preview, and timestamp. Tapping an item navigates to the relevant screen (conversation for chat, etc.) and marks it as read.

#### Scenario: Open notification center
- **WHEN** the user taps the notification bell icon in the app bar
- **THEN** the NotificationCenterScreen opens showing notification history

#### Scenario: Tap notification item
- **WHEN** the user taps a chat_message notification
- **THEN** the app navigates to the target conversation and the notification is marked as read

### Requirement: Unread notification count badge
The system SHALL display an unread notification count badge on the notification bell icon in the app bar. The count SHALL update in real-time via WebSocket events.

#### Scenario: Badge shows unread count
- **WHEN** the user has 5 unread notifications
- **THEN** the bell icon shows a "5" badge

