## Context

The current chat-list search surface in `ChatListScreen` debounces user input and immediately queries the local Drift FTS cache. Server-side full-history search exists separately behind an explicit "Tìm tất cả trên server" action. That split causes two UX problems for the global chat search entry:

- the first results can be incomplete because local cache depth varies across web, mobile, and fresh sessions
- the interaction model does not match the intended global-search behavior, where typing a valid query should search the user's full message history

The backend contract for `GET /api/v1/search/messages` is already defined and supports the fields this UI needs: query validation, authenticated membership filtering, snippet markup, and cursor pagination. The frontend also already has a `SearchResult` model, search result tile, and message-jump routing that can be reused.

## Goals / Non-Goals

**Goals:**
- Make the chat-list search entry server-driven for valid global message queries.
- Surface loading, empty, error, and pagination states directly from the server search flow.
- Keep result-row rendering aligned with the API response contract for avatar, conversation name, snippet, sender label, and relative time.
- Preserve the existing tap-to-open-message behavior by continuing to route search results into the chat message-jump flow.

**Non-Goals:**
- Replacing in-conversation search behavior inside `ChatScreen`.
- Removing local search infrastructure from the app entirely.
- Changing backend search ranking, SQL strategy, or response schema beyond the already defined API contract.
- Introducing a new message-open endpoint separate from the existing conversation + `messageId` navigation flow.

## Decisions

### D1: Make chat-list global search server-first once the query is valid

**Decision:** When the chat-list search query reaches the backend minimum length, the UI will issue server search requests directly instead of showing local-first results and waiting for a separate user action.

**Why:** The chat-list search entry is a global search surface, and device-local cache cannot guarantee complete results. Searching server-side immediately matches the intended UX and keeps results consistent across platforms and sessions.

**Alternatives considered:**
- Keep local-first with an explicit "Tìm tất cả" button. Rejected because it preserves incomplete first results and the extra action the user wants removed.
- Show local results first, then silently replace them with server results. Rejected because it introduces state churn, duplicate-row reconciliation, and confusing result transitions for little product benefit.

### D2: Reuse the existing server search provider shape with query-driven triggering

**Decision:** The current server-search notifier and repository contract will remain the main data path, but `ChatListScreen` will trigger it automatically after debounce instead of only from an explicit button tap.

**Why:** The provider already models `query`, `results`, `nextCursor`, `hasMore`, and loading states. Reusing that structure limits scope and keeps the pagination contract aligned with the API.

**Alternatives considered:**
- Replace the provider with a brand-new search state machine. Rejected because it duplicates working pieces without adding product value.
- Call the repository directly from the widget. Rejected because it would bypass Riverpod state, complicate pagination, and weaken testability.

### D3: Separate global-search UI states from local-cache labels

**Decision:** The chat-list search UI will stop presenting server-driven results under labels that imply recent device-local cache, and it will render a single global-results flow for valid queries.

**Why:** Once the search source of truth is the backend, labels like "Kết quả gần đây" become misleading. The UI should clearly represent that it is showing full-history message matches, while still allowing an empty state or loading state without local-first sections.

**Alternatives considered:**
- Keep the existing "Kết quả gần đây" section header for server results. Rejected because it misdescribes the data source and search scope.
- Show both local and server sections together. Rejected because the change goal is to simplify the entry flow into a single global search experience.

### D4: Keep navigation into existing historical message jump behavior

**Decision:** Search-result taps will continue to navigate using `convId` plus `messageId`, relying on the existing chat-screen historical jump logic to reveal the matched message.

**Why:** The message-jump flow already supports resolving older history and is the right integration point for global search results. Reusing it keeps search concerns focused on discovery rather than re-implementing chat opening behavior.

**Alternatives considered:**
- Add a dedicated "open search hit" API or route. Rejected because the existing jump flow already covers the needed behavior.
- Prefetch surrounding conversation pages directly in the search screen. Rejected because it duplicates chat-screen responsibilities.

## Risks / Trade-offs

- [Risk] Server-first search can feel slower than local cache on high-latency networks. → Mitigation: keep the debounce short, show immediate loading feedback, and avoid redundant requests for invalid/empty queries.
- [Risk] Rapid typing can produce stale responses arriving out of order. → Mitigation: keep query-aware provider state and discard or overwrite responses that do not match the latest active query.
- [Risk] Existing wording or tests may still assume the "Tìm tất cả trên server" button and local-results section. → Mitigation: update specs and regression tests together with the UI state model.
- [Risk] Global search still depends on downstream message-jump reliability. → Mitigation: explicitly retain integration with the existing `chat-message-jump-navigation-ui` capability rather than introducing a parallel open flow.

## Migration Plan

1. Update the chat-list global search requirements to make server search the primary behavior for valid queries.
2. Adjust the frontend search state flow so debounced input triggers server search automatically and paginates with backend cursor metadata.
3. Remove or replace UI affordances that imply manual escalation from local search to server search.
4. Revalidate navigation from a global search result into the existing message-jump flow.
5. Roll back by restoring the explicit server-search trigger if the new automatic flow causes regressions; no backend migration is required.

## Open Questions

None. The API contract, UI mapping, and navigation target are sufficiently defined for implementation.
