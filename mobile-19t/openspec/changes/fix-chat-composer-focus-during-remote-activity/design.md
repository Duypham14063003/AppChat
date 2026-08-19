## Context

`ChatScreen` owns the conversation layout and receives realtime updates from chat providers and WebSocket events. Remote typing events update `_typingUsers` and render `TypingIndicator` above `MessageInputBar`. Remote message events update `chatMessagesProvider`, which rebuilds the message list and can auto-scroll when the user is near the bottom.

`MessageInputBar` owns the composer `TextEditingController`, `FocusNode`, transient mention overlay, emoji panel, and send state. The chat screen also has outside-tap and message-list-drag dismissal behavior so users can intentionally dismiss the keyboard by interacting outside the composer.

The reported bug happens while another user is typing or sends a message in the same chat box. That points to remote UI churn affecting composer focus or input continuity. Realtime updates should never be treated as user outside-tap interactions, and layout changes around the typing indicator/message list should not prevent the local user from continuing to type.

## Goals / Non-Goals

**Goals:**
- Preserve composer focus when remote typing indicators appear, update, or expire.
- Preserve composer focus and draft text when remote messages arrive and the message list rebuilds or auto-scrolls.
- Preserve intentional keyboard dismissal when the local user taps outside the composer or drags the message list.
- Keep composer state coherent for mention, emoji, reply, edit, attachment, voice, multiline, and send flows.
- Add focused test coverage for remote typing/message activity while the composer is focused.

**Non-Goals:**
- Change WebSocket event schemas, backend message contracts, or typing payloads.
- Redesign the chat composer or typing indicator visuals.
- Remove outside-tap or drag-to-dismiss keyboard behavior.
- Change message ordering, read sync, pending resend, or notification behavior.

## Decisions

### D1: Treat remote activity as passive UI updates

**Decision:** Remote typing and remote message updates must only update passive UI state. They must not call focus dismissal paths, reset composer state, disable the text field, or rebuild the composer in a way that replaces its state.

**Why:** A local user composing a message has priority over passive realtime indicators. Chat apps commonly allow users to keep typing while other participants type or send messages.

**Alternatives considered:**
- Dismiss focus when a remote message arrives so users can read the latest content. Rejected because it interrupts active composition and matches the reported failure mode.
- Hide typing indicators while the local composer is focused. Rejected because presence awareness is useful and should be safe if rendered passively.

### D2: Keep outside-dismiss handlers scoped to real local pointer gestures

**Decision:** Preserve outside-tap and message-list-drag dismissal, but ensure they only run for actual local interactions outside the composer and not as a side effect of remote rebuilds or layout shifts.

**Why:** The previous keyboard-dismiss behavior is still valid. The bug is overreach or accidental triggering, not the existence of dismissal behavior itself.

**Alternatives considered:**
- Remove the chat-screen-level `GestureDetector` dismissal entirely. Rejected because it would regress expected outside-tap keyboard dismissal.
- Move all dismissal logic into `MessageInputBar`. Rejected because taps and drags in the message list live outside the composer subtree.

### D3: Stabilize the composer subtree across conversation UI rebuilds

**Decision:** Keep `MessageInputBar` state stable across typing indicator and message-list updates. If needed, use stable widget identity or structure so remote activity does not recreate the composer state object.

**Why:** The composer owns the draft text, focus node, and send lock. Recreating that state during remote activity can make the input appear cleared, unfocused, or disabled.

**Alternatives considered:**
- Lift composer controller/focus state into `ChatScreen`. Rejected for this bug because `MessageInputBar` already owns substantial composer behavior and moving ownership would broaden the change.

### D4: Add regression coverage around focus continuity

**Decision:** Add widget/helper tests that focus the composer, simulate remote typing/message-driven rebuild inputs, and verify typing can continue afterward.

**Why:** This class of bug is interaction-sensitive and easy to reintroduce when changing chat layout, typing indicator, or keyboard dismissal behavior.

**Alternatives considered:**
- Manual verification only. Rejected because future changes could reintroduce the regression without an obvious unit failure.

## Risks / Trade-offs

- [Risk] Narrowing dismissal behavior can regress keyboard dismissal from legitimate outside taps. -> Mitigation: keep existing outside-tap and drag-dismiss scenarios covered.
- [Risk] Remote message auto-scroll can still visually move content while composing. -> Mitigation: preserve focus and draft first; only adjust scroll behavior if it directly causes input interruption.
- [Risk] Web and mobile focus behavior can differ around pointer events. -> Mitigation: cover platform-neutral widget behavior and manually verify on Chrome and a mobile device.
- [Risk] Stabilizing widget identity may hide deeper rebuild issues. -> Mitigation: test actual user-visible behavior: focused composer accepts additional text after remote activity.

## Migration Plan

1. Identify the exact dismissal or rebuild path triggered by remote typing/message updates.
2. Scope focus dismissal so only real local outside-composer interactions clear focus.
3. Stabilize composer state across passive remote chat updates if the composer is being recreated.
4. Add tests for typing indicator appearance/expiry and remote message arrival while the composer is focused.
5. Re-run targeted chat tests and manually verify same-conversation remote typing and send flows.

Rollback: revert the interaction-layer changes in `ChatScreen` and `MessageInputBar`. No data migration is required.

## Open Questions

None. The expected behavior is clear: other participants typing or sending messages must not prevent the local user from continuing to compose.
