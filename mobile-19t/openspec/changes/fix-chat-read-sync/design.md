## Context

The mobile chat flow maintains conversation-list state and conversation-detail state through separate async notifiers. The list can update from websocket preview data and API conversation refreshes, while the detail view depends on its own provider lifecycle, local message cache, and background API refresh. Read state is also handled optimistically in local storage before the server has necessarily reconciled `mark_read`.

This split creates two visible failure modes:
- the conversation list can show a new preview while the opened conversation still renders a stale message set
- unread badges can remain visible after a user opens a conversation because local resets are overwritten by later API refreshes or the read event is never reconciled back into the list state

After the initial read-sync implementation, a regression was identified: unread badges can disappear even when messages are still unread. Investigation shows a local force-read heuristic in the chat list refresh path can override server unread counters with `0` based on local timestamps (`lastViewedAt` versus `last_message_at`). This heuristic is too broad and can suppress valid unread state when local and server clocks/order diverge, or when optimistic/local timestamps do not match authoritative server ordering.

The change needs to keep the current architecture, avoid a large chat rewrite, and tighten synchronization between websocket events, cache updates, and read-state refresh.

## Goals / Non-Goals

**Goals:**
- Ensure opening a conversation refreshes message state strongly enough that newly arrived messages are visible immediately.
- Ensure unread and unread-mention badges clear once the conversation has been viewed and the latest visible message has been marked read.
- Keep conversation-list preview, unread counters, and conversation-detail messages aligned after websocket and API updates.
- Preserve current local-cache-first behavior and existing websocket transport.
- Prevent unread badge suppression for conversations that are not actively confirmed as read.
- Keep server unread counters authoritative unless the client has a clearly scoped and valid read confirmation for that conversation.

**Non-Goals:**
- Replacing the current chat architecture with a new global state model.
- Changing backend websocket contracts unless the existing client flow proves insufficient.
- Redesigning search, reactions, pinned messages, or media upload behavior outside the read-sync path.

## Decisions

### Decision: Treat conversation entry as an explicit synchronization point

When a user enters a conversation, the client should not rely only on a previously built provider instance. The conversation-detail flow should perform an explicit sync step that refreshes the message source of truth for that conversation and then derives the visible state from it.

Why this over the status quo:
- The current provider lifecycle can reuse stale state when re-entering a previously opened conversation.
- A guaranteed on-entry sync is the most direct fix for “preview exists but message not visible.”

Alternatives considered:
- Rely only on websocket `new_message` persistence. Rejected because missed events, stale provider instances, and background timing still leave gaps.
- Invalidate every chat provider on every list change. Rejected because it is noisy and broad for a conversation-scoped bug.

### Decision: Use the local database as the durable source of truth for visible messages, but require reconciliation on entry and after inbound events

The UI should continue reading from local persistence, but message refresh must ensure the database is brought current before the screen settles. Inbound websocket messages must also continue to persist to the database before the list/detail state is considered updated.

Why this over rendering directly from API responses:
- The codebase already uses local persistence for pagination, search, and offline behavior.
- Staying database-backed reduces churn and avoids introducing a second rendering model.

Alternatives considered:
- Render directly from API response and bypass local persistence during refresh. Rejected because it weakens offline support and increases state divergence.

### Decision: Read-state completion must include server reconciliation, not only local optimistic reset

Opening a conversation may clear local unread state immediately for responsiveness, but the client must also reconcile with authoritative state after `mark_read` is sent. The list state should not remain dependent on a potentially stale API response that can reintroduce unread counters.

Why this over local-only resets:
- The bug demonstrates that optimistic local reset alone is not durable.
- Read-state is shared between multiple views, so it must converge on one authoritative value.

Alternatives considered:
- Delay all local unread clearing until server confirmation. Rejected because it makes the UI feel laggy.
- Never refresh list state after local unread reset. Rejected because that leaves the app vulnerable to server/client drift.

### Decision: Scope the fix to message visibility and unread synchronization only

This change will target provider invalidation/refresh timing, unread reconciliation, and cache/list coordination. It will not change unrelated chat capabilities.

Why this scope:
- The user-reported bug is precise.
- A tight scope keeps the fix implementable and testable without expanding into broader chat refactors.

### Decision: Do not apply global timestamp-based force-read overrides to conversation list data

Conversation list refresh should not zero unread counters for arbitrary conversations based only on local timestamp comparison. Server unread counters remain authoritative unless the conversation has an explicit, scoped read-confirmation state that is safe to apply.

Why this over the current heuristic:
- Local timestamp comparisons can be invalid under clock skew, optimistic writes, and cross-device activity.
- Unread badge correctness is more important than aggressively hiding counters.

Alternatives considered:
- Keep global force-read and tweak thresholds. Rejected because threshold tuning does not fix authority/source-of-truth ambiguity.
- Remove all local read assistance. Rejected because local responsiveness on the currently viewed conversation is still needed.

### Decision: Restrict local read-clearing to the active viewed conversation context

Local unread clearing logic should apply only when the user has actively viewed a specific conversation and the client can tie that action to a concrete read checkpoint (message id/timestamp) for that same conversation.

Why this over broad local overrides:
- It preserves responsive UX where the user is currently reading.
- It avoids collateral unread resets in conversations the user has not opened.

Alternatives considered:
- Apply one global watermark across all conversations. Rejected because read state is conversation-scoped.

### Decision: Inbound message handling should preserve unread signal until authoritative read reconciliation

When `new_message` arrives for a conversation that is not being actively viewed, conversation-list state should keep or increase unread signal locally, and only clear after valid read reconciliation.

Why this matters:
- Users rely on badge presence before the next full list refresh.
- Prevents temporary zero-badge states that reduce trust in chat list indicators.

## Risks / Trade-offs

- [Provider invalidation introduces extra fetches] → Mitigation: keep refresh conversation-scoped and reuse local cache for initial render.
- [Server read-state may still lag after `mark_read`] → Mitigation: define a bounded reconciliation step after entry and after refresh, with deterministic local fallback behavior.
- [Websocket and API ordering may produce duplicate or out-of-order updates] → Mitigation: continue persisting messages idempotently by message ID and reload visible state from the database.
- [Fixing unread logic in one path but not another could leave edge cases] → Mitigation: apply the same read-sync rules to both initial conversation entry and later inbound-message handling while the conversation is open.
- [Removing force-read may temporarily show stale unread counters] → Mitigation: keep scoped read reconciliation for the actively viewed conversation and refresh list state after `mark_read`.
- [Local unread increments could race with API refresh] → Mitigation: keep updates idempotent and favor server values on authoritative refresh unless an active scoped read checkpoint applies.

## Migration Plan

No schema or user-facing migration is required. Deploy behind the existing chat entry flow, then verify:
- entering a conversation after receiving a new message shows that message
- unread and unread-mention badges clear after viewing the conversation
- websocket inbound messages continue to appear without duplicate rendering
- unread badges remain visible for inactive conversations with server-reported unread messages
- local timestamp skew or optimistic message timing does not incorrectly suppress unread counters

Rollback is a standard client rollback to the prior mobile build if the synchronization changes regress chat responsiveness.

## Open Questions

None. The follow-up scope is fixed: restore unread badge correctness by narrowing local read overrides and preserving server authority for inactive conversations.
