## local-search

Wire ChatListScreen search bar to Drift FTS5 for instant local message search with debounce, result list UI, and navigation to matched messages.

### Requirements

1. **Search provider (Riverpod)**
   - Create `localSearchProvider(String query)` — `FutureProvider.family` that calls `ChatDao.searchMessages(query)`
   - Debounce: only trigger after 300ms of no typing, minimum 2 characters
   - Return `List<SearchResult>` with max 20 results
   - Build `SearchResult` from `LocalMessage` + conversation metadata from `LocalConversations`

2. **ChatListScreen search wiring**
   - Existing `_searchController.onChanged` currently does `setState(() {})` — wire it to search provider
   - When query is empty: show normal conversation list
   - When query has >= 2 chars: show search results list after 300ms debounce
   - Show loading indicator during search
   - Show "Không tìm thấy kết quả" when no results

3. **Search result list UI (Telegram-style)**
   - Each result row layout:
     - Left: conversation avatar (CircleAvatar, 40px)
     - Center column:
       - Top: conversation name (bold) + relative timestamp (right-aligned, grey)
       - Bottom: message snippet with matched keyword in bold/highlighted
     - If group conversation: show "Sender: snippet" format
   - Section header: "Kết quả gần đây" (local results)
   - Below local results: "Tìm tất cả trên server ▶" button (triggers server-search capability)

4. **Snippet generation (client-side for local)**
   - Extract substring around first match position: 15 chars before + match + 15 chars after
   - Wrap matched text in a way that Flutter `RichText` can render as bold/highlighted
   - If message type is not text: show type label instead ("🎤 Tin nhắn thoại", "📷 Hình ảnh")

5. **ChatDao improvements**
   - Existing `searchMessages(query)` works but needs conversation metadata
   - Add `searchMessagesWithContext(query, {int limit = 20})` that JOINs with `local_conversations` to return conversation name, avatar, type alongside message data
   - FTS5 query: split words, wrap each in quotes with wildcard: `"word1"* "word2"*` (prefix matching)

6. **Navigate to message on tap**
   - Tap search result → navigate to `ChatScreen(conversationId)` with `initialMessageId` parameter
   - `ChatScreen` receives `initialMessageId` → loads messages around that ID → scrolls to it → highlights it
   - This requires the scroll-to-message infrastructure from `in-conversation-search` spec

### Integration Points

- `ChatListScreen` — wire search bar to provider, render results
- `ChatDao` — enhanced search method with conversation context
- `chat_providers.dart` — new search provider
- `ChatScreen` — accept `initialMessageId` parameter for scroll-to
- `app_router.dart` — pass `initialMessageId` query parameter to ChatScreen route

### Acceptance Criteria

- Type 2+ characters in ChatListScreen search bar → results appear within 300ms
- Results show conversation name, snippet with highlighted match, timestamp
- Tap result → opens conversation scrolled to that message with highlight
- Empty query → shows normal conversation list
- No results → shows "Không tìm thấy kết quả"
- Search is case-insensitive
- Prefix matching works: "xin" matches "xin chào"
