## 1. Search Navigation State

- [x] 1.1 Refactor in-chat search state so the displayed match list and counter represent only matches currently navigable in the loaded conversation timeline
- [x] 1.2 Ensure initial query submission auto-scrolls to the first navigable match and that next/previous actions use the same filtered result set
- [x] 1.3 Preserve local/server search discovery without counting unreachable hits as current navigable matches

## 2. Verification

- [x] 2.1 Add mobile tests for auto-scroll-to-first-match, next/previous navigation, and counter consistency when raw hits include unavailable messages
- [ ] 2.2 Manually verify search in a long conversation where some matches are loaded and others are outside the current timeline window
