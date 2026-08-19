## 1. Pagination Reliability

- [x] 1.1 Refactor chat message pagination state so older-history availability is driven by backend pagination metadata instead of only local message-count growth.
- [x] 1.2 Update manual older-history loading on the chat screen to keep requesting pages while backend history metadata reports more data is available.
- [x] 1.3 Preserve truthful exhausted-history handling so the UI only stops older-history loading after the backend reports no more pages.

## 2. Accurate Bookmark Jump Targeting

- [x] 2.1 Refactor chat jump targeting to resolve the rendered timeline index for a target message instead of using the raw message-array index.
- [x] 2.2 Apply the same rendered-target jump logic to bookmarked-message navigation, deep-link `initialMessageId` handling, and other historical jump entry points.
- [x] 2.3 Verify bookmark taps from the global saved-messages inbox reliably reveal the exact target message on both mobile and Flutter Web.
- [x] 2.4 Update `ChatScreen` lifecycle handling so a changed `initialMessageId` in the same conversation retriggers the historical jump flow.

## 3. Regression Coverage

- [x] 3.1 Add tests for older-history loading that continues when backend pagination still reports more pages on web/manual upward scrolling.
- [x] 3.2 Add tests for bookmarked-message jumps that load multiple older pages before succeeding or reporting true exhaustion.
- [x] 3.3 Add tests for rendered-row targeting so date separators and system rows do not shift the final jump destination away from the requested message.
- [x] 3.4 Add regression tests for repeated route-driven jumps within the same conversation, including bookmark and search-result entry paths that change `messageId` without changing `conversationId`.
