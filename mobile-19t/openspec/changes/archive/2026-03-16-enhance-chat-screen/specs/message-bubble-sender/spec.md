## ADDED Requirements

### Requirement: Incoming messages show sender avatar
The MessageBubble widget SHALL display a small CircleAvatar (radius 14) to the left of the bubble for incoming messages (not the current user's). The avatar SHALL show the sender's profile image or initials fallback. The avatar SHALL only appear for messages where `isMine` is false.

#### Scenario: Incoming message with sender avatar
- **WHEN** a message from another user is displayed
- **THEN** a small CircleAvatar appears to the left of the message bubble showing the sender's avatar or initials

#### Scenario: Own message has no avatar
- **WHEN** a message from the current user is displayed
- **THEN** no avatar is shown (right-aligned bubble only, same as current behavior)

### Requirement: Incoming messages show sender name
The MessageBubble widget SHALL display the sender's name above the message content for incoming messages in DIRECT conversations. The name SHALL be displayed in a smaller font (12px) with secondary text color.

#### Scenario: Incoming message shows sender name
- **WHEN** a message from another user is displayed
- **THEN** the sender's name appears above the message content inside the bubble

#### Scenario: Own message has no sender name
- **WHEN** a message from the current user is displayed
- **THEN** no sender name is shown (same as current behavior)

### Requirement: MessageBubble accepts sender info parameters
The MessageBubble widget SHALL accept optional `senderName` (String?) and `senderAvatar` (String?) parameters in addition to the existing `message` and `isMine` parameters. These SHALL be used to display sender identification for incoming messages.

#### Scenario: MessageBubble constructed with sender info
- **WHEN** ChatScreen builds a MessageBubble for an incoming message
- **THEN** it passes `senderName` and `senderAvatar` from the conversation's other member info

