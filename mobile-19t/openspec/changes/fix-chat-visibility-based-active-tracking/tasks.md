## 1. Active-view signal

- [x] 1.1 Add a visibility-aware active chat tracking model that distinguishes foreground-visible chat routes from merely mounted chat screens.
- [x] 1.2 Integrate chat route visibility updates with the current router/navigation flow so switching branches or leaving the chat route demotes the active conversation immediately.
- [x] 1.3 Include app lifecycle foreground/background state in the active chat signal used by mobile chat.

## 2. Read-receipt gating

- [x] 2.1 Refactor automatic read handling to use the new visibility/route-based active-view gate instead of relying on `dispose()` timing.
- [x] 2.2 Ensure every automatic `mark_read` path, including open synchronization, inbound message handling, and refresh reconciliation, uses the same gate.
- [x] 2.3 Preserve existing auto-read behavior for conversations that are truly visible and foregrounded.

## 3. Regression coverage

- [ ] 3.1 Verify a preserved chat screen inside `StatefulShellRoute.indexedStack` no longer auto-sees messages after the user switches away from it.
- [ ] 3.2 Verify returning to a previously preserved chat route restores normal auto-read behavior.
- [ ] 3.3 Verify backgrounded app state does not continue auto-sending `mark_read` for the last open conversation.
- [x] 3.4 Run relevant mobile chat analysis and regression checks.
