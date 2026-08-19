## ADDED Requirements

### Requirement: Incoming direct-message bubbles align without avatar gutter
The Flutter chat UI SHALL render incoming direct-message bubbles without reserving avatar or sender-name gutter space when those UI elements are disabled by the conversation layout.

#### Scenario: Direct chat incoming message
- **WHEN** the chat screen renders an incoming message in a direct conversation
- **THEN** the bubble SHALL align to the normal left content edge without any empty avatar spacer

#### Scenario: Direct chat forwarded message
- **WHEN** the chat screen renders an incoming forwarded message in a direct conversation
- **THEN** the forwarded header and bubble body SHALL share the same left edge without extra avatar gutter spacing

#### Scenario: Direct chat quoted reply
- **WHEN** the chat screen renders an incoming reply bubble in a direct conversation
- **THEN** the quoted-reply container and message body SHALL align to the same corrected left edge as the bubble

### Requirement: Incoming group-message bubbles preserve sender chrome spacing
The Flutter chat UI SHALL continue to reserve incoming gutter space for avatars and sender-name chrome in group conversations when that chrome is enabled by the conversation layout.

#### Scenario: Group chat incoming message with avatar lane
- **WHEN** the chat screen renders an incoming message in a group conversation with avatar display enabled
- **THEN** the bubble SHALL continue to align with the group-chat avatar lane

#### Scenario: Group chat grouped message tail
- **WHEN** the chat screen renders a grouped incoming message that is not the last item in its sender group
- **THEN** the layout SHALL preserve the existing grouped-message alignment behavior without shifting the bubble edge unexpectedly

### Requirement: Adjacent message UI follows bubble edge alignment
The Flutter chat UI SHALL keep message-adjacent elements visually anchored to the corrected bubble position so that spacing remains consistent after the direct-message fix.

#### Scenario: Direct chat reaction row
- **WHEN** an incoming direct-message bubble has reactions
- **THEN** the reaction row SHALL align to the same left edge as the corrected bubble layout

#### Scenario: Direct chat timestamp and message body
- **WHEN** an incoming direct-message bubble renders text, media, or metadata rows
- **THEN** timestamps and message content SHALL remain aligned within the corrected bubble container
