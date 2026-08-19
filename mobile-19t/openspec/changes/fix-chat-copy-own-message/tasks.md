## 1. Copyable Text Source

- [x] 1.1 Introduce a single chat message helper or flow that derives copyable text from the resolved message state shown to the user.
- [x] 1.2 Keep recalled and non-text messages excluded from the text-copy action path.

## 2. Chat Action Integration

- [x] 2.1 Update message context-menu visibility so `Sao chép` uses the resolved copyable text instead of raw stored content checks.
- [x] 2.2 Update the chat copy callback so clipboard content matches the visible resolved text for eligible self-sent messages.

## 3. Verification

- [x] 3.1 Add automated coverage for a self-sent text message whose visible text is available through resolved UI state while raw stored content is insufficient.
- [ ] 3.2 Manually verify that copying your own visible text message works from the chat room context menu.
