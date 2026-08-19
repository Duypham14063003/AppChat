## ADDED Requirements

### Requirement: ChatScreen AppBar displays conversation partner info
The ChatScreen AppBar SHALL display the other member's avatar, name, and online status for DIRECT conversations. The avatar SHALL be a CircleAvatar with the member's profile image (or initials fallback). The name SHALL be displayed as the primary title. The online status SHALL be displayed as a subtitle below the name.

#### Scenario: Open a DIRECT conversation
- **WHEN** user navigates to `/chat/:id` for a DIRECT conversation
- **THEN** the AppBar shows the other member's avatar (CircleAvatar), full name as title, and online status as subtitle

#### Scenario: Other member has avatar
- **WHEN** the other member has a non-null `avatar_url`
- **THEN** the CircleAvatar displays the network image

#### Scenario: Other member has no avatar
- **WHEN** the other member has no `avatar_url`
- **THEN** the CircleAvatar displays the first letter of their name as initials with gold color on surfaceVariant background

#### Scenario: Conversation info loading
- **WHEN** conversation detail is still loading from local DB or API
- **THEN** the AppBar shows a placeholder (e.g., "Chat" title) until data is available

### Requirement: Conversation detail provider exists
The Flutter app SHALL provide a `conversationDetailProvider` (Riverpod FutureProvider.family keyed by conversationId) that returns `LocalConversation?`. It SHALL first attempt to load from `ChatDao.getConversation(id)`. If not found locally, it SHALL fetch from `ChatRepository.getConversation(id)`, store in local DB, and return the result.

#### Scenario: Conversation exists in local DB
- **WHEN** `conversationDetailProvider` is read for a conversation that exists in Drift
- **THEN** the local `LocalConversation` is returned immediately without an API call

#### Scenario: Conversation not in local DB
- **WHEN** `conversationDetailProvider` is read for a conversation not in Drift
- **THEN** the provider fetches from `GET /conversations/:id`, stores in local DB, and returns the result

