## 1. Composer Keyboard Behavior

- [x] 1.1 Update the web `MessageInputBar` key handler so Shift+Enter inserts `\n` at the current cursor or selection.
- [x] 1.2 Preserve Enter without Shift as the web send shortcut.
- [x] 1.3 Keep non-web multiline input behavior unchanged.
- [x] 1.4 Route newline insertion through the existing text insertion path so composer text-derived state remains coherent.
- [x] 1.5 Keep the composer text viewport scrolled to the caret after programmatic newline insertion at the bottom of a full multiline field.
- [x] 1.6 Reset the composer text viewport when multiline content is cleared so deletion and select-all deletion visibly return to the empty state.

## 2. Tests

- [x] 2.1 Add focused composer tests proving Shift+Enter inserts a newline and does not send.
- [x] 2.2 Add coverage proving Enter without Shift still sends a non-empty message.
- [x] 2.3 Add coverage proving multiline sent content preserves inserted line breaks.
- [x] 2.4 Verify empty or whitespace-only Enter does not send.

## 3. Verification

- [x] 3.1 Run the relevant Flutter test file(s) for `MessageInputBar`.
- [x] 3.2 Run targeted Flutter analysis for the changed composer and test files.
- [ ] 3.3 Manually verify on Chrome/web: type text in chat, press Shift+Enter, confirm a new line appears; press Enter without Shift, confirm the message sends.
