## ADDED Requirements

### Requirement: Same-day chat message timestamps stay compact
The system SHALL show a compact time-only timestamp for chat messages sent on the current day.

#### Scenario: Message sent today
- **WHEN** a chat bubble renders a message whose send date is the current local day
- **THEN** the timestamp shown in the bubble uses a time-only format

### Requirement: Older chat message timestamps include the send date
The system SHALL include date information in the bubble timestamp for messages that were not sent on the current local day.

#### Scenario: Message sent on a previous day in the current year
- **WHEN** a chat bubble renders a message from an earlier local date in the same calendar year
- **THEN** the timestamp includes both day/month and time

#### Scenario: Message sent in a previous calendar year
- **WHEN** a chat bubble renders a message from a different calendar year
- **THEN** the timestamp includes day, month, year, and time

### Requirement: Timestamp formatting stays consistent across bubble content types
The system SHALL use the same contextual timestamp formatting rule for text, media, voice, and other chat bubble variants that render a message timestamp row.

#### Scenario: Media bubble timestamp
- **WHEN** an image, album, video, or voice message bubble renders its timestamp
- **THEN** it follows the same same-day versus older-message formatting rules as a text message bubble
