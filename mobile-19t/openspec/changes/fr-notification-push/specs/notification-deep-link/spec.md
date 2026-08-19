## ADDED Requirements

### Requirement: Notification tap navigates to conversation
The system SHALL navigate to the target conversation when the user taps a chat notification across all platforms and app states (foreground, background, terminated). The conversation ID SHALL be extracted from the notification payload's `conv_id` data field.

#### Scenario: Tap notification when app is in background (mobile)
- **WHEN** the user taps a push notification while the app is backgrounded on Android/iOS
- **THEN** the app comes to foreground and navigates to the conversation specified by conv_id

#### Scenario: Tap notification when app is terminated (mobile)
- **WHEN** the user taps a push notification that launches the app from terminated state
- **THEN** the app starts, authenticates, and navigates to the target conversation

#### Scenario: Tap notification on desktop
- **WHEN** the user clicks a desktop notification (Windows toast / macOS notification center)
- **THEN** the app window is restored/focused and navigates to the target conversation

#### Scenario: Tap notification on web
- **WHEN** the user clicks a web push notification
- **THEN** the browser tab is focused and navigates to the target conversation

### Requirement: Deep link payload in all notification types
All push notifications and local notifications SHALL include `conv_id` in the data/payload field. Desktop notifications SHALL encode `conv_id` in the notification payload for retrieval on tap.

#### Scenario: FCM payload includes conv_id
- **WHEN** the server sends a push notification
- **THEN** the data field includes `conv_id` and `message_id`

#### Scenario: Local notification payload includes conv_id
- **WHEN** a local notification is created (foreground or desktop)
- **THEN** the payload includes `conv_id` for navigation on tap

