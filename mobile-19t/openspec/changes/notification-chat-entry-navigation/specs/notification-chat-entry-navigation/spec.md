## ADDED Requirements

### Requirement: Chat notification entry preserves an exit path on mobile
The system SHALL open a conversation from a chat notification in a way that preserves a back path to the previously visible app shell on mobile.

#### Scenario: Tap chat notification while app is in background
- **WHEN** the user taps a chat notification while the mobile app is in the background
- **THEN** the app opens the target conversation and shows a back affordance that returns the user to the prior app shell context

#### Scenario: Tap chat notification from terminated launch
- **WHEN** the user launches the mobile app by tapping a chat notification from a terminated state
- **THEN** the app opens the target conversation as a detail destination with a back path instead of replacing navigation with a backless root chat screen

### Requirement: Non-chat notification destinations keep shell-style navigation
The system SHALL keep existing shell-style navigation behavior for notification destinations that are not chat conversation detail routes.

#### Scenario: Tap HR reminder notification
- **WHEN** the user taps an HR reminder notification
- **THEN** the app navigates to the HR destination without applying chat-detail stacking behavior

### Requirement: Notification chat entry remains payload-driven
The system SHALL continue deriving the chat destination from the notification payload `conv_id` field when opening a conversation from a notification.

#### Scenario: Chat payload includes conversation id
- **WHEN** a notification payload contains `conv_id`
- **THEN** the app resolves the target conversation route from that `conv_id` before applying chat-entry navigation behavior
