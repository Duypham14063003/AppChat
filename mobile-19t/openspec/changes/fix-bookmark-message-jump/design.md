## Context

The chat experience already supports historical message jumps from multiple entry points: bookmarked messages, pinned messages, reply previews, and deep links with `initialMessageId`. The current implementation opens the target conversation and tries to find the target message by repeatedly loading older pages of chat history.

Two failures have emerged in production behavior:

- Flutter Web can stop loading older messages before the bookmarked target becomes available, leaving the user stranded in the timeline with no further API requests.
- Mobile can load the target message but still scroll to the wrong visual position because the jump code uses an index from the raw message list while the rendered timeline also includes date separators and system rows.
- When the user is already inside a conversation, opening a different bookmarked or searched message in that same conversation can fail to jump because `ChatScreen` only reacts to the first `initialMessageId` it sees.

The current frontend logic uses local message-count growth to infer whether more history exists, even though the backend already returns pagination metadata (`hasMore`, `nextCursor`). The backend message cursor also remains time-based, so the frontend must be careful not to treat a temporary count mismatch as proof that history is exhausted.

## Goals / Non-Goals

**Goals:**
- Make bookmarked-message navigation reliably reveal the exact saved message on both mobile and web.
- Keep historical jump loading active until the target message is found or the backend explicitly indicates that older history is exhausted.
- Align scroll targeting with the rendered timeline so message jumps remain accurate even when non-message rows are inserted.
- Ensure route-driven message jumps retrigger when the requested `messageId` changes inside an already open conversation.
- Preserve existing bookmark, pin, reply, and deep-link entry flows while making them more reliable.

**Non-Goals:**
- Introducing a new backend endpoint that fetches a message directly by `messageId`.
- Reworking the entire chat pagination protocol or replacing the current `/conversations/:id/messages` API.
- Changing bookmark ordering, filtering, or storage semantics outside the navigation reliability fix.

## Decisions

### D1: Drive history exhaustion from backend pagination metadata

**Decision:** Frontend history loading will treat backend `hasMore` / `nextCursor` as the source of truth for whether additional older pages are available, instead of relying only on whether the local message count increased after a load.

**Why:** The current `afterCount <= beforeCount` heuristic can incorrectly conclude that history is exhausted, especially when persistence or pagination boundaries produce a page that does not increase the visible local count. The backend already computes whether older history remains, so the UI should preserve that signal.

**Alternatives considered:**
- Keep the message-count heuristic and add more retries. Rejected because it still guesses instead of using the explicit server response.
- Add a separate “jump to message” backend endpoint. Rejected for this change because it adds API surface area and coordination cost beyond the immediate regression fix.

### D2: Track history availability in chat state, not only in widget-local flags

**Decision:** The chat message state exposed to `ChatScreen` will include enough pagination metadata to support reliable older-history loading and exhaustion reporting.

**Why:** The current widget-local `_hasMoreMessages` flag is derived indirectly and can become stale or wrong. Surfacing history-availability state from the notifier keeps pagination decisions closer to the API response and makes deep-link, bookmark, and manual scroll loading follow the same rules.

**Alternatives considered:**
- Continue storing pagination state only in `ChatScreen`. Rejected because it splits loading truth between UI and data layers and makes regression testing harder.

### D3: Resolve scroll targets against rendered timeline rows

**Decision:** Scroll-to-message will target the rendered item index rather than the raw `messages` list index.

**Why:** The rendered chat timeline inserts date separators and system rows, so raw message indices no longer match `ScrollablePositionedList` indices. Calculating the target from the rendered row model ensures the requested message lands in view consistently.

**Alternatives considered:**
- Remove date separators or special rows from the list. Rejected because those rows are intentional UX elements and unrelated to the navigation bug.
- Keep raw index scrolling and adjust alignment heuristically. Rejected because the mismatch is structural, not cosmetic.

### D4: Unify historical jump and manual upward scroll loading

**Decision:** The same older-history loading contract will be used whether the user manually scrolls upward on web or whether the app is resolving a bookmarked-message jump.

**Why:** Both behaviors depend on the same paginated history source. If they use different exhaustion logic, one flow can regress while the other appears healthy. A shared contract reduces platform drift.

**Alternatives considered:**
- Fix bookmarked jumps only and leave manual web scrolling unchanged. Rejected because the user-facing bug report shows both flows are linked through the same history-loading weakness.

### D5: Treat `initialMessageId` changes as new jump requests even when the conversation stays the same

**Decision:** `ChatScreen` will detect changes to `initialMessageId` in `didUpdateWidget` and reset any one-shot initial-jump guard so the new target message is resolved and highlighted.

**Why:** The current screen lifecycle only resets open-state behavior when `conversationId` changes. Under `GoRouter` and the indexed shell, navigating to the same `/chat/:id` route with a different `messageId` can reuse the existing widget state. Without explicit handling for the new target, repeated taps from bookmarks, global search, or other route-driven entry points only focus the chat screen and skip the requested jump.

**Alternatives considered:**
- Force every route-driven jump to rebuild `ChatScreen` with a new key. Rejected because it is broader than needed and would unnecessarily reset other in-screen state.
- Push a separate imperative event bus for message jumps. Rejected because the route query already expresses the requested target and should remain the single source of truth.

## Risks / Trade-offs

- [Risk] Frontend changes may expose latent backend cursor limitations when many messages share similar timestamps. → Mitigation: preserve backend pagination metadata in state and add regression tests around older-history continuation and exhaustion handling.
- [Risk] Refactoring jump targeting to rendered-row indices could affect existing search, reply, or pin navigation. → Mitigation: keep all message-jump entry points on the same targeting helper and expand navigation tests.
- [Risk] More explicit pagination state in the notifier increases state-management complexity. → Mitigation: keep the state surface focused on older-history loading metadata only and document it in the notifier design.
- [Risk] Re-triggering route-driven jumps in the same conversation could cause duplicate scroll/highlight behavior when the target has not actually changed. → Mitigation: only reset the initial-jump guard when the incoming `messageId` differs from the previous one and cover both repeated-target and new-target cases in tests.

## Migration Plan

1. Update the chat navigation requirements and design assumptions for reliable bookmark jumps.
2. Refactor frontend pagination state so the notifier preserves backend history-availability metadata.
3. Update `ChatScreen` jump targeting to resolve against rendered rows.
4. Update same-conversation route handling so a new `messageId` retriggers jump resolution without requiring a full conversation change.
5. Add regression tests for:
   - web/manual older-history loading
   - bookmarked-message deep jumps
   - repeated route-driven jumps in the same conversation
   - rendered-index scroll accuracy
6. Validate bookmark and search-result jump behavior on mobile and web before rollout.

**Rollback:** If the new pagination-state wiring causes regressions, revert the frontend state and scroll-target changes together. No database or API schema migration is required for rollback.

## Open Questions

None. The change will improve reliability within the existing API surface rather than introduce a new message-lookup endpoint.
