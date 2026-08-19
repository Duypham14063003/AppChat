## MODIFIED Requirements

### Requirement: Navigation after new conversation creation preserves back stack
The ContactPickerScreen SHALL use `context.pushReplacement('/chat/$convId')` instead of `context.go('/chat/$convId')` when navigating to a newly created conversation. This ensures the chat list (`/chat`) remains in the navigation back stack, allowing the user to press back to return to the conversation list.

#### Scenario: Create new conversation and navigate back
- **WHEN** user taps a contact in ContactPickerScreen and conversation is created
- **THEN** app navigates to `/chat/:id` AND the back button returns to `/chat` (chat list)

#### Scenario: Back button on new conversation chat screen
- **WHEN** user is on ChatScreen after creating a new conversation from ContactPickerScreen
- **THEN** pressing the back button navigates to the chat list screen (`/chat`)

### Requirement: _refreshFromApi populates other member info for DIRECT conversations
The `ChatListNotifier._refreshFromApi()` method SHALL extract the other member's name and avatar from the API response's `members` array for DIRECT conversations. It SHALL identify the other member by filtering out the current user's ID from the members list. The extracted name and avatar SHALL be stored in `otherMemberName` and `otherMemberAvatar` fields of `LocalConversationsCompanion`.

#### Scenario: DIRECT conversation member info populated
- **WHEN** `_refreshFromApi()` processes a DIRECT conversation from the API
- **THEN** `otherMemberName` is set to the other member's `user.name` and `otherMemberAvatar` is set to the other member's `user.avatar_url`

#### Scenario: Current user filtered from members
- **WHEN** the API returns a DIRECT conversation with 2 members
- **THEN** the member whose `user_id` matches the current authenticated user is excluded, and the remaining member's info is used

#### Scenario: ConversationTile displays correct name
- **WHEN** the chat list screen renders a DIRECT conversation tile
- **THEN** the tile shows the other member's name (not "Unknown") and their avatar

