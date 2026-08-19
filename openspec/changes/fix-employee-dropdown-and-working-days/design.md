## Context

`LeaveListScreen` currently derives employee names from `leaveListProvider` results. `LeaveListNotifier` then applies a name search to those same results, which makes employees without orders unavailable and causes the options to collapse after a selection. The backend leave endpoint already accepts an approver-only `user_id` filter, while the Flutter repository does not expose it.

The NestJS backend in `backend-mobile-19t` obtains attendance from Odoo. Its attendance summary currently targets only the authenticated user, and its payroll export computes `actualWorkedDays` with a different rule that mixes physical attendance and WFH on Monday through Friday. The requested HR value is narrower: attendance-only values for local dates with a completed same-day check-in/check-out, where Saturday contributes `0.5` and every other qualifying date contributes `1`.

The unfinished `hr-working-days-display` change targets self-service attendance history and a different backend path. This change supersedes its working-day behavior and is the implementation source of truth.

## Goals / Non-Goals

**Goals:**

- Keep a complete employee selector independent of leave-order queries and filters.
- Use user IDs for employee selection and server-side leave filtering.
- Provide a backend-owned, approver-authorized employee payroll summary.
- Use one shared completed-attendance date calculation for the HR screen and payroll workbook.
- Apply Asia/Ho_Chi_Minh calendar dates consistently.
- Distinguish a valid zero from missing mapping or an unavailable Odoo source.
- Preserve existing payroll-cycle boundaries and payroll compensation semantics.

**Non-Goals:**

- Changing check-in or check-out creation flows.
- Counting hours or partial days based on session duration.
- Treating WFH, leave, or holidays as actual attendance days.
- Counting overnight attendance sessions.
- Adding a database table or caching layer for attendance summaries.
- Redesigning the leave-order list or payroll workbook beyond the affected metric.

## Decisions

### Decision 1: Use the employee directory as an independent selector source

The Flutter screen will load employees through the existing `GET /hr/employees` API and follow pagination until every page has been collected. The selector value will be the employee user ID; its label will be the employee name, with enough secondary identity in the UI to distinguish duplicate names when needed.

The selected ID will be stored separately from leave-order response state. `HrRepository.getLeaves` will accept `userId` and send it as `user_id`, using the authorization and filtering already present in `LeaveService.getLeaves`.

**Alternative considered:** Continue filtering by employee name on the client. Rejected because names are not unique and any option list derived from filtered orders recreates the reported bugs.

### Decision 2: Add an employee payroll-summary report endpoint

Add an approver-only endpoint under the existing HR reports surface:

```text
GET /hr/reports/payroll-summary?month=YYYY-MM&user_id=<uuid>
```

The endpoint will validate the month and user ID, authorize with the same admin/manager/HR-manager semantics used for leave approval, derive the payroll cycle on the backend, resolve the target user's Odoo employee mapping, fetch attendance, and return a typed summary. A representative response is:

```json
{
  "user_id": "uuid",
  "month": "2026-08",
  "cycle_from": "2026-07-25",
  "cycle_to_exclusive": "2026-08-25",
  "attendance_status": "available",
  "actual_working_days": 12
}
```

`attendance_status` will distinguish `available`, `unmapped`, and `unavailable`. The numeric value will be nullable when the source is not usable.

**Alternative considered:** Extend `GET /hr/attendance/summary` with a target user. Rejected because the requested value belongs to the selected payroll cycle and must remain identical to payroll export; the reports service is the clearer owner of that shared calculation.

### Decision 3: Calculate unique completed-attendance dates in ICT

Introduce a shared backend helper/service used by both payroll summary and payroll export. For every Odoo attendance record in the cycle it will:

1. Parse Odoo check-in and check-out timestamps using the canonical Odoo UTC interpretation.
2. Convert both timestamps to Asia/Ho_Chi_Minh calendar-date keys.
3. Discard records without a valid check-out or whose local check-in and check-out dates differ.
4. Add the common local date to a set.
5. Assign each unique Saturday date `0.5` and every other unique qualifying date `1`.
6. Return the sum of those unique date values.

The algorithm deliberately does not filter weekdays, inspect worked hours, or read leave/WFH records. Multiple completed sessions on one date collapse to one date.

**Alternative considered:** Calculate the value from raw history in Flutter. Rejected because it would duplicate timezone and payroll policy logic, expose more raw data than required, and risk disagreement with exports.

### Decision 4: Preserve payroll compensation semantics separately from actual attendance

`CÔNG THỰC TẾ` will change to the shared attendance-only value. Payroll-compensated totals will continue to apply existing WFH and paid-leave rules with their existing per-date cap and attendance precedence. The implementation must not replace those totals with a naive sum that could double-count a date containing both attendance and WFH.

**Alternative considered:** Remove WFH from every payroll total along with actual attendance. Rejected because the request changes the meaning of actual attendance, not the company's compensation policy.

### Decision 5: Keep summary state independent from order filters

Flutter will use a family provider keyed by `(payrollMonth, employeeUserId)`. Changing employee or month refreshes the summary; changing order status or type does not. The summary card remains visible above an empty order list and displays zero explicitly when `attendance_status` is `available`.

Selecting "All employees" clears the ID and suppresses the individual summary request/card. Unmapped and unavailable states render descriptive text rather than zero.

### Decision 6: Expose the calculation audit in the same summary

The employee payroll summary will include every attendance session fetched for the cycle, whether it was counted, its per-date value, and the exclusion reason when it was not counted. It will also include all employee orders that overlap the payroll cycle. Clicking the metric opens a responsive calendar: counted attendance, excluded sessions, and orders use distinct markers; selecting a date shows the exact sessions and orders used for HR reconciliation.

## Risks / Trade-offs

- **[Risk] Employee directories larger than one API page produce incomplete options** → Fetch pages until the response reports no remaining items and add pagination tests.
- **[Risk] Existing employee-role joins can omit or duplicate unexpected accounts** → Verify and, if necessary, harden the directory query so each authorized non-bot employee is returned once while admin-only accounts remain excluded.
- **[Risk] Odoo timestamps are grouped by UTC date instead of ICT date** → Centralize timestamp parsing and ICT date-key conversion, with early-morning and midnight-boundary tests.
- **[Risk] Missing Odoo mapping or source failure is mistaken for absence** → Return an explicit availability status and nullable count.
- **[Risk] Payroll totals change unintentionally when WFH is removed from actual attendance** → Keep payroll-compensated-day logic separate and add regression tests for attendance/WFH overlap.
- **[Trade-off] Loading all directory pages adds requests before the selector is complete** → Use the existing paginated endpoint to avoid a second employee-options API; the internal employee population is bounded and the directory provider can be cached.
- **[Risk] Two active OpenSpec changes describe different working-day rules** → Treat this named change as superseding `hr-working-days-display` and do not implement the older working-day tasks.

## Migration Plan

1. Add and test the shared completed-attendance calculation and payroll-summary endpoint without changing the Flutter consumer.
2. Update payroll export to source `CÔNG THỰC TẾ` from the shared calculation while preserving compensated totals.
3. Add Flutter models, repository methods, paginated employee provider, selected-ID state, and summary provider.
4. Update `LeaveListScreen` and its widget tests.
5. Deploy the backend before or together with the Flutter release. The existing leave and export endpoints remain backward compatible.
6. Roll back by reverting the Flutter summary consumer and report endpoint; no data migration is required.

## Open Questions

None. The business rule is fixed: only completed check-in/check-out sessions on the same ICT date create actual working days.
