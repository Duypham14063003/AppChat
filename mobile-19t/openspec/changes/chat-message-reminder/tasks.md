## 1. Backend reminder model and scheduling

- [ ] 1.1 Add the chat reminder entity, migration, and persistence rules for audience scope, lifecycle status, and duplicate prevention.
- [ ] 1.2 Implement delayed reminder scheduling and idempotent firing logic for pending reminders.

## 2. Backend APIs and chat event integration

- [ ] 2.1 Add create, update, and cancel reminder APIs with validation and creator ownership checks.
- [ ] 2.2 Reuse the chat message pipeline to emit system messages for reminder created, updated, cancelled, and fired events.
- [ ] 2.3 Send reminder push notifications to the correct recipients based on `self` versus `everyone` scope.

## 3. Mobile chat reminder UX

- [ ] 3.1 Add a “Nhắc hẹn” action to the existing message long-press menu for normal chat messages.
- [ ] 3.2 Implement reminder create, edit, and cancel flows on mobile, including audience selection and datetime selection.
- [ ] 3.3 Render reminder lifecycle system messages in the chat timeline using reminder metadata.

## 4. Verification

- [ ] 4.1 Add backend tests for reminder creation, duplicate prevention, update, cancel, firing, and idempotency.
- [ ] 4.2 Add mobile tests for long-press reminder entry points and reminder system-message rendering.
- [ ] 4.3 Manually verify `self` reminders, `everyone` reminders, update/cancel flows, and fired reminder delivery in chat.
