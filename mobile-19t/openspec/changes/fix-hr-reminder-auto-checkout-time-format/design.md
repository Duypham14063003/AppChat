## Context

The HR module already contains most of the structural pieces for payroll configuration, reminders, and auto-checkout, but the current implementation has several integration gaps:

- the backend defines an `AttendanceReminderProcessor` but does not currently show repeatable job registration for the HR reminder queue,
- the payroll config screen reads raw database time strings and allows free-form text entry, which conflicts with backend `HH:mm` validation,
- auto-checkout uses worker execution time instead of the configured `auto_checkout_time`,
- HR reminder notification payloads are delivered through the shared push service, but app-level tap handling only routes chat notifications.

This change spans mobile HR UI, shared notification handling, backend BullMQ scheduling, and reminder execution semantics. The main constraint is to preserve the existing payroll config API surface while making the time contract deterministic for both admin users and background jobs.

## Goals / Non-Goals

**Goals:**
- Make payroll config time values round-trip safely between PostgreSQL `time`, backend validation, and Flutter editing flows.
- Ensure checkin reminder, checkout reminder, and auto-checkout jobs are actually scheduled and keep running without manual triggering.
- Make auto-checkout write the configured time-of-day into attendance records, even if the worker fires slightly later.
- Ensure HR reminder and auto-checkout notification taps open the HR attendance screen.
- Add enough verification coverage to prevent the current partially-wired state from regressing.

**Non-Goals:**
- Redesign the entire HR attendance UX beyond the payroll config time fields.
- Introduce per-user or per-department reminder schedules.
- Replace BullMQ, FCM, or Odoo sync architecture.
- Add a new public API endpoint for reminders; this change stays within the existing `/hr/config` and attendance APIs.

## Decisions

### D1: Treat `HH:mm` as the canonical app-facing time format

The backend will continue storing reminder and payroll times in PostgreSQL `time` columns, but all API-facing values used by Flutter will be normalized to `HH:mm`. The mobile app will also emit only `HH:mm` values when saving config.

Why:
- The DTO validation already expects `HH:mm`.
- Flutter form fields and time pickers operate naturally at minute precision.
- It avoids the current mismatch where `HH:mm:ss` can be loaded from the backend and rejected on save without user edits.

Alternatives considered:
- Keep `HH:mm:ss` end-to-end. Rejected because it complicates the admin UI without any product value.
- Relax validation to allow both `HH:mm` and `HH:mm:ss`. Rejected because it preserves ambiguity instead of fixing the contract.

### D2: Use picker-driven editing for payroll config time fields

Time-capable fields on the payroll config screen will be edited through a dedicated time selection flow and normalized display formatting rather than relying on raw free-text input alone.

Why:
- It reduces invalid input and aligns behavior with the leave screen's existing use of `showTimePicker`.
- Reminder fields need nullable behavior, which is clearer with explicit selection/clear actions than with open text.

Alternatives considered:
- Add input formatters only. Rejected because users would still be typing fragile values and would not solve the poor display experience for loaded `HH:mm:ss` strings.

### D3: Give the HR reminder processor ownership of its repeatable schedulers

The HR reminder processor will register or upsert its repeatable jobs during module startup, following the same BullMQ pattern already used by the task and auth schedulers.

Why:
- The queue already exists, so the missing piece is scheduler registration.
- Co-locating scheduling with the processor keeps ownership obvious and reduces hidden bootstrapping logic.

Alternatives considered:
- Create a separate bootstrap service just for HR scheduling. Rejected because it adds another lifecycle owner for a small queue.

### D4: Auto-checkout records use configured time-of-day, not execution timestamp

When auto-checkout runs, it will derive the checkout timestamp for each open attendance row from the current business day plus `auto_checkout_time`, instead of writing `new Date()` directly.

Why:
- The requirement is tied to configured payroll policy, not queue jitter.
- It makes downstream total-hour and overtime calculations deterministic.

Alternatives considered:
- Use worker execution time and only message the configured time in notifications. Rejected because the stored attendance data would still be wrong.

### D5: HR push payloads route through a shared non-chat notification path

The app-level push handler will interpret HR notification `type` values and navigate to `/hr`, while preserving the existing chat-specific path for `conv_id`.

Why:
- HR reminders are actionable only if the tap opens the relevant screen.
- This can be done inside the existing shared push-notification entry point without creating a second notification stack.

Alternatives considered:
- Ignore tap handling and rely on foreground notification display only. Rejected because background/opened-app flows are part of the expected reminder UX.

## Risks / Trade-offs

- [Risk] Existing clients may still receive `HH:mm:ss` if formatting is only fixed in Flutter and not normalized server-side. → Mitigation: normalize both at the API boundary and in the Flutter screen.
- [Risk] Repeatable jobs may duplicate if scheduler IDs are unstable. → Mitigation: use fixed scheduler keys and idempotent `upsertJobScheduler` registration.
- [Risk] Auto-checkout on day boundaries can be sensitive to timezone handling. → Mitigation: derive the configured time using the same local business timezone assumptions already used in HR reporting and notification copy.
- [Risk] Nullable reminder fields can become harder to test with picker-driven UX. → Mitigation: define explicit clear/disabled scenarios in the specs and tasks.
