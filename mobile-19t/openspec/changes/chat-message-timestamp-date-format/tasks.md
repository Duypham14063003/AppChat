## 1. Bubble Timestamp Formatting

- [x] 1.1 Replace the fixed `HH:mm` bubble formatter with a contextual formatter that includes date information for messages not sent today
- [x] 1.2 Ensure the shared bubble timestamp formatter is used consistently across text, media, and voice message timestamp rows

## 2. Verification

- [x] 2.1 Add tests for same-day, previous-day, and previous-year bubble timestamp outputs
- [ ] 2.2 Manually verify older chat messages display date-plus-time without breaking bubble layout
