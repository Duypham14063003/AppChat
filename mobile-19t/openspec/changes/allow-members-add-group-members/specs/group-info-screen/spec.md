## ADDED Requirements

### Requirement: All group members can access the add-member action
The Flutter group info screen SHALL expose the add-member action to any current member of a group conversation.

#### Scenario: Regular member opens group info
- **WHEN** a user with role `member` opens the group info screen for a group conversation they belong to
- **THEN** the screen shows the add-member action and allows the existing add-members flow to be started

#### Scenario: Admin opens group info
- **WHEN** a user with role `admin` opens the group info screen for a group conversation they belong to
- **THEN** the screen shows the add-member action

#### Scenario: Creator opens group info
- **WHEN** a user with role `creator` opens the group info screen for a group conversation they belong to
- **THEN** the screen shows the add-member action

### Requirement: Removal controls are creator-only in group info
The Flutter group info screen SHALL expose remove-member controls only when the current user is the group creator, while continuing to show the leave-group action to all members.

#### Scenario: Creator sees remove actions for removable members
- **WHEN** the group creator opens the group info screen
- **THEN** the screen shows remove controls for non-creator members

#### Scenario: Admin does not see remove actions
- **WHEN** a user with role `admin` opens the group info screen
- **THEN** the screen does not show remove-member controls for other members

#### Scenario: Regular member does not see remove actions
- **WHEN** a user with role `member` opens the group info screen
- **THEN** the screen does not show remove-member controls for other members

#### Scenario: Any member can still leave the group
- **WHEN** any current group member opens the group info screen
- **THEN** the screen shows the leave-group action
