## 1. Foreground notification policy

- [x] 1.1 Add a route-aware helper that can determine whether an incoming chat notification matches the currently open conversation.
- [x] 1.2 Define a chat-only foreground notification decision path that suppresses alerts for the active conversation and preserves existing behavior for non-chat notifications.

## 2. Mobile notification integration

- [x] 2.1 Wire the foreground chat notification policy into the app-level notification handling flow so chat alerts can be shown while the app is open.
- [x] 2.2 Reuse current route or selected conversation context from the router/shell so the suppression logic works for exact conversation matches.
- [x] 2.3 Ensure the foreground chat alert path does not break notification tap routing or existing background notification behavior.

## 3. Verification

- [x] 3.1 Add tests for same-conversation suppression, different-conversation foreground alerts, and non-chat notification passthrough.
- [ ] 3.2 Manually verify foreground behavior while viewing the same chat, a different chat, and a non-chat screen.
