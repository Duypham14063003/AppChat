## Why

Group chats currently require an admin or the group creator to add new members. That creates an unnecessary bottleneck for day-to-day coordination because regular members cannot bring the right people into a discussion when the original manager is unavailable.

## What Changes

- Allow any existing group member to add active users to that group.
- Restrict removal of other members to the group creator only.
- Preserve self-leave for all members and preserve creator-only role changes and group deletion.
- Update the group info UI so all members can access the add-member flow, while removal controls remain visible only to the creator.
- Add backend and Flutter tests that cover the new permission matrix.

## Capabilities

### New Capabilities
- `group-member-management`: Defines who can add members, remove other members, and leave a group conversation.
- `group-info-screen`: Defines which membership management actions are visible and actionable from the Flutter group info screen.

### Modified Capabilities

## Impact

- Backend chat membership authorization in `ConversationController` and `ChatService`.
- Flutter group management UI in `GroupInfoScreen` and related chat repository/provider flows.
- Automated coverage for group membership permission rules in backend and Flutter tests.
