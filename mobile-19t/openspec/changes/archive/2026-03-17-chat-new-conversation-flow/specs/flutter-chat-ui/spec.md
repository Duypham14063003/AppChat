## MODIFIED Requirements

### Requirement: Chat list screen displays conversations
The Flutter app SHALL display a chat list screen showing all conversations the user is a member of, sorted by most recent message. Each conversation item SHALL show: avatar, name (contact name for DIRECT, group name for GROUP), last message preview (truncated), timestamp, and unread badge. The FAB (floating action button) SHALL navigate to the contact picker screen (`/contacts/pick`) to start a new conversation.

#### Scenario: Chat list loads from local cache
- **WHEN** user navigates to chat list
- **THEN** conversations are loaded from Drift local cache instantly (< 1 second), then refreshed from API in background

#### Scenario: Conversation order updates on new message
- **WHEN** a new message arrives in any conversation
- **THEN** that conversation moves to the top of the list with updated preview and timestamp

#### Scenario: Unread badge displays count
- **WHEN** conversation has 3 unread messages
- **THEN** a badge with "3" is displayed on the conversation item

#### Scenario: FAB opens contact picker
- **WHEN** user taps the FAB on the chat list screen
- **THEN** app navigates to `/contacts/pick` to select a contact for a new conversation

