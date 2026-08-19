## 1. Backend Bookmark Model

- [x] 1.1 Add the `message_bookmarks` database migration and TypeORM entity, then register it in the chat module
- [x] 1.2 Extend chat DTOs/controller routes for `POST`, `DELETE`, and `GET /conversations/:id/bookmarks`
- [x] 1.3 Implement `ChatService` bookmark create/delete/list logic with membership validation, duplicate protection, and message ownership checks

## 2. Mobile Bookmark Data Flow

- [x] 2.1 Add chat repository methods for bookmark create, delete, and list APIs
- [x] 2.2 Add Drift bookmark table and migration, plus DAO helpers for reading and replacing conversation bookmarks
- [x] 2.3 Add a Riverpod conversation bookmark provider that loads cache first, refreshes from the API, and answers per-message bookmark state

## 3. Mobile UI Integration

- [x] 3.1 Add bookmark/unbookmark action wiring to the message context menu and chat screen error handling
- [x] 3.2 Add conversation-scoped bookmarked-messages browsing UI with tap-to-jump back into the chat timeline
- [x] 3.3 Add bookmarked visual state on message items if the existing chat layout supports it cleanly

## 4. Verification

- [x] 4.1 Add backend tests for bookmark create/delete/list validation and privacy behavior
- [x] 4.2 Add mobile tests for bookmark provider logic and context-menu label/state changes
- [ ] 4.3 Manually verify bookmarking, unbookmarking, and bookmark retrieval across at least two sessions for the same user
