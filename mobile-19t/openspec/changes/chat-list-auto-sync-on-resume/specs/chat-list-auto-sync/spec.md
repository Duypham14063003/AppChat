## ADDED Requirements

### Requirement: Chat list refreshes automatically when the app resumes
The system SHALL refresh the chat conversation list when the mobile app returns to the foreground so newly arrived messages appear in the list without manual pull-to-refresh.

#### Scenario: Resume after receiving a new message
- **WHEN** the user backgrounds the app, receives a new chat message, and then returns to the app
- **THEN** the chat list refreshes automatically and shows the latest conversation preview, timestamp, and ordering

### Requirement: Chat list remains current after inbound chat activity
The system SHALL keep the chat list aligned with newly arrived chat activity so conversation previews do not require opening the conversation to reveal new server state.

#### Scenario: Inbound message updates list state
- **WHEN** a new chat message arrives for a conversation
- **THEN** the chat list reflects that newer conversation state without requiring the user to manually reload the list

#### Scenario: Preview-only local data is insufficient
- **WHEN** local websocket preview updates are not enough to represent the latest server state for the conversation list
- **THEN** the client performs reconciliation through chat-list refresh behavior instead of leaving the list stale

### Requirement: Automatic chat-list sync does not require manual reload to reveal server-known messages
The system SHALL not depend on manual list refresh for users to see messages that are already available on the server.

#### Scenario: Opening conversation is no longer the first time new data appears
- **WHEN** the server already contains a new message for a conversation
- **THEN** the chat list shows that newer message state before the user needs to open the conversation detail screen
