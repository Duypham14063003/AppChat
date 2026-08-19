## ADDED Requirements

### Requirement: Scroll-to-bottom FAB visibility follows chat position
The system SHALL show the chat scroll-to-bottom FAB when the user has scrolled sufficiently away from the latest messages in the conversation, even if no new messages arrive and no pagination request has completed.

#### Scenario: User scrolls upward away from latest messages
- **WHEN** the user scrolls up through older messages past the configured bottom-distance threshold
- **THEN** the chat screen shows the scroll-to-bottom FAB

#### Scenario: Pagination has not started yet
- **WHEN** the user has moved away from the bottom but the conversation has not yet triggered history loading
- **THEN** the scroll-to-bottom FAB is still visible

### Requirement: Scroll-to-bottom FAB stays hidden near the bottom
The system SHALL keep the chat scroll-to-bottom FAB hidden while the user remains at or near the latest messages.

#### Scenario: Chat opens on latest messages
- **WHEN** the user opens a conversation and the newest messages are in view
- **THEN** the scroll-to-bottom FAB is hidden

#### Scenario: User returns to the bottom
- **WHEN** the user taps the FAB or manually scrolls back to the latest messages
- **THEN** the FAB becomes hidden again

### Requirement: New-message handling does not gate the manual return affordance
The system SHALL determine scroll-to-bottom FAB visibility independently from message-count increases while preserving automatic scrolling for incoming messages when the user is already at the bottom.

#### Scenario: New message arrives while user is at bottom
- **WHEN** a new message is appended and the user is already at the latest messages
- **THEN** the chat timeline stays anchored to the bottom without showing the FAB

#### Scenario: User is away from bottom before any new data event
- **WHEN** the user scrolls away from the bottom and no new messages or pagination responses have changed the message count
- **THEN** the FAB visibility still reflects the user's current scroll position
