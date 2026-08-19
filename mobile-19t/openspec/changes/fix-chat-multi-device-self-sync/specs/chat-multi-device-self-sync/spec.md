## ADDED Requirements

### Requirement: Sender secondary devices SHALL receive realtime message delivery
When a user has multiple active chat sessions, sending a message from one session SHALL deliver the normal realtime `new_message` event to the sender's other active sessions for the same account.

#### Scenario: Sender posts from phone while desktop is also connected
- **WHEN** the same authenticated user is connected to the same conversation from both phone and desktop
- **AND** the user sends a message from the phone session
- **THEN** the desktop session SHALL receive the realtime `new_message` event for that message
- **AND** the desktop session SHALL persist and render the message without requiring manual refresh or room reopen

#### Scenario: Sender posts from desktop while phone is also connected
- **WHEN** the same authenticated user is connected to the same conversation from both desktop and phone
- **AND** the user sends a message from the desktop session
- **THEN** the phone session SHALL receive the realtime `new_message` event for that message
- **AND** the phone session SHALL persist and render the message without requiring manual refresh or room reopen

### Requirement: Originating socket SHALL remain protected from redundant self-echo
The websocket session that initiated a message send SHALL NOT receive a redundant realtime `new_message` event for the same message if that session already relies on optimistic local insert and acknowledgement flow.

#### Scenario: Origin device sends a message successfully
- **WHEN** a connected chat session sends a message successfully over websocket
- **THEN** the originating socket SHALL receive acknowledgement and status updates through the existing send flow
- **AND** the originating socket SHALL NOT receive an extra `new_message` event for the same message from conversation fan-out

### Requirement: Other conversation members SHALL keep existing realtime behavior
Delivering realtime updates to the sender's secondary devices SHALL NOT suppress or delay `new_message` delivery to other members of the conversation.

#### Scenario: Conversation contains sender, sender secondary device, and another member
- **WHEN** a user sends a message while they also have another active device connected
- **THEN** the sender's secondary device SHALL receive the realtime message
- **AND** every other connected conversation member SHALL continue receiving the same realtime message event

### Requirement: Multi-device sender sync SHALL use the current websocket transport contract
The system SHALL satisfy sender multi-device synchronization without requiring a new client message schema, a device ID field, or a separate polling fallback for healthy realtime sessions.

#### Scenario: Existing client send payload is used
- **WHEN** a client sends a message using the current websocket message payload shape
- **THEN** the backend SHALL determine duplicate-suppression scope from existing connection state
- **AND** the client SHALL NOT be required to send a new device identifier to enable same-account multi-device realtime sync
