## ADDED Requirements

### Requirement: Any current group member can add members
The system SHALL allow any current member of a group conversation to add active users through the existing add-members flow. Users who are already members of the conversation SHALL be skipped without failing the request.

#### Scenario: Regular member adds a new colleague
- **WHEN** a user with role `member` sends `POST /conversations/:id/members` for a group conversation they belong to with one or more active user IDs that are not already in the group
- **THEN** the system adds each new user with role `member` and returns a successful add-members response

#### Scenario: Existing members in the request are ignored
- **WHEN** any current group member sends `POST /conversations/:id/members` including user IDs that are already present in the conversation
- **THEN** the system silently skips those existing members and only adds newly eligible users

### Requirement: Only the group creator can remove other members
The system SHALL allow any member to remove themselves from a group conversation, but SHALL require the acting user to have role `creator` when removing a different member.

#### Scenario: Creator removes another member
- **WHEN** the group creator sends `DELETE /conversations/:id/members/:userId` for a non-creator target in that conversation
- **THEN** the target member is removed and the system records the existing removed-member system message behavior

#### Scenario: Admin attempts to remove another member
- **WHEN** a user with role `admin` sends `DELETE /conversations/:id/members/:userId` for a different user in that conversation
- **THEN** the system returns HTTP 403

#### Scenario: Regular member attempts to remove another member
- **WHEN** a user with role `member` sends `DELETE /conversations/:id/members/:userId` for a different user in that conversation
- **THEN** the system returns HTTP 403

#### Scenario: Member leaves the group
- **WHEN** any current group member sends `DELETE /conversations/:id/members/:theirOwnUserId`
- **THEN** the system removes that membership and records the existing left-group system message behavior

#### Scenario: Creator cannot be removed
- **WHEN** any user sends `DELETE /conversations/:id/members/:creatorUserId`
- **THEN** the system returns HTTP 403
