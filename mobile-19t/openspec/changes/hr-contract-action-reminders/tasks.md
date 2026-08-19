## 1. Backend Reminder Semantics

- [x] 1.1 Update the contract reminder service to derive reminder action and threshold from contract type: internship/probation at 7 days, official at 10 days, temporary ignored.
- [x] 1.2 Update notification title/body copy so internship/probation reminders ask admins/managers to propose an official contract and official reminders ask them to propose renewal.
- [x] 1.3 Update notification payload data to use `type: hr_contract_action_reminder` and include `action`, `contract_id`, and `user_id`.

## 2. Recipient Filtering

- [x] 2.1 Restrict contract reminder recipient lookup to active users whose role name is `admin` or `manager`, case-insensitive.
- [x] 2.2 Remove the internal HR role id fallback from contract reminder recipient selection.

## 3. Mobile Notification Handling

- [x] 3.1 Verify current mobile notification routing for HR payloads and add support for `hr_contract_action_reminder` if it is not already handled.
- [x] 3.2 Route contract action reminder taps to the relevant employee contract context using `user_id` and `contract_id` from the payload.

## 4. Tests

- [x] 4.1 Update backend unit tests for internship and probation 7-day official-contract proposal reminders.
- [x] 4.2 Update backend unit tests for official 10-day renewal proposal reminders.
- [x] 4.3 Add backend unit coverage proving temporary contracts are ignored.
- [x] 4.4 Add backend unit coverage proving recipients are active users with role names `admin` or `manager` only.
- [x] 4.5 Add backend unit coverage for action-specific notification payloads.
- [x] 4.6 Preserve or update duplicate reminder event tests for the contract id, threshold day count, and reminder date uniqueness behavior.

## 5. Verification

- [x] 5.1 Run the focused backend contract reminder test suite.
- [x] 5.2 Run backend build or type-check to verify notification service changes compile.
- [x] 5.3 Run focused mobile analysis/tests for notification routing changes if mobile routing code is touched.
