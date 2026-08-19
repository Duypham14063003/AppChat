## 1. Chat Screen Dismiss Interaction

- [x] 1.1 Add conversation-screen outside-tap handling so tapping non-composer areas dismisses active input focus.
- [x] 1.2 Update message-list interaction to dismiss keyboard on drag/scroll while preserving existing message item tap/long-press behavior.
- [x] 1.3 Verify chat app-bar and non-input chrome taps do not leave stale composer focus.

## 2. Composer Focus and Overlay Coherence

- [x] 2.1 Add composer-level outside-tap fallback handling in `MessageInputBar` to clear focus reliably.
- [x] 2.2 Ensure mention suggestion overlay and emoji-related transient states converge correctly after focus dismissal.
- [x] 2.3 Confirm send/edit/reply flows still behave correctly after focus is dismissed and re-acquired.

## 3. Verification

- [x] 3.1 Add/update widget tests for chat keyboard dismissal on outside tap and message-list drag.
- [x] 3.2 Add/update focused tests validating mention/emoji/input state coherence after dismissal and re-focus.
- [ ] 3.3 Manually verify on mobile: open keyboard, tap outside, drag list, re-focus composer, send/edit flows remain intact.
