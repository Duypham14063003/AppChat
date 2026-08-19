## in-conversation-search

Search overlay in ChatScreen with AppBar replacement, up/down navigation through matches, scroll-to-message, highlight animation, and "N of M" counter. Telegram-style UX.

### Requirements

1. **ScrollablePositionedList migration**
   - Add `scrollable_positioned_list` package to `pubspec.yaml`
   - Replace `ListView.builder` in `ChatScreen` with `ScrollablePositionedList.builder`
   - Replace `ScrollController` with `ItemScrollController` + `ItemPositionsListener`
   - Preserve existing behavior: reverse list, infinite scroll up (load more), auto-scroll to bottom on new message, "new message" FAB
   - `_onScroll` logic: use `ItemPositionsListener.itemPositions` stream to detect when user scrolls near the top (oldest loaded messages) to trigger `loadMore()`

2. **Search activation in ChatScreen**
   - Existing search icon in AppBar `actions` — change from snackbar to activating search mode
   - When search active: replace AppBar content with search overlay:
     - Left: back arrow (IconButton) — exits search mode
     - Center: TextField with autofocus, hint "Tìm kiếm..."
     - Right: result counter "N/M" text + up arrow IconButton + down arrow IconButton
   - AppBar background remains same color
   - Message list stays visible below

3. **Search execution (hybrid: local + server)**
   - On query change (debounced 300ms, min 2 chars):
     - First: search local via `ChatDao.searchMessagesInConversation(convId, query)`
     - Then: search server via `ChatRepository.searchMessages(query: q, convId: convId)` for older messages not in local cache
     - Merge results: deduplicate by message ID, sort by `created_at DESC`
   - Store all match message IDs in order
   - Set current match index to 0 (newest match)

4. **ChatDao.searchMessagesInConversation**
   - New method in `ChatDao`:
     ```dart
     Future<List<LocalMessage>> searchMessagesInConversation(String convId, String query)
     ```
   - FTS5 query with conv_id filter:
     ```sql
     SELECT m.* FROM messages_fts fts
     INNER JOIN local_messages m ON m.id = fts.id
     WHERE messages_fts MATCH ? AND m.conv_id = ?
     ORDER BY m.created_at DESC LIMIT 100
     ```
   - Return matched message IDs for navigation

5. **Up/down navigation**
   - Match list ordered newest-first (index 0 = newest match)
   - Down arrow (↓): move to next older match (index + 1)
   - Up arrow (↑): move to next newer match (index - 1)
   - Wrap around: at last match, down goes to first; at first match, up goes to last
   - On each navigation: scroll to matched message, update counter, trigger highlight

6. **Scroll-to-message**
   - Use `ItemScrollController.scrollTo(index: messageIndex, alignment: 0.4)` to center the matched message in viewport
   - `alignment: 0.4` places the message roughly 40% from the top — visible with context above and below
   - Animation duration: 300ms, curve: `Curves.easeInOut`
   - If message is not in currently loaded list (older than loaded range): load messages around that timestamp first, then scroll

7. **Message highlight animation**
   - When a message is the current search match, apply a highlight overlay:
     - Background color: `AppColors.gold.withOpacity(0.15)` (subtle gold tint)
     - Animate: fade in over 200ms, hold 1.5s, fade out over 500ms
   - Track `highlightedMessageId` in state — `MessageBubble` checks if its message ID matches
   - Only one message highlighted at a time

8. **Counter display**
   - Format: "3/12" (current position / total matches)
   - Position: between search TextField and arrow buttons
   - Style: `TextStyle(color: AppColors.textSecondary, fontSize: 14)`
   - When no results: show "0/0"
   - When searching (loading): show small CircularProgressIndicator instead of counter

9. **Exit search mode**
   - Tap back arrow or device back button → exit search mode
   - Clear search query, remove highlight, restore normal AppBar
   - Stay at current scroll position (don't jump back to bottom)

10. **ChatScreen initialMessageId support**
    - Add optional `initialMessageId` parameter to `ChatScreen`
    - On init, if `initialMessageId` is set:
      - Load messages around that message's timestamp (before + after)
      - After messages load, scroll to that message index
      - Apply highlight animation
    - This supports navigation from global search results (FR-018/019)
    - Update `app_router.dart` to pass `initialMessageId` as query parameter

### Integration Points

- `ChatScreen` — search overlay, ScrollablePositionedList migration, highlight state
- `MessageBubble` — accept `isHighlighted` parameter for highlight animation
- `ChatDao` — new `searchMessagesInConversation` method
- `ChatRepository` — reuse `searchMessages(convId: ...)` for server search within conversation
- `chat_providers.dart` — in-conversation search state provider
- `app_router.dart` — `initialMessageId` query parameter on chat route

### Acceptance Criteria

- Tap search icon in ChatScreen → AppBar replaced with search bar, keyboard opens
- Type query → results found, counter shows "N/M"
- Tap ↓ → scrolls to next older match with highlight animation
- Tap ↑ → scrolls to next newer match with highlight animation
- Counter updates on each navigation
- Highlight fades after 1.5 seconds
- Back button → exits search, restores normal AppBar
- Navigate from global search result → ChatScreen opens at that message with highlight
- Existing scroll behavior preserved: infinite scroll up, auto-scroll on new message, new message FAB
- No results → counter shows "0/0", arrows disabled
