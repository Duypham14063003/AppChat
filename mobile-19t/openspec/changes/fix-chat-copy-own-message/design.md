## Context

The chat screen currently shows a message action menu through `showMessageContextMenu()` and performs the copy action directly in `ChatScreen` by writing `message.content` to the clipboard. At the same time, the chat UI supports encrypted and resolved message flows where the raw stored `LocalMessage.content` may be empty or placeholder-based while the user-facing text is reconstructed through `_resolveLocalMessageForUi()` and `EncryptedMessageAdapter.resolveLocalMessageForUi()`.

This mismatch creates a fragile copy path: the user can see readable text in the bubble, but copy eligibility and clipboard payload still depend on the raw persisted field. That especially affects self-sent text messages when plaintext was not persisted locally during encrypted send flows.

This change needs to preserve the current context-menu model, message-type restrictions, and recalled-message handling. The main correction is to make copy decisions use the same visible/resolved message text that the user sees in the chat room.

## Goals / Non-Goals

**Goals:**
- Make copy availability for text messages depend on visible/resolved text instead of only raw stored content.
- Ensure self-sent text messages remain copyable when displayed text was resolved from encrypted or transformed state.
- Keep recalled messages non-copyable.
- Keep non-text message types excluded from text-copy actions unless they already have a dedicated copy flow elsewhere.
- Add focused tests for copying self-sent resolved text.

**Non-Goals:**
- Adding copy actions for images, files, voice, or video messages.
- Changing chat encryption, persistence, or message rendering architecture beyond the copy source of truth.
- Changing clipboard behavior outside the message context menu flow.

## Decisions

### D1: Copy eligibility SHALL follow the message text currently visible to the user

**Decision:** The copy action will use a dedicated copyable-text helper derived from the resolved `LocalMessage` state already passed through the chat UI, rather than checking raw persisted content directly.

**Why:** The rendered chat bubble already represents the best user-visible message text after decryption and UI resolution. Using that same resolved state keeps copy behavior aligned with what the user actually sees.

**Alternatives considered:**
- Continue using `message.content` directly. Rejected because encrypted self-sent flows can leave the raw field empty even when visible text exists.
- Re-decrypt messages again only for copy. Rejected because the resolved message is already available in the room state and duplicating resolution logic would add risk and complexity.

### D2: Copy action rules stay narrow and explicit

**Decision:** Copy will remain limited to eligible text messages that are not recalled and that have a non-empty copyable display string.

**Why:** This preserves existing product boundaries while fixing the source-of-truth problem. The bug is not that copy supports too few types broadly; it is that eligible self-text messages are evaluated against the wrong field.

**Alternatives considered:**
- Expand copy to every message type during this fix. Rejected because it broadens scope beyond the reported bug.

### D3: Tests SHALL cover resolved self-message text, not only raw plaintext

**Decision:** Automated coverage will include a case where the displayed text for a self-sent message is available through resolved UI state while the raw persisted field is insufficient for direct copy checks.

**Why:** The regression risk is specifically in the gap between raw storage and visible text. A test that only uses raw plaintext would miss the bug.

**Alternatives considered:**
- Rely on manual copy verification only. Rejected because this bug lives in UI/state edge conditions that are easy to regress.

## Risks / Trade-offs

- [Risk] Copy helper may accidentally expose placeholder text instead of meaningful user text in unresolved encryption edge cases. -> Mitigation: keep eligibility tied to non-empty resolved display text and preserve current recalled-message exclusion.
- [Risk] Copy behavior could diverge between menu visibility and clipboard payload if two separate checks are kept. -> Mitigation: use one shared copyable-text source for both menu rendering and `Clipboard.setData`.
- [Risk] Tests may become tightly coupled to current message resolution plumbing. -> Mitigation: keep tests focused on externally visible copy behavior and the resolved message value passed into the screen/widget layer.

## Migration Plan

1. Introduce a single copyable-text decision path for chat message actions.
2. Update context-menu visibility and copy callback to use that resolved copyable text.
3. Add tests for self-sent messages with resolved visible text.
4. Manually verify copying own text message works again in the chat room.

Rollback: revert the copyable-text helper and restore the previous `message.content`-based checks if the new logic causes incorrect copy availability.

## Open Questions

None. The intended behavior is clear: if the user can see eligible text in their own message bubble, the copy action should be available and should copy that visible text.
