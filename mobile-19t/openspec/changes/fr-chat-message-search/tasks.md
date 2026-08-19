## 1. Flutter: Add scrollable_positioned_list Package

- [x] 1.1 Add `scrollable_positioned_list: ^0.3.8` to `pubspec.yaml`
- [x] 1.2 Run `flutter pub get` to verify package resolves

## 2. Flutter: Migrate ChatScreen to ScrollablePositionedList

- [x] 2.1 In `ChatScreen` (`lib/features/chat/screens/chat_screen.dart`):
  - Replace `ScrollController _scrollController` with `ItemScrollController _itemScrollController` and `ItemPositionsListener _itemPositionsListener`
  - Replace `ListView.builder` with `ScrollablePositionedList.builder` using same `reverse: true`, padding, itemCount, itemBuilder
  - Update `_onScroll` logic: listen to `_itemPositionsListener.itemPositions` stream, detect when max visible index approaches `messages.length` to trigger `loadMore()`
  - Update `_isAtBottom` check: use `itemPositions` to check if index 0 is visible
  - Update auto-scroll on new message: use `_itemScrollController.scrollTo(index: 0)` instead of `_scrollController.animateTo(0)`
  - Update "new message" FAB: use `_itemScrollController.scrollTo(index: 0)`
  - Remove `_scrollController.dispose()` — ItemScrollController doesn't need dispose
- [x] 2.2 Add `initialMessageId` parameter to `ChatScreen` constructor (optional String?)
- [x] 2.3 Implement `initialMessageId` handling in `initState`:
  - If set: after messages load, find index of message with that ID, call `_itemScrollController.jumpTo(index: idx, alignment: 0.4)`
  - Set `_highlightedMessageId` state for highlight animation
- [x] 2.4 Update `app_router.dart`: add `queryParams['messageId']` to ChatScreen route, pass as `initialMessageId`
- [ ] 2.5 Verify: existing chat behavior unchanged — messages load, scroll up loads more, new messages auto-scroll, FAB works

## 3. Flutter: Message Highlight Animation

- [x] 3.1 Add `isHighlighted` parameter to `MessageBubble` widget
- [x] 3.2 In `MessageBubble`: when `isHighlighted` is true, wrap bubble in `AnimatedContainer` or `TweenAnimationBuilder`:
  - Background overlay: `AppColors.gold.withOpacity(0.15)` → transparent
  - Duration: fade in 200ms, hold 1.5s, fade out 500ms (total ~2.2s)
- [x] 3.3 In `ChatScreen._buildMessageItems()`: pass `isHighlighted: msg.id == _highlightedMessageId` to each `MessageBubble`
- [x] 3.4 Add timer to clear `_highlightedMessageId` after 2.2 seconds

## 4. Flutter: ChatDao — Search Improvements

- [x] 4.1 Add `searchMessagesInConversation(String convId, String query)` to `ChatDao`
- [x] 4.2 Add `searchMessagesWithContext(String query, {int limit = 20})` to `ChatDao`
- [x] 4.3 Ensure FTS5 query builds prefix-match tokens: split query by spaces, wrap each word as `"word"*`, join with spaces

## 5. Flutter: Search Result Model & Snippet Widget

- [x] 5.1 Create `SearchResult` model class in `lib/features/chat/data/search_result.dart`
- [x] 5.2 Create `HighlightedSnippet` widget in `lib/features/chat/widgets/highlighted_snippet.dart`
- [x] 5.3 Client-side snippet builder for local results

## 6. Flutter: Search Providers

- [x] 6.1 Create `localSearchProvider` in `lib/features/chat/providers/chat_providers.dart`
- [x] 6.2 Create `serverSearchNotifierProvider` as `AsyncNotifierProvider`
- [x] 6.3 Create `inConversationSearchNotifierProvider(String convId)` as family `AsyncNotifierProvider`:
  - Note: Implemented directly in ChatScreen state instead of a separate provider for simplicity — search state is local to the screen

## 7. API: Implement SearchController

- [x] 7.1 Add `searchMessages` method to `ChatService`
- [x] 7.2 Replace `SearchController.searchMessages()` stub with full implementation
- [x] 7.3 Add `SearchMessagesDto` in `dto/chat.dto.ts`
- [x] 7.4 Inject `ChatService` into `SearchController` (update `chat.module.ts` if needed)

## 8. Flutter: ChatRepository — Search Method

- [x] 8.1 Add `searchMessages` method to `ChatRepository`

## 9. Flutter: ChatListScreen — Wire Search

- [x] 9.1 Refactor `ChatListScreen` to show search results when query is active
- [x] 9.2 Implement "Tìm tất cả" button
- [x] 9.3 Create `SearchResultTile` widget (`lib/features/chat/widgets/search_result_tile.dart`)
- [x] 9.4 Implement tap handler on `SearchResultTile`
- [x] 9.5 Add debounce to search input

## 10. Flutter: In-Conversation Search Overlay

- [x] 10.1 Add search state to `_ChatScreenState`
- [x] 10.2 Implement search AppBar
- [x] 10.3 Wire search icon in existing AppBar
- [x] 10.4 Wire search TextField to `inConversationSearchNotifierProvider`
- [x] 10.5 Wire up/down arrow buttons
- [x] 10.6 Implement scroll-to-match
- [x] 10.7 Implement `_exitSearchMode()`

## 11. Integration & Verification

- [ ] 11.1 Verify: ChatListScreen search → type query → local results appear instantly
- [ ] 11.2 Verify: tap "Tìm tất cả" → server results load below local results
- [ ] 11.3 Verify: tap any search result → opens conversation at that message with highlight
- [ ] 11.4 Verify: ChatScreen search icon → search overlay appears
- [ ] 11.5 Verify: type query in conversation search → counter shows matches
- [ ] 11.6 Verify: up/down arrows → scroll to matches with highlight animation
- [ ] 11.7 Verify: back button in search → exits search, stays at current position
- [ ] 11.8 Verify: existing chat behavior unchanged after ScrollablePositionedList migration
- [x] 11.9 Run `flutter analyze` in apps/mobile — no errors
- [x] 11.10 Run `npm run lint && npm run build` in apps/api — no errors
