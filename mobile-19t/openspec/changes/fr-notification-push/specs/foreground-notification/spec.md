## ADDED Requirements

### Requirement: Display local notification when app is in foreground
The system SHALL display a local notification banner via `flutter_local_notifications` when a push message arrives while the app is in the foreground on Android, iOS, macOS, and Windows. Web SHALL use the existing service worker notification.

#### Scenario: Foreground notification on Android
- **WHEN** a FCM message arrives while the Flutter app is in the foreground on Android
- **THEN** a local notification is displayed with the sender name as title and message preview as body, using the app's notification channel

#### Scenario: Foreground notification on iOS
- **WHEN** a FCM message arrives while the Flutter app is in the foreground on iOS
- **THEN** a local notification banner is displayed with sender name and message preview

### Requirement: Suppress notification for active conversation
The system SHALL NOT display a foreground notification if the user is currently viewing the conversation that the message belongs to. The system SHALL check the currently active conversation ID before showing the notification.

#### Scenario: User viewing target conversation
- **WHEN** a message arrives for conversation X and the user is currently on ChatScreen for conversation X
- **THEN** no local notification is displayed

#### Scenario: User viewing different conversation
- **WHEN** a message arrives for conversation X and the user is on ChatScreen for conversation Y
- **THEN** a local notification is displayed for conversation X

### Requirement: Android notification channel setup
The system SHALL create a notification channel "chat_messages" with high importance on Android during app initialization. All chat message notifications SHALL use this channel.

#### Scenario: Channel created on init
- **WHEN** the app starts on Android
- **THEN** a "Chat Messages" notification channel with high importance and default sound is created

### Requirement: Initialize flutter_local_notifications on all platforms
The system SHALL initialize `flutter_local_notifications` with platform-specific settings during app startup: Android (channel, icon), iOS (request permissions), macOS (request permissions), Windows (app name).

#### Scenario: Plugin initialized
- **WHEN** the app starts on any supported platform
- **THEN** flutter_local_notifications is initialized with correct platform settings

