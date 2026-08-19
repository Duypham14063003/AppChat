## Context

The mobile chat client renders message-level seen-by state from Riverpod `FutureProvider` snapshots backed by `GET /conversations/:convId/messages/:messageId/seen-by`. The current implementation fetches seen-by data when a message row or detail sheet needs it, but it does not invalidate those providers when read-receipt websocket activity changes. This causes visible seen-by avatars and the detail sheet to lag behind actual read progress while the conversation remains open.

The mobile app already participates in the read-receipt flow by sending `mark_read` over websocket when a conversation is actively viewed. The backend also emits read-receipt websocket activity, so the missing piece on mobile is listening for that activity and using it to refresh seen-by state.

## Goals / Non-Goals

**Goals:**
- Make visible seen-by markers update while the conversation remains open.
- Keep `GET /conversations/:convId/messages/:messageId/seen-by` as the source of truth for displayed readers.
- Ensure each reader avatar is shown only on the newest message they have read up to.
- Keep the currently signed-in account excluded from displayed seen-by avatars.
- Refresh the seen-by detail sheet from current backend state when opened.

**Non-Goals:**
- Redesign the backend seen-by API.
- Replace the existing read-receipt websocket protocol.
- Add persistent local storage for seen-by snapshots.
- Solve performance for arbitrarily large visible windows beyond the currently rendered message set.

## Decisions

### Use websocket read-receipt events as invalidation triggers

The mobile client will listen for read-receipt websocket events while a conversation is active. When a read event affects the currently open conversation, the client will invalidate the seen-by providers for that conversation so the next render refreshes from backend truth.

Why this approach:
- It preserves the existing backend contract and mobile repository API.
- It avoids inventing client-side seen inference from message ordering or timestamps.
- It provides realtime refresh semantics without polling.

Alternative considered:
- Poll `seen-by` on a timer. Rejected because it adds unnecessary HTTP load and still trails websocket activity.

### Keep seen-by data fetch-on-demand, but centralize invalidation

The design keeps the existing `getMessageSeenBy(convId, messageId)` repository method and provider pattern. The change focuses on invalidation rules rather than replacing the data source.

Why this approach:
- It minimizes scope and keeps detail-sheet behavior aligned with message-row behavior.
- It avoids a larger redesign to conversation-level read-state modeling in this change.

Alternative considered:
- Replace per-message seen-by fetching with a conversation-level read-state model. Rejected for this change because it would require a broader contract and data-shaping redesign.

### Recompute message-to-reader placement from refreshed provider results

The conversation-level placement provider will continue mapping readers to the newest visible message they have read up to. After invalidation, it will rebuild from fresh seen-by API responses and reassign each user to exactly one message.

Why this approach:
- It matches the intended UX where each member appears only once at the latest message they have read.
- It keeps placement logic deterministic and local to the active message window.

Alternative considered:
- Show the same reader on every message returned by seen-by. Rejected because it creates noisy duplicate avatar rows.

## Risks / Trade-offs

- **[Higher refresh fan-out for visible messages]** → Invalidation may trigger multiple seen-by refetches for the visible message window; mitigate by invalidating only for the active conversation and reusing the existing placement provider boundary.
- **[Event coverage mismatch]** → If the mobile client listens to the wrong websocket event name or payload shape, realtime refresh will still lag; mitigate by wiring invalidation to the exact read-receipt event already emitted by the backend contract used in production.
- **[Transient stale UI during refetch]** → Seen-by rows may disappear briefly during provider refresh; mitigate by keeping provider lifecycle scoped to the open screen and avoiding unnecessary invalidations outside the active conversation.
- **[Visible-window limitation]** → Placement is only computed for messages currently available in the client window; mitigate by accepting this as current-scope behavior and keeping older unloaded history out of scope.

## Migration Plan

1. Add websocket read-receipt listening on the mobile chat state layer.
2. Invalidate seen-by providers for the active conversation when relevant read events arrive.
3. Update seen-by rendering to rely on refreshed provider output without changing the seen-by API contract.
4. Verify behavior by opening the same conversation on multiple clients and confirming seen-by rows and detail sheets update without leaving the screen.

Rollback strategy:
- Remove the websocket-driven invalidation and fall back to the current snapshot-only behavior if the refresh logic introduces instability.

## Open Questions

- Does production backend emit a dedicated `message_read` websocket event to mobile clients with stable payload fields for `conv_id`, `user_id`, and `message_id`?
- Should seen-by detail sheets auto-refresh while already open, or is refresh-on-open sufficient for this change?
- Do we need debounce or coalescing if multiple readers mark the same conversation as read in rapid succession?
