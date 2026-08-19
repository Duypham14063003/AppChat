## ADDED Requirements

### Requirement: Web clients show browser notifications for incoming chat messages
The system SHALL display a browser notification for an incoming chat message on web when the user is authenticated, the browser notification permission is granted, and the message is eligible for foreground notification display.

#### Scenario: Browser notification appears for an incoming direct or group chat message
- **WHEN** an eligible incoming chat message reaches the web client while the app is open
- **THEN** the system MUST display a browser notification using the message sender and chat preview content

#### Scenario: Web notification display does not change native foreground notifications
- **WHEN** the same incoming chat event is processed on Android, iOS, or macOS
- **THEN** the system MUST continue using the existing native local foreground notification flow

### Requirement: Web notification permission is handled explicitly
The system SHALL evaluate browser notification permission before attempting to display a web chat notification and SHALL avoid silent notification attempts when permission is unavailable.

#### Scenario: Granted permission enables browser notification delivery
- **WHEN** browser notification permission is granted for the authenticated web session
- **THEN** the system MUST allow eligible incoming chat messages to trigger browser notifications

#### Scenario: Denied or unavailable permission suppresses notification display safely
- **WHEN** browser notification permission is denied, dismissed, or unsupported
- **THEN** the system MUST skip browser notification display without interrupting chat message delivery or app navigation

### Requirement: Web chat notifications are de-duplicated across foreground sources
The system SHALL avoid showing duplicate browser notifications for the same incoming chat message when multiple foreground message sources deliver the same event.

#### Scenario: The same message arrives through WebSocket and FCM foreground streams
- **WHEN** a single incoming chat message is observed from more than one foreground source on web
- **THEN** the system MUST display at most one browser notification for that message
