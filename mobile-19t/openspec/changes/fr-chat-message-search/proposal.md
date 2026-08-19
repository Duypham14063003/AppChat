## Why

Chat messaging is functional with text, image, and voice messages. Users currently have no way to find past messages — the search bar in `ChatListScreen` exists as UI but has no logic, and the search icon in `ChatScreen` shows a "coming soon" snackbar. The API `SearchController` returns 501 Not Implemented.

The infrastructure is already in place on both sides:
- **SQLite**: FTS5 virtual table `messages_fts` exists, `ChatDao.searchMessages()` method exists but is never called from UI
- **PostgreSQL**: `search_vector` tsvector column with GIN index on partitioned `messages` table, `unaccent` and `pg_trgm` extensions installed

This change implements CHAT-FR-018 (Local Search, P0 MUST), CHAT-FR-019 (Server Full-History Search, P1 SHOULD), and CHAT-FR-020 (In-Conversation Search, P1 SHOULD). All three share search infrastructure and UI patterns — implementing them together avoids duplicate work.

Performance target: smooth operation with tens of millions of messages in PostgreSQL.

## What Changes

Frontend (Flutter):
- Wire `ChatListScreen` search bar to local FTS5 search with debounce — instant results from 7-day cache
- Add "Tìm tất cả" button that triggers server-side full-history search via API
- Display search results as Telegram-style list: conversation avatar, name, message snippet with highlighted keyword, timestamp
- Tap result → navigate to conversation and scroll to that specific message
- Add `scrollable_positioned_list` package for index-based scroll-to-message
- Implement in-conversation search overlay in `ChatScreen`: search bar replaces AppBar, up/down navigation arrows, "N of M" counter, message highlight animation
- Search provider with debounce (300ms local, 500ms server) and cancellation
- Add `searchMessagesInConversation(convId, query)` to `ChatDao` for local in-conversation search

Backend (NestJS):
- Implement `GET /search/messages` endpoint in `SearchController` with full-text search using `plainto_tsquery` against `search_vector`
- Support parameters: `q` (query), `conv_id` (optional, for in-conversation), `cursor` (message ID for pagination), `limit`
- Return results with `ts_headline` snippets, conversation metadata, and cursor-based pagination
- Ensure query plan uses GIN index + partition pruning for performance at scale

## Capabilities

### New Capabilities
- `local-search`: Wire ChatListScreen search bar to Drift FTS5, debounced instant results, result list UI with snippets
- `server-search`: API full-text search endpoint with tsvector/GIN, cursor pagination, snippet generation; Flutter integration with "Tìm tất cả" trigger and infinite scroll results
- `in-conversation-search`: Search overlay in ChatScreen with AppBar replacement, up/down navigation, scroll-to-message, highlight animation, "N of M" counter

### Modified Capabilities
- `flutter-chat-ui`: ChatListScreen search wiring, ChatScreen search overlay, scroll-to-message support via scrollable_positioned_list
- `chat-dao`: New searchMessagesInConversation method, improved FTS5 query handling

## Impact

- **Database**: No schema changes — existing FTS5 (SQLite) and tsvector+GIN (PostgreSQL) infrastructure sufficient
- **API endpoints**: Implement existing stub `GET /search/messages` (currently returns 501)
- **Packages (Flutter)**: `scrollable_positioned_list` (scroll-to-index for message list)
- **Packages (API)**: None
- **Performance**: GIN index + partition pruning handles tens of millions of messages. Local FTS5 search < 300ms. Server search < 100ms with proper index usage. Cursor-based pagination avoids OFFSET performance degradation.
- **Migration**: None required — all DB infrastructure already exists
