## ADDED Requirements

### Requirement: Update group info (name, avatar)
The system SHALL provide `PATCH /conversations/:id` endpoint. Only users with role `creator` or `admin` in the conversation MAY update. Updatable fields: `name` (string, 1-255 chars), `avatar_url` (string, nullable). The endpoint SHALL return the updated conversation.

#### Scenario: Admin renames group
- **WHEN** admin sends `PATCH /conversations/:id { name: "New Name" }`
- **THEN** conversation name is updated and a system message "renamed_group" is inserted

#### Scenario: Regular member tries to rename
- **WHEN** a member with role `member` sends `PATCH /conversations/:id { name: "New Name" }`
- **THEN** server returns HTTP 403 Forbidden

#### Scenario: Update DIRECT conversation rejected
- **WHEN** user sends `PATCH /conversations/:id` for a DIRECT conversation
- **THEN** server returns HTTP 400 "Cannot update DIRECT conversations"

### Requirement: Add members to group
The system SHALL provide `POST /conversations/:id/members` endpoint with body `{ member_ids: string[] }`. Only `creator` or `admin` role MAY add members. Members already in the group SHALL be silently skipped. Each new member gets role `member`. A system message "added_member" SHALL be inserted for each new member added.

#### Scenario: Admin adds 2 new members
- **WHEN** admin sends `POST /conversations/:id/members { member_ids: ["id1", "id2"] }`
- **THEN** both users are added as members and system messages are generated for each

#### Scenario: Add member already in group
- **WHEN** admin adds a user who is already a member
- **THEN** the user is silently skipped, no error, no duplicate

### Requirement: Remove member from group
The system SHALL provide `DELETE /conversations/:id/members/:userId` endpoint. Only `creator` or `admin` MAY remove other members. Admins CANNOT remove the creator. A member MAY remove themselves (leave group). A system message SHALL be inserted: "removed_member" if removed by admin, "left_group" if self-removal.

#### Scenario: Admin removes a member
- **WHEN** admin sends `DELETE /conversations/:id/members/:userId`
- **THEN** the member is removed and a "removed_member" system message is inserted

#### Scenario: Member leaves group
- **WHEN** member sends `DELETE /conversations/:id/members/:ownUserId`
- **THEN** the member is removed and a "left_group" system message is inserted

#### Scenario: Try to remove creator
- **WHEN** admin sends `DELETE /conversations/:id/members/:creatorId`
- **THEN** server returns HTTP 403 "Cannot remove the group creator"

### Requirement: Change member role
The system SHALL provide `PATCH /conversations/:id/members/:userId` endpoint with body `{ role: "admin" | "member" }`. Only the `creator` MAY change roles. The creator's own role CANNOT be changed.

#### Scenario: Creator promotes member to admin
- **WHEN** creator sends `PATCH /conversations/:id/members/:userId { role: "admin" }`
- **THEN** the member's role is updated to admin

#### Scenario: Non-creator tries to change role
- **WHEN** an admin sends `PATCH /conversations/:id/members/:userId { role: "admin" }`
- **THEN** server returns HTTP 403 "Only the group creator can change roles"

### Requirement: Delete group
The system SHALL provide `DELETE /conversations/:id` endpoint. Only the `creator` MAY delete a group. Deleting a group SHALL soft-delete all messages (set deleted_at) and remove all conversation_members records. The conversation record itself is kept with a `deleted_at` timestamp (requires adding this column or using a flag).

#### Scenario: Creator deletes group
- **WHEN** creator sends `DELETE /conversations/:id`
- **THEN** all members are removed, messages are soft-deleted, conversation is marked as deleted

#### Scenario: Non-creator tries to delete
- **WHEN** admin sends `DELETE /conversations/:id`
- **THEN** server returns HTTP 403 "Only the group creator can delete the group"

