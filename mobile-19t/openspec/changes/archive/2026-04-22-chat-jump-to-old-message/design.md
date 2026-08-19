## Context

The chat screen already supports several entry points that conceptually "jump to a message": the pinned-message bar, the pinned-message list, bookmarked-message navigation, reply tap, and route-based `initialMessageId`. All of those flows currently converge on a local `_scrollToMessage` helper that only succeeds when the target message already exists in the loaded `chatMessagesProvider` timeline.

That creates a reliability gap for older messages. A valid target can exist on the server and in local metadata, but because the current timeline window only contains the newest slice of history, the app immediately shows "Tin nhắn không trong phạm vi hiển thị" instead of attempting to load older pages. The existing pagination stack already knows how to fetch older messages through `loadMore()`, so the design should reuse that mechanism before introducing new APIs.

## Goals / Non-Goals

**Goals:**
- Allow the chat screen to progressively load older pages when the user requests navigation to a message that is not yet present in the current timeline.
- Reuse one shared jump flow across pinned, bookmarked, reply, and `initialMessageId` entry points.
- Give the user deterministic outcomes: loading while searching older history, success when found, and a final failure state only after history is exhausted.
- Keep the solution within the current mobile pagination architecture.

**Non-Goals:**
- Adding a new backend "load around message" or "fetch by message id with context" endpoint.
- Redesigning pinned-message, bookmark, or reply UI beyond the minimal feedback needed for jump loading.
- Reworking how chat pagination cursors are generated or how message pages are cached.
- Solving cross-conversation global search navigation in this change.

## Decisions

### D1: Introduce a shared "ensure target message is loaded" flow in the chat screen

**Decision:** Add a shared async jump helper in `ChatScreen` that first checks the current timeline, then repeatedly requests older history until the target message appears or pagination stops returning new messages.

**Why:** The user-facing problem is not that scrolling fails; it is that the app never tries to fetch the missing history. A shared helper keeps pinned, bookmarked, reply, and deep-link navigation behavior consistent.

**Alternatives considered:**
- Patch only pinned-message navigation. Rejected because the same gap exists for other message-jump entry points.
- Leave `_scrollToMessage` unchanged and show a richer error. Rejected because it preserves the broken behavior.

### D2: Use pagination exhaustion as the stop condition

**Decision:** Stop the history-loading loop when `loadMore()` no longer increases the loaded message count, and only then surface the final "message unavailable" feedback.

**Why:** The current notifier already exposes a practical exhaustion signal via list growth. Reusing that signal avoids adding a second explicit pagination state contract just for this change.

**Alternatives considered:**
- Hard-code a fixed number of pagination attempts. Rejected because it can fail early on long conversations or waste calls on short ones.
- Add a brand-new `hasMore` provider contract immediately. Rejected because it expands scope beyond the jump behavior itself.

### D3: Show temporary loading feedback while historical jump resolution is in progress

**Decision:** While the app is loading older pages to resolve a requested target message, expose a lightweight loading state and suppress the immediate "out of range" snackbar.

**Why:** Without intermediate feedback, the app appears unresponsive during repeated page loads. The user should understand that the app is actively searching older history rather than failing silently.

**Alternatives considered:**
- Show no loading state and only succeed or fail at the end. Rejected because the delay would feel like a tap miss.
- Block the whole screen with a full-page loader. Rejected because the action is local and should remain lightweight.

### D4: Keep navigation scoped to backward history loading

**Decision:** The shared jump helper only paginates older history (`dir: before`) because the missing-target problem comes from navigating to older messages from the newest window.

**Why:** The current chat screen opens at the latest messages, and the known failure mode is historical navigation. Restricting the direction keeps logic simpler and aligned with the real bug.

**Alternatives considered:**
- Build a bidirectional jump system immediately. Rejected because there is no current user-facing need for loading newer pages after opening on the latest window.

## Risks / Trade-offs

- [Risk] Very old targets can require multiple sequential page loads, causing a visible delay. → Mitigation: show clear loading feedback and stop as soon as the target is found.
- [Risk] Multiple rapid taps on pinned/bookmarked targets could start overlapping history loads. → Mitigation: serialize jump resolution with a single in-flight state in `ChatScreen`.
- [Risk] Pagination exhaustion inferred from message-count growth could be brittle if the notifier behavior changes later. → Mitigation: keep the helper encapsulated so the exhaustion rule can be upgraded without changing all entry points.
- [Risk] Some messages may truly be unavailable locally or remotely even after pagination. → Mitigation: preserve a final failure snackbar after the app has exhausted history loading.

## Migration Plan

1. Add the shared jump-resolution helper in `ChatScreen` and route all message-jump entry points through it.
2. Reuse existing `loadMore()` pagination until the target is found or history is exhausted.
3. Add loading and exhausted-history feedback so the user sees progress and final outcomes clearly.
4. Add tests for found-after-pagination and exhausted-history failure cases.
5. Manually verify pinned/bookmarked/reply navigation to older messages in a long conversation.

**Rollback:** Revert the shared historical jump flow and return entry points to the existing immediate local scroll behavior, though that restores the current false failure state for older messages.

## Open Questions

None. The change intentionally stays within the current mobile pagination model and does not depend on backend API changes.
