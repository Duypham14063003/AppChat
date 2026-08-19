## 1. Backend Badge Payload

- [x] 1.1 Replace the hardcoded chat push badge value with a computed unread total for the recipient user
- [x] 1.2 Include the computed unread total in chat push data payloads as `badge_count`
- [x] 1.3 Add backend tests for unread-total badge payload generation

## 2. Mobile Badge Sync

- [x] 2.1 Add mobile badge handling that applies the unread total from notification/sync flows to the app icon badge
- [x] 2.2 Update chat read/open flows so badge count is recalculated or cleared when unread state changes
- [x] 2.3 Ensure badge resets to `0` only when unread chat total is actually zero

## 3. Verification

- [x] 3.1 Add mobile tests for badge update and badge-clear behavior where feasible
- [ ] 3.2 Manually verify on mobile: multiple unread notifications increase the badge above `1`, and reading all unread chats clears the badge back to `0`
