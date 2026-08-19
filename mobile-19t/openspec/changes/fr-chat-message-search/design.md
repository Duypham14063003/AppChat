## Context

Chat messaging works with text, image, and voice types. Search infrastructure exists but is unwired:
- SQLite FTS5 `messages_fts` table with `ChatDao.searchMessages()` — never called from UI
- PostgreSQL `search_vector` tsvector (GENERATED ALWAYS, `simple` config) with GIN index on partitioned `messages` table
- `unaccent` and `pg_trgm` extensions installed
- `SearchController` stub returning 501
- `ChatListScreen` has search bar UI (TextField + state) but `onChanged` does nothing
- `ChatScreen` has search icon that shows "coming soon" snackbar

Target: Telegram-style search UX, performant at tens of millions of messages.

## Goals / Non-Goals

**Goals:**
- Telegram-style global search from chat list with instant local results + server full-history
- Telegram-style in-conversation search with up/down navigation, scroll-to-message, highlight
- Search result snippets with keyword highlighting
- Cursor-based pagination for server search (no OFFSET)
- Performance: local < 300ms, server < 100ms at scale
- Debounced search input to avoid excessive queries

**Non-Goals:**
- Accent-insensitive search (Vietnamese diacritics change word meaning — exact match like Telegram)
- Search by sender filter (Telegram has this but it's a later enhancement)
- Search by date filter (calendar picker — later enhancement)
- Search in media/file messages (only text content indexed)
- Real-time search index updates via WebSocket (FTS5 already syncs on insert)

## Decisions

### D1: Search text config — `simple` (no change)
**Choice**: Keep existing `to_tsvector('simple', ...)` for PostgreSQL search_vector. No accent stripping.
**Rationale**: Vietnamese is tonal — diacritics encode distinct meanings ("dấu" vs "dàu" vs "dãu" are different words). Telegram does exact match. `simple` config does lowercase + whitespace split which is sufficient. `unaccent` would produce semantically wrong results for Vietnamese. The `pg_trgm` extension remains available for future fuzzy search if needed.

### D2: Server search — plainto_tsquery with cursor pagination
**Choice**: Use `plainto_tsquery('simple', query)` against `search_vector` column. Paginate via cursor (message ID + created_at) not OFFSET.
**Rationale**: `plainto_tsquery` handles multi-word queries naturally (implicit AND). Cursor pagination maintains O(1) performance regardless of result position — critical for tens of millions of messages. OFFSET-based pagination degrades as offset grows (PostgreSQL must scan and discard rows). The composite cursor `(created_at, id)` aligns with the partition key for efficient pruning.

### D3: Snippet generation — ts_headline server-side
**Choice**: Use PostgreSQL `ts_headline('simple', content, query, 'MaxWords=30, MinWords=15, StartSel=<mark>, StopSel=</mark>')` for search result snippets.
**Rationale**: Server generates snippets with match markers. Flutter renders highlighted text by parsing `<mark>` tags. This avoids sending full message content for search results — only the relevant snippet. `MaxWords=30` keeps snippets concise.

### D4: Local search — existing FTS5, add conversation filter
**Choice**: Reuse existing `messages_fts` FTS5 table and `ChatDao.searchMessages()`. Add new `searchMessagesInConversation(convId, query)` method that joins FTS5 results with `conv_id` filter.
**Rationale**: FTS5 is already populated on every `insertMessage()` call. The `conv_id` column is stored as UNINDEXED in FTS5 (available for retrieval but not searchable) — filtering by conv_id is done via JOIN with `local_messages` table which has the conv_id column indexed. No schema changes needed.

### D5: Search debounce — 300ms local, 500ms server
**Choice**: Debounce local search at 300ms after last keystroke. Server search triggered explicitly by "Tìm tất cả" button tap (no auto-trigger). In-conversation search: 300ms debounce, local first, then server for older messages.
**Rationale**: 300ms feels instant while avoiding excessive FTS5 queries during fast typing. Server search is explicit to avoid unnecessary API calls — user taps "Tìm tất cả" when local results aren't sufficient. Matches Telegram pattern where local results appear first, server results load on demand.

### D6: Scroll-to-message — scrollable_positioned_list package
**Choice**: Replace `ListView.builder` in `ChatScreen` with `ScrollablePositionedList` from `scrollable_positioned_list` package.
**Rationale**: Standard `ListView` + `ScrollController` cannot scroll to a specific index — only to pixel offsets, which requires knowing item heights in advance (impossible with variable-height message bubbles). `ScrollablePositionedList` provides `scrollTo(index)` and `jumpTo(index)` natively. This is required for both search-result navigation (tap result → scroll to message) and in-conversation search (up/down arrows). The package is well-maintained (pub.dev score 130+, by Google).

### D7: In-conversation search UI — AppBar replacement with counter
**Choice**: When search is active in `ChatScreen`, replace AppBar content with: back arrow + search TextField + "N of M" counter + up/down arrow buttons. Message list remains visible. Current match gets a temporary highlight animation (background color pulse, 1.5s fade).
**Rationale**: Telegram pattern. AppBar replacement keeps the search bar always visible while browsing results. Counter gives spatial awareness. Up/down arrows cycle through matches newest→oldest and back. Highlight animation draws attention to the current match without permanent visual clutter.

### D8: Search result model — unified for local and server
**Choice**: Single `SearchResult` model used for both local and server results:
```dart
class SearchResult {
  final String messageId;
  final String convId;
  final String convName;
  final String? convAvatar;
  final String convType; // DIRECT or GROUP
  final String snippet; // with <mark> tags for highlighting
  final String senderId;
  final String? senderName;
  final DateTime createdAt;
  final String messageType; // text, image, voice, etc.
}
```
**Rationale**: Unified model simplifies the result list UI — same widget renders both local and server results. Local results build snippet client-side (substring around match). Server results use `ts_headline` snippet directly.

### D9: Global search result layout — two-tier Telegram style
**Choice**: Search results displayed in single scrollable list with two sections:
1. **Local results** (header: "Kết quả gần đây") — from FTS5, instant, max 20 results
2. **Server results** (header: "Tất cả tin nhắn") — from API, loaded on "Tìm tất cả" tap or auto-load after local results shown, infinite scroll with cursor pagination

Each result row: conversation avatar (left) + conversation name + sender name (if group) + snippet with bold keyword + relative timestamp (right).
**Rationale**: Telegram shows local results first for instant feedback, server results below for completeness. Two-tier approach gives best perceived performance — user sees results immediately while server query runs.

### D10: API search endpoint — single endpoint, optional conv_id
**Choice**: Single `GET /search/messages?q=&conv_id=&cursor=&limit=20` endpoint. When `conv_id` is provided, search is scoped to that conversation (FR-020). When omitted, search is global across all user's conversations (FR-019). Always validates user membership.
**Rationale**: One endpoint, two modes. Avoids duplicate logic. Membership check ensures users only see messages from their conversations. The `conv_id` filter combined with the GIN index and partition pruning keeps in-conversation search fast even at scale.

### D11: Performance safeguards for tens of millions of messages
**Choice**: Multiple layers:
1. **GIN index** on `search_vector` — already exists, handles FTS efficiently
2. **Partition pruning** — queries include `created_at` range when cursor is used, PostgreSQL skips irrelevant partitions
3. **Cursor pagination** — no OFFSET, uses `(created_at, id)` composite cursor
4. **Result limit** — max 20 per page, hard cap 50
5. **Membership pre-filter** — query only conversations the user belongs to (uses `conversation_members` table)
6. **Query timeout** — 5 second statement timeout on search queries to prevent runaway scans
7. **Minimum query length** — 2 characters minimum to avoid overly broad matches
**Rationale**: Each layer addresses a specific performance risk. GIN index is the primary optimization. Partition pruning reduces scan scope. Cursor pagination avoids the O(n) skip problem. Membership pre-filter narrows the search space. Timeout prevents worst-case scenarios from blocking the connection pool.

## Risks / Trade-offs

- **[FTS5 only indexes text content]** → Voice, image, system messages won't appear in local search. Acceptable — these message types have no searchable text content. Server search has the same limitation (search_vector is generated from content column).
- **[scrollable_positioned_list replaces ListView]** → Requires refactoring ChatScreen message list. The package API is similar to ListView.builder but not identical. Risk of subtle scroll behavior differences. Mitigated by testing scroll-to-bottom, infinite scroll up, and new message auto-scroll.
- **[ts_headline performance]** → `ts_headline` is called per result row which adds overhead. Mitigated by limiting results to 20 per page. At 20 rows, overhead is negligible (< 1ms total).
- **[Local search limited to 7 days]** → FTS5 only contains messages from local cache (7-day eviction). Users searching for older messages must use server search. This is by design — local search is for speed, server search is for completeness.

## Open Questions

- None — all decisions made during exploration phase.
