## 1. Backend Data Model and Module Foundation

- [x] 1.1 Add validated PoC configuration for report conversation, Friday publication time, timezone, daily/weekly capacity defaults, and reminder offsets, defaulting the report conversation to `35353995-517b-4fcb-b4d7-e0f23c5f4042`.
- [x] 1.2 Create a TypeORM migration for `pocs`, atomic code sequence support, `poc_history`, `poc_notification_events`, and `poc_weekly_reports` with foreign keys, state/data constraints, uniqueness, and coordination/capacity indexes.
- [x] 1.3 Add PoC, history, notification-event, and weekly-report entities with explicit status/outcome/event types and relations to users, messages, and conversations.
- [x] 1.4 Create `PocModule`, register entities and BullMQ queues, and wire it into `backend-mobile-19t/src/app.module.ts` without modifying the legacy API tree.
- [x] 1.5 Add migration/entity tests covering valid schema, code uniqueness, one-developer storage, report uniqueness by ISO week, and notification delivery uniqueness.

## 2. PoC Lifecycle and Coordination APIs

- [x] 2.1 Add validated DTOs and response models for request creation, assignment/reassignment, plan updates, lifecycle transitions, post-demo outcomes, links, cancellation, history, filters, and versioned mutations.
- [x] 2.2 Implement create and detail services that validate active users, future `demo_at`, optional conversation membership/source-message ownership, and creator/sale ownership.
- [x] 2.3 Implement paginated list queries for my requests, my assignments, unassigned, selected week, status, developer, sale owner, priority, and text search with derived overdue/upcoming flags.
- [x] 2.4 Implement collision-safe readable-code allocation on first assignment and regeneration/history behavior for developer or demo schedule changes while keeping UUID identity stable.
- [x] 2.5 Implement assignment and plan mutations available to every active non-bot user, enforcing one active developer, positive estimate, planned-start ordering, and actor attribution.
- [x] 2.6 Implement the lifecycle state machine, readiness/demonstration timestamps, terminal outcomes, revision-required return to in-progress with a new plan, and cancellation cleanup.
- [x] 2.7 Implement append-only PoC history and audit-log integration for all material mutations with actor and old/new values.
- [x] 2.8 Implement optimistic concurrency for every mutation and map stale versions to HTTP 409 responses containing the latest representation.
- [x] 2.9 Expose authenticated `/pocs` REST endpoints with Swagger metadata and consistent 400/404/409 error mapping.
- [x] 2.10 Add service/controller tests covering open coordination, validation, readable codes, state transitions, revision, cancellation, filtering, derived flags, audit history, and simultaneous assignment conflicts.

## 3. Planned Capacity APIs

- [x] 3.1 Implement Ho Chi Minh City ISO-week and Monday-Friday working-period utilities with proportional estimate allocation across days and weeks.
- [x] 3.2 Implement capacity aggregation per developer with allocated/capacity/remaining/excess hours, daily load, contributing PoCs, overlaps, and overload flags while excluding terminal PoCs and Odoo/actual-time data.
- [x] 3.3 Implement candidate assignment preview that recalculates projected load and conflicts for a proposed developer, start, estimate, and demo time without blocking warned assignments.
- [x] 3.4 Expose selected-period capacity and assignment-preview endpoints, including active developer identity data required by the client.
- [x] 3.5 Add deterministic unit tests for weekend exclusion, cross-week allocation, revision work, terminal exclusion, overlap detection, overload thresholds, and preview calculations.

## 4. PoC Chat Projection and Scheduled Notifications

- [x] 4.1 Add a public chat integration method for inserting bot/system PoC messages with structured metadata, realtime fan-out, and deep-link context without coupling PoC state to chat messages.
- [x] 4.2 Implement lifecycle projections for assignment, reassignment, plan changes, readiness, revision, cancellation, demonstration, and overdue events, including old/new values where applicable.
- [x] 4.3 Implement the dedicated PoC BullMQ job service with deterministic assignment/deadline/reminder job IDs and safe removal/rescheduling when plan or state changes.
- [x] 4.4 Implement idempotent PoC notification workers for applicable 24-hour, 30-minute, and deadline checks using unique notification-event claims and current-state validation.
- [x] 4.5 Route assignment/deadline pushes to the primary developer, readiness pushes to the sale owner, and overdue notifications to both while reusing active sessions and existing Firebase handling.
- [x] 4.6 Ensure PoC mutations commit when chat/push projection fails, persist retry/failure state, and add operational logging for eventual delivery.
- [x] 4.7 Add tests for structured metadata, absent working conversation, recipient selection, elapsed reminder windows, rescheduling, cancellation, overdue suppression, worker retries, and downstream delivery failures.

## 5. Stable Weekly PoC Summary

- [x] 5.1 Implement weekly summary aggregation for status counts, overdue PoCs, ordered demos, sale/developer names, developer capacity, overload warnings, and app deep links.
- [x] 5.2 Implement system-bot/report-conversation verification and one weekly-report record/message per ISO week in the configured conversation.
- [x] 5.3 Implement Friday 12:00 `Asia/Ho_Chi_Minh` publication plus a debounced refresh path that edits the stored bot message after relevant PoC changes instead of posting duplicates.
- [x] 5.4 Add authenticated weekly report view and recovery publish/refresh endpoints that always regenerate data from PoC records.
- [x] 5.5 Add tests for timezone/week boundaries, stable message identity, publisher retries, refresh edits, summary ordering/content, target conversation configuration, and manual recovery.

## 6. Flutter Data Layer and Work Navigation

- [x] 6.1 Add immutable PoC, history, capacity, weekly-report, filter, and conflict models with resilient JSON parsing and local date conversion.
- [x] 6.2 Add PoC repository methods for all lifecycle, list, capacity, preview, weekly report, and recovery APIs, including version headers/body and HTTP 409 latest-state parsing.
- [x] 6.3 Add Riverpod providers/notifiers for PoC queues, detail, mutation invalidation, assignment preview, selected week, capacity, and weekly summary with loading/error/refresh behavior.
- [x] 6.4 Convert the hidden `/tasks` branch into a visible Work destination containing `PoC` and existing `Tasks` modes on narrow and wide layouts.
- [x] 6.5 Move authorized employee-management entry under HR while preserving `/employees` routes, authorization redirects, and a maximum of five root destinations.
- [x] 6.6 Add GoRouter routes and UUID-based deep links for PoC detail, form, assignment, capacity, weekly view, and links originating from chat notifications.
- [x] 6.7 Add navigation and provider tests for Work/Task preservation, role-independent PoC access, HR employee entry, route restoration, and conflict parsing.

## 7. Flutter PoC Coordination Experience

- [x] 7.1 Build the responsive PoC queue screen with My requests, My PoCs, Unassigned, and This week modes, search/filter controls, attention summary, pagination, and empty/error states.
- [x] 7.2 Build the concise request form with customer/title, requirement, product type, priority, demo date/time, conversation picker, references, validation, and no client-editable code.
- [x] 7.3 Add a chat message context action that opens the request form prefilled with source message and working conversation IDs.
- [x] 7.4 Build assignment/reassignment UI with searchable active developer choices, planned start, numeric estimate controls, demo schedule, capacity preview, overlap/overload warnings, and explicit warned-assignment confirmation.
- [x] 7.5 Build PoC detail with lifecycle progress, derived attention, people/plan/link/chat fields, valid context actions, outcome/revision forms, and chronological history.
- [x] 7.6 Handle stale-write conflicts by preserving the user's draft, presenting latest server values, and requiring review before retry.
- [x] 7.7 Build wide developer-by-day capacity timeline and narrow expandable developer summaries with stable dimensions, readable PoC spans, overlap/overload treatment, and approved-leave context.
- [x] 7.8 Build the weekly PoC report view for bot deep links, counts, demo schedule, overdue list, capacity summary, and recovery refresh action.
- [x] 7.9 Add widget/golden tests across phone and desktop widths for queues, long names/codes, forms, assignment warnings, detail/history, conflict recovery, capacity, weekly report, loading, empty, and error states.

## 8. Chat Cards, Notifications, and End-to-End Verification

- [x] 8.1 Extend chat system-message parsing/rendering for versioned PoC lifecycle, reminder, overdue, and weekly-summary metadata with safe fallback for malformed or newer payloads.
- [x] 8.2 Add PoC push/deep-link routing that opens the correct UUID detail or weekly view after cold start, background resume, and foreground receipt.
- [x] 8.3 Add chat widget tests for assignment/schedule-change/reminder/overdue/readiness/weekly cards, old/new values, open-detail actions, and fallback rendering.
- [x] 8.4 Run backend formatting, lint, focused/full Jest tests, TypeORM migration validation, and production build; resolve failures attributable to the change.
- [x] 8.5 Run Flutter formatting, analysis, focused/full tests, and web/mobile builds; resolve failures attributable to the change.
- [ ] 8.6 Perform an end-to-end smoke flow: create from Work and chat, concurrently assign, start, reschedule, mark ready, fire reminders, demonstrate/revise/complete, inspect capacity, publish/refresh the stable weekly message, and follow all deep links.
- [x] 8.7 Verify screenshots at mobile and desktop viewports for non-overlap, text containment, navigation stability, timeline legibility, theme compatibility, and the fixed reporting conversation output.
- [x] 8.8 Document environment variables, migration/deployment sequence, scheduler enablement, rollback, queue/report monitoring, and the distinction between planned PoC capacity and actual timesheets.
