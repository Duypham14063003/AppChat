## Context

`ChatScreen` receives `conversationId` from router state and updates the visible conversation as users move between chat rooms. The screen rebuilds around provider data, typing indicators, and message list state, while `MessageInputBar` owns the local composer state such as draft text, mention metadata, link preview state, emoji visibility, and transient overlays.

The current bug indicates that conversation navigation can reuse the existing composer state instead of scoping it to the newly active room. As a result, unsent text from one conversation can appear in another conversation, which is incorrect even though reply, edit, send, and attachment flows still work within a single room.

## Goals / Non-Goals

**Goals:**
- Ensure composer draft state is scoped to the active `conversationId`.
- Clear transient composer state when the user switches to a different room.
- Preserve current composer behavior while remaining in the same conversation.
- Add regression coverage for entering text, switching rooms, and confirming the new room starts with a clean composer.

**Non-Goals:**
- Persist drafts per room across navigation.
- Change backend, WebSocket, or database behavior.
- Redesign the composer UI or alter existing send/reply/edit flows within one conversation.
- Change unrelated chat-screen navigation or realtime sync behavior.

## Decisions

### D1: Reset composer identity on conversation change

**Decision:** Tie the composer widget identity to `conversationId` so a room switch creates a fresh composer state instead of reusing the previous room's controller state.

**Why:** The bug comes from transient UI state surviving across conversation navigation. Resetting widget identity is the narrowest fix because it aligns the composer lifecycle with the active room boundary.

**Alternatives considered:**
- Add manual clearing logic only inside `MessageInputBar.didUpdateWidget`. Rejected as the sole fix because the widget does not currently receive `conversationId`, and partial resets are easy to miss when new transient state is added later.
- Lift all composer state into `ChatScreen` or a provider. Rejected because it broadens scope and introduces extra state coordination for a bug that only needs room-scoped lifecycle boundaries.

### D2: Treat room switch as a full transient-state reset boundary

**Decision:** When the active room changes, clear unsent text plus related transient state such as mention offsets, mention overlay, emoji visibility, link preview, loading preview state, and draft bookkeeping.

**Why:** A room switch changes the semantic ownership of the composer. Any transient state derived from the prior room becomes invalid and must not leak.

**Alternatives considered:**
- Clear text only. Rejected because stale mention metadata, overlay state, or preview state could remain inconsistent in the new room.
- Preserve transient state except for text. Rejected because the user expectation is a clean composer for the newly opened room.

### D3: Preserve same-room composer continuity

**Decision:** Keep the existing local composer state model for same-room activity, including edit-mode prefill, reply state, and send flow, and limit the reset behavior to true conversation changes.

**Why:** The reported bug is specifically cross-room leakage. Same-room lifecycle behavior already supports rich composer interactions and should not regress.

**Alternatives considered:**
- Reset composer more aggressively on any parent rebuild. Rejected because it would break typing continuity during normal message or typing updates.

### D4: Add navigation-focused composer regression tests

**Decision:** Add widget-level coverage that enters a draft, switches to another conversation context, and verifies the composer is empty and ready for new input.

**Why:** This bug is driven by widget lifecycle and route changes, so a regression test should validate user-visible behavior at the room boundary.

**Alternatives considered:**
- Manual QA only. Rejected because lifecycle regressions are easy to reintroduce during future chat-screen refactors.

## Risks / Trade-offs

- [Risk] Re-keying the composer could unintentionally reset state during flows that are not true room switches. -> Mitigation: bind the reset to `conversationId` only and verify same-room rebuild behavior stays intact.
- [Risk] Clearing the composer on room switch may hide a future requirement for per-room draft persistence. -> Mitigation: keep this change explicitly scoped to current behavior; draft persistence can be designed separately later.
- [Risk] Tests may not fully reproduce router behavior if they only rebuild widgets. -> Mitigation: cover both helper-level lifecycle expectations and a widget flow that changes conversation context.

## Migration Plan

1. Update the chat conversation screen/composer boundary so composer state is recreated or explicitly reset when `conversationId` changes.
2. Ensure all transient composer sub-state is cleared at the same boundary.
3. Add regression tests for draft entry followed by room switching.
4. Run targeted chat tests and verify switching rooms no longer carries over unsent text.

Rollback: revert the conversation-scoped composer reset and tests. No data migration is required.

## Open Questions

None. The expected behavior is clear: a different chat room must not inherit another room's unsent draft state.
