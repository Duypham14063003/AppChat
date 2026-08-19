## 1. Composer lifecycle

- [x] 1.1 Trace the conversation-switch path between `ChatScreen` and `MessageInputBar` and confirm where prior-room composer state is reused.
- [x] 1.2 Bind composer reset behavior to `conversationId` changes so a different room gets a fresh transient composer state.
- [x] 1.3 Ensure unsent text, mention state, link preview state, emoji state, and overlay state are all cleared at the same room-switch boundary.

## 2. Same-room behavior protection

- [x] 2.1 Preserve current composer continuity for same-conversation rebuilds, including draft text, reply state, and edit state.
- [x] 2.2 Verify send, attachment, multiline, mention, and emoji flows still behave correctly after the room-switch reset change.

## 3. Regression coverage

- [x] 3.1 Add widget/helper coverage for typing a draft in one conversation, switching to another conversation, and confirming the new room starts with a clean composer.
- [x] 3.2 Add or update coverage that same-room rebuilds still preserve the active draft and composer context.
- [x] 3.3 Run targeted chat tests and Flutter analysis for the changed chat composer files.
