## Context

The chat screen supports in-conversation search by querying local FTS results first and then merging server search results when local hits are sparse. The search UI stores only message IDs in `_searchMatchIds`, shows a counter based on that list, and attempts to auto-scroll to the first match with `_scrollToMessage`.

The integration gap is that `_scrollToMessage` only works if the target message already exists in the currently loaded `chatMessagesProvider` timeline. Search results, however, can come from a wider set: older cached local messages or server matches outside the current timeline window. This creates two mismatched result sets:

- the result list counted by the search header, and
- the subset of messages the timeline can actually scroll to right now.

The user-visible symptoms are exactly what we saw in the screenshot: the counter reports multiple matches, but the screen does not reliably jump to the selected match and next/previous can appear inconsistent.

## Goals / Non-Goals

**Goals:**
- Ensure in-chat search auto-scrolls to the first selected match whenever the app presents it as navigable.
- Keep the header counter synchronized with the same result set used by next/previous navigation.
- Define explicit handling for results that are not yet present in the rendered timeline.
- Minimize scope so this fix improves reliability without redesigning search UX.

**Non-Goals:**
- Building a full "search around message" server endpoint in this change.
- Redesigning global chat search outside the conversation screen.
- Changing FTS ranking, highlighting, or snippet presentation.
- Reworking chat pagination beyond what is necessary to support coherent search navigation.

## Decisions

### D1: Treat only timeline-available matches as immediately navigable

**Decision:** The search navigation state shown in the chat-screen header will be derived from matches that can currently be resolved against the loaded conversation timeline, rather than from every raw local or server hit.

**Why:** The current bug exists because the counter reflects a larger set than the navigation layer can use. Synchronizing those two concepts restores trust in the UI quickly and keeps behavior deterministic.

**Alternatives considered:**
- Keep counting all raw hits and let scroll failures silently occur. Rejected because it preserves the current mismatch.
- Fetch surrounding history for every off-screen hit before showing any results. Rejected as more complex and dependent on pagination/search coordination that the current architecture does not yet expose cleanly.

### D2: Filter and order search matches against the current timeline before updating UI state

**Decision:** After local/server search collection, normalize the result IDs against the currently loaded `chatMessagesProvider` data and only expose the filtered, ordered list to `_searchMatchIds`.

**Why:** This gives the counter, first-match auto-scroll, and next/previous controls a single authoritative list. It also lets the code preserve existing `_scrollToMessage` behavior with minimal architectural churn.

**Alternatives considered:**
- Store raw hits and navigable hits in separate lists and show both counts. Rejected because it adds UX complexity without solving the immediate reliability issue.

### D3: Preserve server fallback as a source of discovery, but not of impossible navigation

**Decision:** Server search results may continue to expand discovery, but only message IDs present in the loaded timeline should be counted as current in-screen navigation targets unless the app explicitly loads more history for them.

**Why:** This keeps the existing search fallback useful while avoiding false promises in the counter and navigation buttons.

**Alternatives considered:**
- Remove server fallback entirely for in-conversation search. Rejected because it reduces search usefulness and unnecessarily narrows the feature.

## Risks / Trade-offs

- [Risk] Result counts may decrease compared with raw server/local hit totals. → Mitigation: prefer truthful navigable counts over inflated but misleading totals.
- [Risk] Users may still expect off-screen historical matches to be reachable immediately. → Mitigation: keep the design scoped now, and leave room for a future "load around match" enhancement if product needs it.
- [Risk] Timeline order and search order can diverge if ID normalization is inconsistent. → Mitigation: compute the navigable result list from the currently loaded message collection and reuse it for both counter and navigation.

## Migration Plan

1. Refactor in-chat search state so `_searchMatchIds` represents only the current navigable match set.
2. Keep local/server lookup as discovery inputs, but filter against loaded timeline data before updating the UI counter.
3. Ensure initial search auto-scroll and next/previous buttons operate on the same filtered list.
4. Add tests for counter consistency and auto-scroll behavior when some raw hits are unavailable in the timeline.
5. Manually verify searching in a long conversation with both loaded and unloaded historical matches.

**Rollback:** Revert to the current raw-ID list approach if the filtered navigation model unexpectedly hides too many matches, though that would restore the known counter/scroll mismatch.

## Open Questions

None. The immediate fix is to make the displayed search navigation state truthful and scrollable.
