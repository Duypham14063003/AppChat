## Context

The chat composer is implemented in `MessageInputBar`. It uses a multiline `TextField` with `maxLines: 4` and `minLines: 1`. On mobile, the field uses `TextInputAction.newline`, so multiline composition works through the platform keyboard.

On web, `MessageInputBar` assigns `_focusNode.onKeyEvent` to intercept keyboard input. The current handler sends the message for Enter without Shift and returns `KeyEventResult.ignored` for Shift+Enter, expecting the `TextField` to insert the newline itself. In Flutter Web, this is unreliable because the focus-level key handler can prevent the browser/text-input path from producing the newline. The result is that Shift+Enter does not visibly create a new line in Chrome/web.

The widget already has `_insertTextAtCursor`, which updates the controller text, cursor selection, `_hasText`, link detection, mention offsets, previous text tracking, and mention detection after text insertion. Reusing that path for newline insertion keeps composer state coherent.

When the composer reaches its visible multiline height, programmatic newline insertion must also keep the text viewport aligned with the caret. Otherwise the newline is inserted correctly but the user cannot see the new line until manually scrolling inside the field.

The same internal text viewport must recover when text shrinks or is cleared. After many line breaks, keyboard deletion or select-all deletion can leave the internal scroll offset pointing at empty lower space unless the composer resets the offset for empty text.

## Goals / Non-Goals

**Goals:**
- Make Shift+Enter insert a newline in the web chat composer.
- Preserve Enter without Shift as the web shortcut for sending the current message.
- Preserve mobile multiline input behavior.
- Keep mention detection, link preview detection, typing state, and send-button state coherent after newline insertion.
- Keep the web composer scrolled to the active caret when Shift+Enter creates a new line beyond the visible text area.
- Reset the internal text-field scroll position when multiline content is cleared, so deletion and select-all deletion visibly return to the empty composer state.
- Add focused widget tests around composer keyboard behavior and multi-line send content.

**Non-Goals:**
- Redesign the composer UI or change its visual layout.
- Change message rendering, storage, or backend payload contracts.
- Add a user preference for keyboard shortcuts.
- Change attachment, emoji, voice recording, paste-image, or link-preview behavior beyond preserving existing composer state.

## Decisions

### D1: Explicitly insert newline for web Shift+Enter

**Decision:** In the web key handler, handle `KeyDownEvent` for Enter with Shift by inserting `\n` at the current selection/cursor and returning `KeyEventResult.handled`.

**Why:** This removes reliance on Flutter Web/browser default newline behavior after a focus-level key handler has already seen the event. It also mirrors expected desktop chat behavior.

**Alternatives considered:**
- Continue returning `ignored` for Shift+Enter. Rejected because this is the observed bug path.
- Use `onSubmitted` or `TextInputAction` to model both send and newline. Rejected because web desktop shortcuts require differentiating Enter from Shift+Enter, and the existing focus key handler already owns Enter-to-send.

### D2: Reuse `_insertTextAtCursor` for newline insertion

**Decision:** Use the existing text insertion helper instead of directly editing the controller inside the key handler.

**Why:** The helper already performs cursor-safe replacement and updates composer-derived state. Reusing it avoids drift between paste behavior and keyboard newline behavior.

**Alternatives considered:**
- Directly append `\n` to `_controller.text`. Rejected because it would ignore selection replacement and could skip mention/link state updates.

### D3: Keep mobile path unchanged

**Decision:** Keep the web-specific key handling gated by `kIsWeb`, and keep mobile `TextInputAction.newline` behavior as-is.

**Why:** The reported bug is web-only and mobile already works. Avoiding mobile keyboard changes reduces regression risk.

**Alternatives considered:**
- Apply the same focus key handler on all platforms. Rejected because mobile virtual keyboard behavior is different and already correct.

### D4: Attach a text-field scroll controller for programmatic caret visibility

**Decision:** Give the composer `TextField` a `ScrollController` and, after programmatic insertion at the end of the current text, scroll to the bottom after layout.

**Why:** Flutter Web does not always auto-scroll the inner text viewport after controller-driven text insertion. A focused scroll adjustment keeps the visible composer aligned with the blinking caret when the input has reached its maximum visible line count.

**Alternatives considered:**
- Rely on default `EditableText` scrolling. Rejected because the observed bug is that default scrolling does not happen for this programmatic Shift+Enter path.
- Increase `maxLines` or resize the composer indefinitely. Rejected because it changes the composer layout rather than fixing caret visibility inside the existing field.

### D5: Reset the text-field viewport when content becomes empty

**Decision:** After text changes, if composer text becomes empty, reset the field scroll controller to offset zero after layout.

**Why:** Clearing a long multiline draft should make the empty composer and placeholder visible immediately. Without resetting the offset, the user can remain scrolled to blank lower space and perceive deletion as broken.

**Alternatives considered:**
- Reset only after programmatic newline insertion. Rejected because the clear/delete path is driven by normal text input changes, not the explicit insertion helper.

## Risks / Trade-offs

- [Risk] Tests that simulate hardware keyboard events may not perfectly match browser event delivery. -> Mitigation: test the helper-visible behavior through widget text state and send callback, and manually verify in Chrome.
- [Risk] Newline insertion may affect mention query offsets. -> Mitigation: route insertion through `_insertTextAtCursor`, which already recalculates mention offsets.
- [Risk] Enter-to-send could regress while fixing Shift+Enter. -> Mitigation: add tests covering both Enter and Shift+Enter paths.

## Migration Plan

1. Update the web key handler in `MessageInputBar` to explicitly handle Shift+Enter as newline insertion.
2. Keep Enter without Shift mapped to `_send()` and leave non-web behavior unchanged.
3. Add focused tests for Shift+Enter newline insertion, Enter send behavior, and multi-line message content.
4. Run the relevant Flutter tests for the composer.

Rollback: revert the key handler change and tests if an unexpected browser regression appears. No data migration is required.

## Open Questions

None. The desired behavior is standard desktop chat behavior: Enter sends, Shift+Enter inserts a line break.
