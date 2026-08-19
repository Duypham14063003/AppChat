## ADDED Requirements

### Requirement: Top-level background message handler
The system SHALL register a top-level `@pragma('vm:entry-point')` function as the Firebase background message handler via `FirebaseMessaging.onBackgroundMessage()`. This handler SHALL process data-only FCM messages when the app is terminated or backgrounded on Android and iOS.

#### Scenario: Background message on Android
- **WHEN** a data-only FCM message arrives while the app is terminated on Android
- **THEN** the background handler processes it and displays a local notification

#### Scenario: Background message on iOS
- **WHEN** a FCM message arrives while the app is backgrounded on iOS
- **THEN** the background handler processes it (iOS shows the notification automatically via APNs)

### Requirement: Background handler registered in all entry points
The system SHALL call `FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler)` in all main entry points (main.dart, main_dev.dart, main_staging.dart, main_prod.dart) before `runApp()`.

#### Scenario: Handler registered
- **WHEN** the app starts from any entry point
- **THEN** the background message handler is registered with FirebaseMessaging

