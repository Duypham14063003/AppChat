## ADDED Requirements

### Requirement: Chat surfaces must render normalized avatar URLs
The Flutter chat client SHALL normalize backend-provided avatar values into renderable image URLs before chat surfaces use them for user or group avatar rendering.

#### Scenario: Relative avatar path from direct conversation member
- **WHEN** the chat client receives a direct conversation member avatar value as a relative path
- **THEN** the client SHALL convert that value into a renderable absolute URL before storing or displaying it

#### Scenario: Absolute avatar URL from backend
- **WHEN** the chat client receives an avatar value that is already an absolute URL
- **THEN** the client SHALL preserve the value without rewriting it

### Requirement: Chat surfaces must provide a visible fallback when avatar cannot be rendered
The Flutter chat client SHALL show a visible fallback avatar state when no renderable avatar image is available.

#### Scenario: Avatar value is missing
- **WHEN** a chat surface renders a conversation, contact, or group member without an avatar value
- **THEN** the UI SHALL display initials or an appropriate fallback icon instead of a blank avatar circle

#### Scenario: Avatar value is unusable for rendering
- **WHEN** a chat surface does not have a renderable avatar image after normalization
- **THEN** the UI SHALL use the same initials/icon fallback behavior as if no avatar were provided

### Requirement: Chat avatar behavior must be consistent across supported chat surfaces
The Flutter chat client SHALL apply the same avatar normalization and fallback behavior across supported chat screens that render conversation or member avatars.

#### Scenario: Conversation list avatar rendering
- **WHEN** the conversation list renders direct or group chat entries
- **THEN** each entry SHALL use normalized avatar data and fallback behavior consistently

#### Scenario: Related chat picker and detail surfaces
- **WHEN** chat picker or detail surfaces render conversation/member avatars from the same chat data sources
- **THEN** those surfaces SHALL use the same normalized avatar behavior as the conversation list
