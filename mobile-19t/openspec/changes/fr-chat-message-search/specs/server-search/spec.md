## server-search

API full-text search endpoint using PostgreSQL tsvector/GIN with cursor pagination and snippet generation. Flutter integration with "Tìm tất cả" trigger and infinite scroll.

### Requirements

1. **API: SearchController implementation**
   - Replace stub `GET /search/messages` (currently returns 501) with full implementation
   - Query parameters:
     - `q` (string, required, min 2 chars) — search query
     - `conv_id` (uuid, optional) — scope to single conversation (used by in-conversation-search)
     - `cursor` (string, optional) — composite cursor `{created_at}_{id}` for pagination
     - `limit` (number, optional, default 20, max 50)
   - Authentication: require valid JWT (existing `@ApiBearerAuth()`)
   - Authorization: only return messages from conversations the user is a member of

2. **Search query execution**
   - Build query: `plainto_tsquery('simple', :query)` against `search_vector` column
   - Membership filter: JOIN `conversation_members` WHERE `user_id = :userId`
   - If `conv_id` provided: add `WHERE conv_id = :convId` (also verify membership)
   - Exclude deleted messages: `WHERE deleted_at IS NULL`
   - Order: `created_at DESC, id DESC` (newest first)
   - Cursor filter: `WHERE (created_at, id) < (:cursorDate, :cursorId)`
   - Statement timeout: `SET LOCAL statement_timeout = '5s'` per query

3. **Snippet generation**
   - Use `ts_headline('simple', content, query, 'MaxWords=30, MinWords=15, StartSel=<mark>, StopSel=</mark>')` for each result
   - For non-text messages (voice, image, system): return type label as snippet, no ts_headline

4. **Response format**
   ```json
   {
     "results": [
       {
         "message_id": "uuid",
         "conv_id": "uuid",
         "conv_name": "string or null",
         "conv_type": "DIRECT|GROUP",
         "conv_avatar_url": "string or null",
         "snippet": "...text with <mark>keyword</mark>...",
         "sender_id": "uuid",
         "sender_name": "string",
         "message_type": "text",
         "created_at": "ISO8601"
       }
     ],
     "next_cursor": "2026-03-17T10:00:00Z_uuid-here",
     "has_more": true,
     "total_estimate": 42
   }
   ```
   - `total_estimate`: use `count_estimate` from `EXPLAIN` or `ts_stat` for approximate count (avoid exact COUNT on millions of rows)
   - `next_cursor`: composite of last result's `created_at` + `id`

5. **Performance safeguards**
   - GIN index on `search_vector` — already exists
   - Partition pruning: cursor-based queries naturally include `created_at` filter which enables partition pruning
   - Membership pre-filter: subquery `SELECT conv_id FROM conversation_members WHERE user_id = :userId` narrows search scope
   - No OFFSET — cursor pagination only
   - Hard limit 50 results per page
   - 5-second statement timeout
   - Minimum query length 2 characters (reject shorter with 400)

6. **Flutter: ChatRepository — searchMessages method**
   - Add `searchMessages({required String query, String? convId, String? cursor, int limit = 20})` to `ChatRepository`
   - GET `/search/messages` with query parameters
   - Return parsed `ServerSearchResponse` with `List<SearchResult>`, `nextCursor`, `hasMore`

7. **Flutter: Server search provider**
   - Create `serverSearchProvider` — `AsyncNotifierProvider` that manages:
     - Current query
     - Accumulated results (for infinite scroll)
     - Loading state (initial load vs load more)
     - Cursor for next page
   - Methods: `search(query)`, `loadMore()`, `clear()`
   - Triggered when user taps "Tìm tất cả" in ChatListScreen

8. **Flutter: Server results UI in ChatListScreen**
   - Below local results section, show "Tất cả tin nhắn" header
   - Render server results using same result row widget as local results
   - Infinite scroll: load more when scrolled near bottom
   - Loading indicator at bottom during load more
   - Tap result → same navigation as local search (open conversation, scroll to message)

### Integration Points

- `SearchController` — implement full search endpoint
- `ChatService` — add `searchMessages()` method with query builder
- `ChatRepository` (Flutter) — new `searchMessages` method
- `chat_providers.dart` — new server search provider
- `ChatListScreen` — "Tìm tất cả" button + server results section

### Acceptance Criteria

- `GET /search/messages?q=hello` returns matching messages with snippets
- `GET /search/messages?q=hello&conv_id=uuid` returns only messages from that conversation
- Results only include messages from user's conversations (membership check)
- Cursor pagination works: second page returns different results
- Snippet contains `<mark>` tags around matched keywords
- Query with no results returns empty array (not error)
- Query shorter than 2 chars returns 400
- Search completes in < 100ms with 10M+ messages (GIN index + partition pruning)
- Flutter: tap "Tìm tất cả" → server results load below local results
- Flutter: scroll down → more results load (infinite scroll)
- Flutter: tap server result → opens conversation at that message
