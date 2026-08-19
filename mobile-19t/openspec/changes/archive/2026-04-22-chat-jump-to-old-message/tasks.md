## 1. Shared Historical Jump Flow

- [x] 1.1 Add a shared chat-screen helper that checks whether a target message is already loaded, then paginates older history until the target is found or no additional messages are returned
- [x] 1.2 Add in-flight loading and final exhausted-history feedback so message-jump requests no longer fail immediately with the out-of-range snackbar
- [x] 1.3 Route pinned-message taps, bookmarked-message taps, reply navigation, and `initialMessageId` handling through the shared historical jump helper

## 2. Verification

- [x] 2.1 Add mobile tests that cover finding a target after one or more `loadMore()` calls and reporting failure only after history exhaustion
- [ ] 2.2 Manually verify pinned, bookmarked, reply, and deep-link jumps to older messages in a long conversation
