## ADDED Requirements

### Requirement: Firebase Admin SDK initialization
The NestJS backend SHALL initialize Firebase Admin SDK on startup using `FIREBASE_PROJECT_ID` and `FIREBASE_SERVICE_ACCOUNT_KEY` environment variables. If these variables are empty, the system SHALL log a warning and disable push notification functionality without affecting other features.

#### Scenario: Firebase initialized with valid credentials
- **WHEN** NestJS starts with valid FIREBASE_PROJECT_ID and FIREBASE_SERVICE_ACCOUNT_KEY
- **THEN** Firebase Admin SDK is initialized and push notifications are enabled

#### Scenario: Firebase skipped when not configured
- **WHEN** NestJS starts with empty FIREBASE_PROJECT_ID
- **THEN** a warning is logged "Firebase not configured — push notifications disabled" and the app starts normally

### Requirement: FCM token registration
The system SHALL accept FCM tokens from Flutter clients and store them in `user_sessions.fcm_token`. When a user logs in or the FCM token refreshes, the client SHALL send the token to the server via `PATCH /auth/sessions/fcm-token { fcmToken }`.

#### Scenario: FCM token stored on login
- **WHEN** Flutter client receives FCM token after login
- **THEN** client sends token to server, server updates `user_sessions.fcm_token` for the current session

#### Scenario: FCM token refreshed
- **WHEN** Firebase SDK issues a new token (token rotation)
- **THEN** client sends updated token to server

### Requirement: Push notification for offline message delivery
When a message recipient has no active WebSocket connection, the system SHALL enqueue a BullMQ job (`chat:push-notification`) to send an FCM push notification. The job SHALL query all active sessions for the recipient and send to each device's FCM token.

#### Scenario: Offline user receives push
- **WHEN** user B is offline and user A sends a message
- **THEN** BullMQ job sends FCM notification to all of B's registered device tokens

#### Scenario: Push notification content
- **WHEN** FCM push is sent
- **THEN** notification contains: title = sender name, body = message preview (truncated 100 chars), data = `{ conv_id, message_id }` for deep linking

#### Scenario: Invalid FCM token handling
- **WHEN** FCM returns "registration-token-not-registered" error
- **THEN** the system removes the invalid fcm_token from user_sessions

### Requirement: Flutter FCM setup and handling
The Flutter app SHALL initialize Firebase Messaging, request notification permissions, and handle: foreground messages (show local notification), background messages (system tray), and notification taps (navigate to conversation).

#### Scenario: Notification permission requested on first launch
- **WHEN** app launches for the first time after login
- **THEN** notification permission dialog is shown (iOS) or permission is auto-granted (Android)

#### Scenario: Foreground notification
- **WHEN** a push notification arrives while app is in foreground and user is NOT in the target conversation
- **THEN** a local notification banner is shown at the top of the screen

#### Scenario: Notification tap navigates to conversation
- **WHEN** user taps a push notification (from system tray or banner)
- **THEN** app navigates to `/chat/{conv_id}` from the notification data

### Requirement: Push notification respects mute setting
The system SHALL check `conversation_members.is_muted` before sending push notifications. If the conversation is muted for the recipient, no push notification SHALL be sent.

#### Scenario: Muted conversation skips push
- **WHEN** user B has muted conversation X and receives a message in X while offline
- **THEN** no FCM push notification is sent to user B for this message

