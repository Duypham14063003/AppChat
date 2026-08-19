## ADDED Requirements

### Requirement: Chat list screen displays conversations
The Flutter app SHALL display a chat list screen showing all conversations the user is a member of, sorted by most recent message. Each conversation item SHALL show: avatar, name (contact name for DIRECT, group name for GROUP), last message preview (truncated), timestamp, and unread badge.

#### Scenario: Chat list loads from local cache
- **WHEN** user navigates to chat list
- **THEN** conversations are loaded from Drift local cache instantly (< 1 second), then refreshed from API in background

#### Scenario: Conversation order updates on new message
- **WHEN** a new message arrives in any conversation
- **THEN** that conversation moves to the top of the list with updated preview and timestamp

#### Scenario: Unread badge displays count
- **WHEN** conversation has 3 unread messages
- **THEN** a badge with "3" is displayed on the conversation item

### Requirement: Chat screen with message bubbles
The Flutter app SHALL display a chat screen with message bubbles. Sent messages appear on the right (gold accent), received messages on the left (dark surface). Each bubble shows content, timestamp, and status indicator (for sent messages).

#### Scenario: Chat screen loads messages
- **WHEN** user opens a conversation
- **THEN** messages are loaded from Drift cache first, then synced with server if needed

#### Scenario: New message appears in real-time
- **WHEN** a new message arrives via WebSocket while chat screen is open
- **THEN** the message bubble appears at the bottom with smooth animation

#### Scenario: Auto-scroll to bottom on new message
- **WHEN** user is at the bottom of the chat and a new message arrives
- **THEN** the list auto-scrolls to show the new message

#### Scenario: No auto-scroll when reading history
- **WHEN** user has scrolled up to read older messages and a new message arrives
- **THEN** a "New message" floating button appears instead of auto-scrolling

### Requirement: Optimistic UI for sending messages
The Flutter app SHALL display sent messages immediately with pending status (⏳) before server confirmation. On ACK, status updates to sent (✓). The message input field SHALL clear immediately after send.

#### Scenario: Optimistic message display
- **WHEN** user types "Hello" and taps send
- **THEN** message bubble appears immediately with ⏳ status, input field clears

#### Scenario: ACK updates status
- **WHEN** server ACK is received
- **THEN** message status changes from ⏳ to ✓

### Requirement: Infinite scroll for message history
The Flutter app SHALL load older messages when the user scrolls to the top of the message list. A shimmer loading indicator SHALL be shown while loading. Loading SHALL use cursor-based pagination via REST API.

#### Scenario: Scroll up loads older messages
- **WHEN** user scrolls to the top of the message list
- **THEN** shimmer loading appears, 30 older messages are loaded and prepended to the list

#### Scenario: No more messages indicator
- **WHEN** all messages have been loaded (hasMore = false)
- **THEN** scrolling up shows "Đầu cuộc trò chuyện" indicator

### Requirement: Local search via Drift FTS
The Flutter app SHALL provide a search bar in the chat list that searches message content in the local Drift cache using FTS5. Results SHALL appear within 300ms and show message snippet with highlighted match, conversation name, and timestamp.

#### Scenario: Local search returns results
- **WHEN** user types "meeting" in search bar
- **THEN** matching messages from the last 7 days appear within 300ms with highlighted snippets

#### Scenario: Search with no results
- **WHEN** user searches for a term with no matches
- **THEN** "Không tìm thấy kết quả" is displayed

### Requirement: Drift local database schema for chat
The Flutter app SHALL define Drift tables for `conversations` and `messages` mirroring the server schema. The local DB SHALL support: insert/update/delete operations, query by conversation with ordering, FTS5 search on message content, and 7-day eviction policy.

#### Scenario: Drift schema matches server data
- **WHEN** messages are received from server API or WebSocket
- **THEN** they can be inserted into Drift tables without data loss

#### Scenario: Old messages are evicted
- **WHEN** Drift cleanup runs (on app start)
- **THEN** messages older than 7 days are deleted, conversations not viewed in 30 days are removed

### Requirement: Chat navigation via go_router
The Flutter app SHALL add routes: `/chat` (chat list), `/chat/:id` (chat screen). Navigation from chat list to chat screen SHALL pass conversation ID. Push notification tap SHALL deep-link to `/chat/:id`.

#### Scenario: Navigate from list to chat
- **WHEN** user taps a conversation in the chat list
- **THEN** app navigates to `/chat/:id` showing the chat screen for that conversation

#### Scenario: Deep link from notification
- **WHEN** user taps a push notification for conversation X
- **THEN** app opens and navigates to `/chat/X`

