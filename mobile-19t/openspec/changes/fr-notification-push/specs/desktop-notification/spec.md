## ADDED Requirements

### Requirement: System tray integration on desktop
The system SHALL integrate `system_tray` package on Windows and macOS to show a tray icon with context menu (Show App, Quit). The close button SHALL minimize to tray instead of quitting the app. The tray icon SHALL show an unread count badge or indicator.

#### Scenario: Close minimizes to tray on Windows
- **WHEN** the user clicks the close button on Windows
- **THEN** the app minimizes to the system tray and continues running

#### Scenario: Close minimizes to tray on macOS
- **WHEN** the user clicks the close button on macOS
- **THEN** the app minimizes to the menu bar tray and continues running

#### Scenario: Tray context menu
- **WHEN** the user right-clicks the tray icon
- **THEN** a context menu appears with "Show App" and "Quit" options

### Requirement: WebSocket-based desktop notification
The system SHALL listen for `new_message` WebSocket events on desktop platforms. When a message arrives and the app window is not focused or is minimized, the system SHALL display a system notification via `flutter_local_notifications`.

#### Scenario: Notification when app minimized on Windows
- **WHEN** the app is minimized to tray on Windows and a new_message WS event arrives
- **THEN** a Windows toast notification is displayed with sender name and message preview

#### Scenario: Notification when app minimized on macOS
- **WHEN** the app is minimized to tray on macOS and a new_message WS event arrives
- **THEN** a macOS notification center alert is displayed with sender name and message preview

#### Scenario: No notification when app is focused
- **WHEN** the app window is focused and a new_message WS event arrives
- **THEN** the foreground notification handler decides (suppress if viewing target conversation)

### Requirement: Desktop notification tap focuses app
The system SHALL focus the app window and navigate to the target conversation when the user clicks a desktop notification.

#### Scenario: Click notification on Windows
- **WHEN** the user clicks a Windows toast notification for conversation X
- **THEN** the app window is restored/focused and navigates to conversation X

#### Scenario: Click notification on macOS
- **WHEN** the user clicks a macOS notification for conversation X
- **THEN** the app window is restored/focused and navigates to conversation X

