## 1. Notification Navigation Semantics

- [x] 1.1 Update notification tap handling so chat conversation destinations use push-style navigation instead of unconditional route replacement
- [x] 1.2 Keep non-chat notification destinations on their existing shell/root navigation behavior
- [x] 1.3 Guard chat notification re-entry behavior so repeated taps do not produce obviously broken navigation flow

## 2. Verification

- [x] 2.1 Extend notification routing tests to cover chat-entry navigation semantics, not just payload-to-route mapping
- [ ] 2.2 Manually verify chat notification entry from background and terminated mobile states shows a back affordance and returns to the app shell correctly
