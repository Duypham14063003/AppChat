## Context

The current PoC process is encoded in chat text. A sale user posts a request, another user chooses a developer, somebody creates a message reminder, and the weekly list is manually rewritten in the main reporting conversation. The backend already provides PostgreSQL/TypeORM persistence, authenticated users and employee metadata, chat system messages and realtime fan-out, Firebase push delivery, BullMQ delayed jobs, audit logs, and a bot that broadcasts daily reports. The Flutter client already uses Riverpod, GoRouter, responsive layouts, a hidden `/tasks` branch, user pickers, and calendar components.

Message reminders cannot be the authoritative PoC model because each reminder is bound to one source message and contains only creator, audience, and one scheduled timestamp. Odoo task APIs are currently read-oriented and do not model customer demo scheduling or PoC-specific lifecycle rules. The production implementation target is `backend-mobile-19t`; `mobile-19t/apps/api` is not the target backend for this change.

Stakeholders are sale users who submit requests, any authenticated active user who can coordinate assignments, primary developers who prepare PoCs, and administrators who need weekly workload visibility. The business decisions are: there is no coordinator permission, one primary developer is assigned per PoC, and `demo_at` is both the completion deadline and customer demo time.

## Goals / Non-Goals

**Goals:**

- Make one structured PoC record the authoritative source for assignment, schedule, status, links, outcome, notifications, and reporting.
- Allow every authenticated active user to create, assign, reassign, and reschedule PoCs while preserving actor history.
- Give assignees and administrators clear personal queues, weekly demo schedules, overlap warnings, and planned PoC capacity.
- Project PoC lifecycle events into working conversations without making chat messages authoritative.
- Deliver idempotent reminders and maintain one current weekly summary in the fixed reporting conversation.
- Fit PoC workflows into the existing responsive Flutter work area and retain Odoo task browsing.

**Non-Goals:**

- Multiple developers or weighted contributor allocation on one PoC.
- Actual time tracking, timesheet approval, payroll calculations, or performance scoring.
- Including Odoo tasks in PoC capacity or writing PoC state back to Odoo.
- Customer-facing access, proposal/contract management, or the complete customer journey after demo.
- Replacing general chat reminders, daily reports, or the existing notification pipeline.
- Recurring demos, external calendar synchronization, or configurable per-employee work calendars in MVP.

## Decisions

### D1: Create a dedicated PoC module and relational model

The backend will add a `PocModule` with `pocs`, `poc_history`, `poc_notification_events`, and `poc_weekly_reports` tables. The `pocs` row holds current state; append-only history records preserve actor, event, previous values, and new values. Notification-event rows and weekly-report rows provide delivery idempotency and stable chat message references.

Core `pocs` fields include UUID `id`, human-readable `code`, customer/title/requirement fields, product type, priority, creator/sale user, one nullable primary developer, assigning actor, optional source message, working conversation, planned start, positive estimated hours, `demo_at`, status, post-demo outcome, PoC URL, cancellation reason, readiness/demo timestamps, integer version, and timestamps.

Alternatives considered:

- Extend `message_reminders`: rejected because message ownership and a single fire time cannot model assignment, workload, lifecycle, or history.
- Treat every PoC as an Odoo task: rejected because the current integration is read-oriented and PoC-specific state would be lost or require risky Odoo customization.
- Store snapshots only in JSONB: rejected because assignment, week, state, and capacity queries need indexed relational fields.

### D2: Use a strict state machine and derived attention flags

Persisted statuses are `unassigned`, `assigned`, `in_progress`, `ready`, `demonstrated`, and `cancelled`. A demonstrated PoC records one outcome: `completed`, `revision_required`, or `not_proceeding`. `revision_required` returns the PoC to `in_progress` with a new future `demo_at`. `overdue`, `demo_soon`, `overlap`, and `over_capacity` are derived query/UI flags rather than persisted lifecycle states.

This separates business progression from time-sensitive presentation and avoids stale overdue flags.

### D3: Any active user may coordinate, with optimistic concurrency

There is no coordinator role or permission. Any authenticated active non-bot user may create a request, assign/reassign its developer, change its plan, or apply a valid status transition. The backend records `assigned_by_user_id` and appends history for every mutation.

Every mutation includes the last-read `version`. TypeORM optimistic versioning or an equivalent `UPDATE ... WHERE id = ? AND version = ?` check rejects stale writes with HTTP 409 and returns the current representation. This prevents two coordinators from silently overwriting each other.

Alternatives considered:

- Last-write-wins: rejected because simultaneous assignment is plausible and silent reassignment would create missed work.
- Admin/manager-only coordination: rejected by the confirmed business rule.
- Pessimistic locks held across the UI flow: rejected because locks would be long-lived and fragile on mobile networks.

### D4: Keep a stable UUID identity and generate a readable assignment code

The UUID remains the immutable API and deep-link identity. On first assignment, the service atomically allocates a sequence and generates a readable code using normalized sale initials, developer initials, product code, sequence, and demo time/date, following the existing operational convention. Reassignment or schedule changes regenerate the display code and record the previous code in history; links continue to use UUID and therefore remain stable.

Code generation is backend-owned and collision-safe. The client never constructs or edits a code. This preserves the recognizable operational format without coupling references to mutable names and dates.

### D5: Treat `demo_at` as the only deadline and require an explicit work plan

Assignment requires one active primary developer, `planned_start_at < demo_at`, and `estimated_hours > 0`. There is no separate delivery deadline. Readiness is expected before `demo_at`; reaching `demo_at` before readiness produces an overdue flag and notification.

Separating planned start and estimate from the one deadline is necessary because a deadline alone cannot describe when developer capacity is consumed.

### D6: Calculate planned capacity from PoC estimates only

Capacity queries use a default Monday-Friday work calendar of 8 hours per day and 40 hours per ISO week in `Asia/Ho_Chi_Minh`. For a PoC spanning multiple workdays or weeks, its estimated hours are allocated proportionally across the working-day portions intersecting `[planned_start_at, demo_at]`. Cancelled, completed, and not-proceeding PoCs consume no future capacity; active revision work does.

The response returns each developer's allocated hours, capacity hours, PoC spans, overlap pairs, daily load, weekly load, and derived overload flags. Approved leave may be displayed as contextual calendar data through existing HR APIs, but MVP workload totals remain based on fixed capacity and PoC estimates only. Odoo tasks and actual attendance are excluded.

Alternatives considered:

- Count PoCs instead of hours: rejected because PoCs vary substantially in size.
- Assign the entire estimate to the demo week: rejected because it hides work beginning in an earlier week.
- Build a timesheet engine: rejected as unnecessary for planned-capacity visibility.

### D7: Use a dedicated BullMQ PoC scheduler

PoC notification jobs are independent from `message_reminders`. Deterministic job IDs combine PoC ID and event kind: assignment follow-up, 24-hour demo reminder, 30-minute demo reminder, and deadline/overdue check. Assignment and rescheduling remove obsolete pending jobs and create only future applicable jobs. Workers claim a unique `poc_notification_events` record before emitting chat or push results so retries are idempotent.

PoC state commits are not rolled back if downstream chat or push delivery fails. Delivery is retried and surfaced through logs/event state.

### D8: Project lifecycle events into chat with structured metadata

Assignment, reassignment, schedule changes, readiness, revision, cancellation, reminder, overdue, and demonstration events create chat system messages in the selected working conversation. Structured metadata contains `kind`, `poc_id`, current code, actor, developer, schedule, status, old/new values when relevant, and a deep link. Realtime distribution reuses the existing Redis chat fan-out. Scheduled notifications use the system bot and push recipients derived from the event: developer for assignment/deadline, sale/creator for readiness, and relevant working-conversation members for demo reminders.

The source chat message is optional metadata for traceability. It never owns PoC state.

### D9: Maintain one stable weekly summary message

`POC_REPORT_CONVERSATION_ID` defaults to `35353995-517b-4fcb-b4d7-e0f23c5f4042`; `POC_REPORT_TIME` defaults to Friday 12:00 in `Asia/Ho_Chi_Minh`. A `poc_weekly_reports` row is unique by ISO week/year and stores snapshot metadata, publication state, and `chat_message_id`.

The scheduled publisher creates the weekly bot message once. Relevant PoC changes enqueue a debounced refresh that edits the same bot-authored message after publication instead of posting duplicates. The summary includes counts by status, overdue items, demos ordered by `demo_at`, sale/developer names, capacity totals, overload warnings, and a deep link. Manual refresh/publish remains available for recovery, but users cannot hand-edit source figures.

### D10: Place PoC inside a responsive Work hub

The existing hidden `/tasks` branch becomes a visible `Work` destination with `PoC` and `Tasks` segmented views. To retain at most five root destinations, employee-management entry moves under HR for authorized users rather than remaining a separate root tab. No sixth bottom-navigation item is added.

PoC list defaults are contextual but not permission gates: creator/sale users can select `My requests`, assigned developers can select `My PoCs`, and everyone can open `Unassigned`, `This week`, and `Capacity`. Desktop/tablet uses master-detail and a developer-by-day timeline; narrow layouts use full screens and developer summary lists. A chat context action can prefill a new request with source message and conversation IDs.

The UI uses the existing theme palette, Riverpod async states, GoRouter routes, employee/user APIs, date pickers, and calendar conventions.

## Risks / Trade-offs

- [Risk] Open coordination permits accidental reassignment or schedule changes. -> Mitigation: optimistic concurrency, explicit confirmation, append-only history, old/new chat events, and easy visibility of the latest actor.
- [Risk] Name-derived display codes can change and initials can collide. -> Mitigation: UUID deep links remain authoritative, the sequence is atomic, code generation is backend-owned, and previous codes are retained in history.
- [Risk] Fixed 40-hour capacity is not a complete availability model. -> Mitigation: label it planned PoC capacity, show leave as context, and exclude actual utilization claims from MVP.
- [Risk] A delayed job may survive a reschedule or retry. -> Mitigation: deterministic job IDs, removal/rescheduling, delivery-event uniqueness, and state checks immediately before delivery.
- [Risk] Chat/report failure after a successful PoC mutation creates temporary projection lag. -> Mitigation: persist authoritative state first, retry projections independently, and provide manual report refresh.
- [Risk] The reporting conversation is also used by daily reports and rewards. -> Mitigation: use distinct PoC metadata/kinds, one message per week, and deep links rather than repeated text messages.
- [Risk] Moving employee management under HR changes navigation expectations. -> Mitigation: retain routes and authorization, add a clear HR entry, and cover route selection with widget tests.

## Migration Plan

1. Add nullable configuration defaults, PoC tables, indexes, constraints, and entities without changing existing tables or routes.
2. Deploy backend APIs, audit/history, capacity queries, and scheduler with weekly publication disabled until the reporting bot membership and target conversation are verified.
3. Deploy Flutter Work hub and PoC screens behind backend capability availability while retaining the existing Task screen.
4. Enable working-conversation projections and push delivery, then enable the Friday weekly publisher.
5. Monitor notification-event failures, weekly message uniqueness, queue depth, and 409 conflict rates.

Rollback disables PoC creation/schedulers and hides the Work/PoC entry while retaining PoC data and historical chat messages. The additive migration can remain in place; dropping it is only safe after exporting or explicitly discarding created PoCs.

## Open Questions

None for MVP. The confirmed defaults are one primary developer, open coordination for all active users, one `demo_at` deadline, PoC-only planned capacity, and Friday 12:00 weekly publication to the specified reporting conversation.
