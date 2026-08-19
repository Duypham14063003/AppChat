## 1. Investigation

- [x] 1.1 Reproduce or trace the remote typing/message paths that rebuild `ChatScreen` while the composer is focused.
- [x] 1.2 Identify whether focus is lost through parent outside-tap dismissal, message-list drag dismissal, composer subtree replacement, or send-state locking.

## 2. Core Implementation

- [x] 2.1 Scope chat-screen outside-tap dismissal so it only reacts to real local interactions outside the composer.
- [x] 2.2 Preserve existing message-list drag keyboard dismissal for intentional user scrolls.
- [x] 2.3 Ensure remote typing indicator appearance, update, and cleanup do not unfocus or disable `MessageInputBar`.
- [x] 2.4 Ensure remote message insertion and near-bottom auto-scroll do not unfocus, clear draft text, or disable `MessageInputBar`.
- [x] 2.5 Stabilize `MessageInputBar` identity/state across passive chat-screen rebuilds if the investigation shows it is being recreated.
- [x] 2.6 Confirm reply, edit, mention, emoji, attachment, voice, multiline, and send flows remain coherent after remote activity.

## 3. Tests

- [x] 3.1 Add widget/helper coverage for focused composer continuity when a remote typing indicator appears.
- [x] 3.2 Add widget/helper coverage for focused composer continuity when a remote typing indicator updates or expires.
- [x] 3.3 Add widget/helper coverage for focused composer continuity when a remote message arrives.
- [x] 3.4 Preserve or update tests for intentional outside-tap and message-list-drag keyboard dismissal.
- [x] 3.5 Add coverage that sending after remote activity uses the full draft text.

## 4. Verification

- [x] 4.1 Run targeted chat composer/chat screen tests.
- [x] 4.2 Run targeted Flutter analyze for changed chat files and tests.
- [ ] 4.3 Manually verify in Chrome or mobile: focus composer, have another user type/send in the same chat, continue composing and send.
