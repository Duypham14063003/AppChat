## Why

PoC work is currently coordinated through free-form chat messages, manually created reminders, and manually rewritten weekly summaries. This leaves no authoritative record of ownership, schedule, status, or planned developer capacity, so administrators cannot reliably see who is preparing each demo or when developers are overloaded.

## What Changes

- Introduce a structured PoC record as the single source of truth for customer/demo requests, one primary developer, planned start, estimated hours, demo deadline, status, working conversation, links, outcome, and change history.
- Allow any authenticated active user to create a PoC request and assign or reassign its primary developer; record the assigning user for audit instead of introducing a coordinator role.
- Use one `demo_at` timestamp as both the PoC completion deadline and the customer demo schedule.
- Add lifecycle management from unassigned request through assigned, in progress, ready for demo, demonstrated, and cancelled, including post-demo outcomes and revision flow.
- Add developer capacity views derived from PoC estimated hours and planned date ranges, including overlap and overload indicators. MVP capacity excludes Odoo tasks and actual timesheets.
- Publish structured assignment, schedule-change, readiness, overdue, and demo reminder events to the selected working conversation and send targeted push notifications.
- Generate a weekly PoC summary for conversation `35353995-517b-4fcb-b4d7-e0f23c5f4042`, with one stable weekly message that is refreshed as PoC data changes and scheduled publication at 12:00 Friday in `Asia/Ho_Chi_Minh`.
- Add responsive Flutter screens for role-oriented PoC queues, request creation, assignment, detail/history, weekly schedule, developer capacity, and weekly report review.
- Expose PoC from the existing work/task area rather than adding a sixth root navigation destination, and support creating a PoC request from a source chat message.

## Capabilities

### New Capabilities

- `poc-record-lifecycle`: Structured PoC creation, assignment, scheduling, state transitions, outcomes, concurrency control, and audit history.
- `poc-capacity-planning`: Planned developer workload aggregation, schedule overlap detection, overload indicators, and weekly capacity queries based on PoC estimates.
- `poc-chat-automation`: Working-group lifecycle messages, scheduled reminders and push delivery, and stable weekly summary publication to the configured main conversation.
- `poc-coordination-ui`: Responsive Flutter workflows for creating, assigning, tracking, scheduling, and reviewing PoCs and developer capacity.

### Modified Capabilities

<!-- No existing capability requirements are changed. Existing chat reminders, Odoo tasks, and daily reports remain independent. -->

## Impact

- NestJS backend: a new PoC module, TypeORM entities and migrations, lifecycle and capacity APIs, BullMQ scheduling, audit logging, chat system-message projection, push delivery, and weekly summary publishing under `backend-mobile-19t`.
- Flutter application: new models, repository/providers, work-hub routes, PoC list/form/detail/assignment/capacity/report screens, chat entry action, deep links, and responsive widget tests under `mobile-19t/apps/mobile`.
- PostgreSQL stores authoritative PoC state, notification delivery markers, stable weekly-report message references, and versioned history.
- Redis/BullMQ schedules deadline and demo notifications using idempotent deterministic jobs.
- Existing users, conversations, system bot, chat realtime delivery, push notification pipeline, employee directory, and calendar UI patterns are reused.
- No breaking API change is intended. Existing message reminders stay message-bound, Odoo task APIs remain read-only, and daily-report broadcasting remains unchanged.
