## 1. Backend Global Bookmark Inbox API

- [x] 1.1 Add the user-scoped global bookmark inbox route, DTOs, and query parameters for pagination and conversation-type filtering.
- [x] 1.2 Implement service/query logic that returns the current user's bookmarks across accessible conversations ordered by `marked_at DESC` with flattened message and conversation metadata.
- [x] 1.3 Add backend tests covering privacy, access filtering, pagination, filter behavior, and compatibility with the existing conversation-scoped bookmark routes.

## 2. Mobile Global Bookmark Data Flow

- [x] 2.1 Add repository/model support for fetching the global bookmark inbox with cursor and filter inputs.
- [x] 2.2 Add DAO/provider support for reading cached bookmarks across conversations and composing inbox items with local conversation metadata before refresh completes.
- [x] 2.3 Update bookmark mutation flows so bookmark/unbookmark actions refresh both the conversation-scoped bookmark state and the global inbox state.

## 3. Mobile Inbox UI And Navigation

- [x] 3.1 Add the saved-messages entry point to the chat-list header and register the global inbox route/screen.
- [x] 3.2 Build the global saved-messages UI with ordered mixed-conversation items, empty state, `all/direct/group` filter, and paginated loading behavior.
- [x] 3.3 Wire saved-item taps to open `/chat/:convId?messageId=:messageId` and validate that chat navigation reuses the existing jump-and-highlight behavior.

## 4. Verification

- [x] 4.1 Add mobile tests for global bookmark provider behavior, cache-first rendering, and filter state handling.
- [x] 4.2 Add widget or navigation tests for opening the saved-messages inbox from chat list and routing to the source message.
- [ ] 4.3 Manually verify bookmarking and unbookmarking update the global inbox across at least two conversations and across multiple sessions for the same account.
