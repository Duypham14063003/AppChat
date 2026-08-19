## ADDED Requirements

### Requirement: Foreground chat notifications are suppressed for the active conversation
The system SHALL suppress a foreground chat notification when the app is open and the user is already viewing the same conversation identified by the incoming chat notification payload.

#### Scenario: User is already inside the matching chat
- **WHEN** a new chat message for conversation `conv-1` arrives while the app is open and the current route is `/chat/conv-1`
- **THEN** the app does not show a foreground notification for that message

#### Scenario: User is inside a different chat
- **WHEN** a new chat message for conversation `conv-2` arrives while the app is open and the current route is `/chat/conv-1`
- **THEN** the app shows a foreground notification for the new message

### Requirement: Foreground chat notifications are shown outside the matching chat route
The system SHALL show a foreground local notification for a new chat message when the app is open and the user is not currently on the matching conversation route.

#### Scenario: User is on a non-chat screen
- **WHEN** a new chat message arrives while the app is open and the current route is not a chat conversation route
- **THEN** the app shows a foreground notification for that chat message

#### Scenario: Chat route has no matching conversation id
- **WHEN** a new chat message arrives while the app is open and the app cannot resolve the current route as the same target conversation
- **THEN** the app treats the message as notification-worthy and shows a foreground notification

### Requirement: Foreground suppression does not break other notification behaviors
The system SHALL keep existing background push handling, notification tap routing, and non-chat notification presentation intact while applying chat-only foreground suppression.

#### Scenario: Non-chat foreground notification arrives
- **WHEN** a foreground notification arrives with a non-chat payload
- **THEN** the app continues handling that notification using the existing foreground notification behavior

#### Scenario: Chat notification is opened from background
- **WHEN** the user taps a chat notification while the app is backgrounded or terminated
- **THEN** the app continues using the existing notification tap navigation flow for that chat destination
