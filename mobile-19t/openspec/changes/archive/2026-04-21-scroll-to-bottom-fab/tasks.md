## 1. Chat Scroll Visibility Logic

- [x] 1.1 Refactor chat-screen FAB visibility to derive from `ItemPositionsListener` scroll position instead of message-count changes
- [x] 1.2 Add a stable bottom-distance threshold so the FAB appears only after a meaningful upward scroll and hides again near the bottom
- [x] 1.3 Preserve existing bottom-jump tap behavior and auto-scroll-on-new-message behavior while removing the count-based visibility side effect

## 2. Verification

- [x] 2.1 Add mobile tests for bottom, near-bottom, and away-from-bottom FAB visibility states
- [ ] 2.2 Manually verify the FAB appears before pagination starts, stays hidden on initial open, and disappears after jumping back to the latest messages
