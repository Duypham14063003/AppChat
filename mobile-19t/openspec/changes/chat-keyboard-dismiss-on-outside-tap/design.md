## Context

`ChatScreen` renders a message list, app bar actions, and `MessageInputBar` at the bottom. The input bar owns a `FocusNode` for the composer `TextField`, mention overlay state, and emoji panel state.

Current behavior focuses the composer correctly but does not define a full-screen outside-tap dismissal path. As a result:
- tapping empty message area may not remove input focus
- keyboard can stay visible while the user is trying to read messages
- mention/emoji UI can remain active longer than intended after focus context changes

The fix should stay scoped to interaction handling and avoid changing message transport, read sync, or chat business logic.

## Goals / Non-Goals

**Goals:**
- Dismiss keyboard when the user taps outside the chat composer.
- Dismiss keyboard when the user drags the message list to browse history.
- Keep composer state coherent (focus, mention overlay, emoji panel) after dismissal.
- Preserve current send, edit, reply, and attachment behavior.
- Add coverage for keyboard-dismiss behavior to prevent regressions.

**Non-Goals:**
- Redesign the chat screen layout or composer visual style.
- Change message sending, WebSocket, or unread-state logic.
- Introduce platform-specific custom keyboard channels.

## Decisions

### D1: Add explicit outside-tap focus dismissal in chat screen interaction surfaces

**Decision:** Add a chat-screen-level dismissal path so taps in non-composer areas trigger `unfocus()` for the current primary focus.

**Why:** Input focus should not rely only on keyboard/system back actions. A direct outside-tap path matches expected chat UX.

**Alternatives considered:**
- Composer-only dismissal logic inside `TextField` events. Rejected because many taps happen outside composer subtree.
- No tap-dismiss, rely only on scroll/back gestures. Rejected due to poor discoverability and user friction.

### D2: Add `TextField` outside-tap handling as composer-local fallback

**Decision:** Add an input-level outside-tap dismissal fallback in `MessageInputBar` so focus can still clear when the tap path is resolved near input boundaries.

**Why:** Screen-level and input-level handling together are more robust across platform hit-testing differences.

**Alternatives considered:**
- Screen-level only. Rejected because nested overlays and focus transitions can still miss edge taps.

### D3: Dismiss keyboard on message-list drag

**Decision:** Configure message-list interaction to dismiss keyboard when users drag/scroll through messages.

**Why:** This is a common mobile chat behavior and naturally aligns with the user intent to read history.

**Alternatives considered:**
- Keep drag behavior unchanged. Rejected because keyboard can continue obscuring content during browse gestures.

### D4: Keep focus-linked overlay state coherent

**Decision:** When composer focus is dismissed, related transient UI (mention suggestion overlay and emoji panel when appropriate) should converge to a consistent inactive state.

**Why:** Prevents partial states where keyboard is hidden but mention/emoji affordances remain unexpectedly active.

**Alternatives considered:**
- Manage only keyboard visibility and ignore overlay state. Rejected due to inconsistent composer UX.

### D5: Add focused regression tests for interaction behavior

**Decision:** Add widget tests for outside tap and drag-dismiss behavior in chat input flow.

**Why:** Interaction regressions are easy to reintroduce; tests protect expected behavior as chat UI evolves.

## Risks / Trade-offs

- [Risk] New tap handlers could interfere with existing message-item tap/long-press gestures.
  Mitigation: scope dismissal handlers to non-conflicting areas and verify message actions still work.
- [Risk] Desktop/web pointer behavior may differ from mobile expectations.
  Mitigation: keep behavior platform-safe and validate only intended mobile-first paths for this change.
- [Risk] Over-aggressive dismissal could collapse emoji/mention UI unexpectedly.
  Mitigation: tie dismissal rules to explicit outside-input interactions and verify editing/reply flows.

## Migration Plan

1. Introduce keyboard-dismiss interaction handling in `ChatScreen` and `MessageInputBar`.
2. Ensure mention/emoji state converges correctly after focus dismissal.
3. Add/update chat widget tests for outside-tap and drag-dismiss behavior.
4. Run manual verification on representative mobile layouts.

Rollback is low risk: revert interaction-layer changes in chat screen/input widgets without impacting persistence or transport contracts.

## Open Questions

None. Scope and expected behavior are clear from the reported UX issue.
