## Context

The mobile chat screen uses a reversed `ScrollablePositionedList` and already renders a downward floating action button that jumps back to index `0`, which represents the latest messages in the conversation. However, the current visibility logic is attached to message-count changes from the provider listener, so the button appears only after new messages arrive or pagination loads older history.

This creates a UX gap for normal reading behavior: when a user scrolls upward through older messages, there is no immediate affordance to return to the bottom until a separate data event happens. The change is local to Flutter chat UI behavior, but the reversed list and pagination threshold make the implementation slightly tricky because the same position listener currently drives both "load more" and "hide at bottom" behavior.

## Goals / Non-Goals

**Goals:**
- Show the scroll-to-bottom FAB as soon as the user has moved meaningfully away from the latest messages.
- Keep the FAB hidden while the user is already at or near the bottom.
- Preserve the existing tap action that scrolls back to the latest messages.
- Avoid coupling FAB visibility to pagination or new-message arrival side effects.
- Add verification coverage for the chosen visibility threshold in the reversed list.

**Non-Goals:**
- Redesign the FAB visual style, placement, or iconography.
- Change pagination behavior or message loading strategy beyond what is needed for visibility logic.
- Add unread-message counts or badges to the FAB in this change.
- Introduce backend, API, or websocket changes.

## Decisions

### D1: Drive FAB visibility from scroll position snapshots

**Decision:** Use `ItemPositionsListener` snapshots to determine whether the user is away from the bottom, and update `_showNewMessageFab` directly from that scroll-position state.

**Why:** The real user intent is tied to where they are in the timeline, not whether the message array length changed. The scroll listener already exists and is the most direct source of truth.

**Alternatives considered:**
- Keep visibility in the provider listener and try to infer scroll intent from list growth. Rejected because it preserves the current bug.
- Add a separate `ScrollController`. Rejected because `ScrollablePositionedList` already uses position listeners and adding another mechanism increases coordination complexity.

### D2: Use a small distance threshold instead of a strict "not at bottom" check

**Decision:** Show the FAB only after the user has moved beyond a small threshold from the bottom, rather than the first frame where index `0` is partially off screen.

**Why:** A threshold prevents the button from flickering when keyboard changes, small layout shifts, or tiny finger movements briefly move the newest item. It also better matches the expected behavior shown in the reference UI, where the FAB appears after a clear upward scroll.

**Alternatives considered:**
- Show the FAB immediately when index `0` is no longer visible. Rejected because it is too sensitive.
- Show the FAB only after pagination begins. Rejected because that is the current broken behavior.

### D3: Keep new-message auto-scroll semantics separate from manual scroll affordance

**Decision:** Continue using the provider listener for auto-scroll-on-new-message when the user is at the bottom, but remove FAB visibility as a side effect of `nextCount > prevCount`.

**Why:** Auto-scroll for new incoming messages is still valid behavior, but it should not be responsible for the manual "jump to latest" affordance.

**Alternatives considered:**
- Move all new-message handling into the scroll listener. Rejected because message arrival still needs data-driven behavior.
- Disable auto-scroll entirely once FAB logic changes. Rejected because it would regress normal live-chat behavior.

## Risks / Trade-offs

- [Risk] Threshold tuning may feel too eager or too late on different chat densities. → Mitigation: choose a simple item-index or viewport-based threshold and cover it with widget tests around representative scroll states.
- [Risk] Reversed-list math can be misread, causing the FAB to stay visible at the bottom. → Mitigation: define the threshold in terms of visible item positions and explicitly test bottom, near-bottom, and away-from-bottom cases.
- [Risk] Updating FAB visibility from every position change could increase rebuild frequency. → Mitigation: only call `setState` when the computed visibility actually changes.

## Migration Plan

1. Update chat-screen scroll-position handling to compute a deterministic "away from bottom" state.
2. Keep existing bottom-jump tap behavior and auto-hide logic aligned with the new state computation.
3. Remove the provider-listener branch that shows the FAB only when message count increases while away from bottom.
4. Add mobile tests that cover bottom, near-bottom, and past-threshold states.
5. Manually verify behavior in a long conversation with and without pagination.

**Rollback:** Revert the chat-screen visibility logic to the previous count-based implementation if the new threshold causes severe regressions, though that would restore the current UX gap.

## Open Questions

None. The feature scope is limited to making the existing affordance appear at the correct time.
