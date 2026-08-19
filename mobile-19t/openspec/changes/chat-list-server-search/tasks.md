## 1. Search Flow Refactor

- [x] 1.1 Update chat-list search state so valid debounced input triggers server search automatically instead of waiting for a separate manual "search all" action
- [x] 1.2 Preserve non-search behavior for empty or too-short queries, including clearing active server-search state when the user exits search
- [x] 1.3 Ensure server-search requests remain query-aware so stale responses do not overwrite newer chat-list search input

## 2. UI and Result Rendering

- [x] 2.1 Update the chat-list search UI to present a single server-driven global results flow with loading, empty, and error states
- [x] 2.2 Replace local-cache-specific labels and affordances so the chat-list search copy matches full-history server search behavior
- [x] 2.3 Verify search result rows map API fields correctly for avatar, conversation name, sender context, snippet/content fallback, and relative time

## 3. Pagination and Navigation

- [x] 3.1 Keep cursor pagination wired to `next_cursor` and `has_more`, and append additional result pages when the user requests more results
- [x] 3.2 Verify tapping a global search result still routes to the source conversation with the matched `messageId`
- [x] 3.3 Confirm the existing chat message-jump flow continues to reveal older matched messages opened from global search

## 4. Regression Coverage

- [x] 4.1 Add tests for debounced server-triggered chat-list search, including the no-request behavior for queries shorter than 2 characters
- [x] 4.2 Add UI-state tests for loading, empty, error, and paginated global search results in the chat-list search surface
- [x] 4.3 Add or update navigation tests to confirm a global search result opens the correct conversation and target message
