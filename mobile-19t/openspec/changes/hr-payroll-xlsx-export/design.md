## Context

The current HR leave list workflow lets approvers review leave requests, but it does not provide a salary-processing export. Existing mobile logic filters leave requests on the client by calendar month, while payroll calculations depend on a configurable payroll start day and must support cross-month cycles such as `2026-06-25` through `2026-07-24` for payroll month `07/2026`.

The existing backend shape is also incomplete for this use case. Leave browsing already allows approver-wide visibility, but attendance history and attendance summary are still scoped to either the authenticated user or admin-only cross-user access. HR needs one authoritative export flow that computes workbook rows server-side from attendance, approved leave day splits, approved WFH entries, approved OT entries, and active employee metadata.

The user explicitly constrained the first version to:
- export `.xlsx`, not CSV
- include only `users.is_active = true`
- derive employee labels from `user.employment_status` (`official`, `probation`)
- leave the employee note, confirmation, and discrepancy columns blank

## Goals / Non-Goals

**Goals:**
- Add a single payroll export flow that produces a `.xlsx` workbook for the selected payroll month.
- Make the workbook available from the existing HR leave list UI for users who can approve leave requests.
- Compute workbook data on the backend using payroll-cycle boundaries derived from payroll configuration.
- Keep numeric payroll cells numeric so spreadsheet tools do not coerce them into dates.
- Align export permissions with HR approver behavior for both `admin` and `manager`.

**Non-Goals:**
- Adding employee confirmation workflows, discrepancy submission flows, or persistent export audit records.
- Backfilling hire date / resignation date logic; the corresponding workbook column will remain blank.
- Reworking existing leave list browsing to become server-filtered by payroll cycle.
- Supporting inactive employees or historical offboarding annotations in this first change.

## Decisions

### 1. Generate the workbook on the backend instead of the client

The export will be assembled server-side in the HR backend and returned as a binary `.xlsx` attachment.

Rationale:
- The backend already owns attendance, leave-day paid/unpaid classification, payroll configuration, and user activation state.
- Manager/admin permission checks belong on the server, not in client-only composition logic.
- `.xlsx` generation requires structured workbook output; building that on the backend avoids duplicating payroll logic in Flutter and prevents client-side inconsistencies.

Alternatives considered:
- Client-side CSV generation: rejected because the user explicitly requires `.xlsx`.
- Client-side `.xlsx` generation: rejected because it would duplicate payroll aggregation logic and require broader client data access.

### 2. Introduce a dedicated payroll export endpoint

The implementation should add a new HR reporting endpoint, separate from the existing leave list and attendance summary endpoints.

Rationale:
- Existing endpoints are scoped to browsing and per-user summaries, not multi-user payroll export.
- A dedicated endpoint can return binary content and own the workbook contract without disturbing the leave list JSON contract.
- This avoids overloading `/hr/leaves` or `/hr/attendance/summary` with export-only fields and role exceptions.

Alternatives considered:
- Extend `/hr/leaves` to return payroll workbook rows: rejected because the current leave endpoint is not the source of truth for attendance-derived columns.
- Extend `/hr/attendance/summary` with `user_id`: rejected because the export needs a complete workbook, not N client-orchestrated summary requests.

### 3. Treat the selected month as a payroll month label, not a calendar month

The export input month will represent the payroll month label. For a payroll start day of 25, payroll month `2026-07` maps to `2026-06-25` through `2026-07-24`, inclusive.

Rationale:
- This matches the explicit business rule from the user.
- It keeps the UI month selector semantics aligned with payroll processing instead of attendance browsing.
- Centralizing the date-range mapping in the backend prevents drift from existing client-side calendar-month filtering.

Alternatives considered:
- Reuse calendar month boundaries: rejected because it would misstate payroll totals.
- Let the client submit explicit from/to dates: rejected because the month-to-cycle rule is a business invariant that should remain server-owned.

### 4. Build workbook rows from a normalized server-side aggregation model

The backend should compute a row object per active employee before rendering `.xlsx`. Each row should contain:
- employee name with status suffix
- paid leave days
- unpaid leave days
- absent without leave days
- actual worked days
- payroll-compensated days
- WFH days
- OT hours
- blank note / confirmation / discrepancy fields

Rationale:
- This creates a clean separation between payroll calculation and workbook rendering.
- The same row model can support future JSON preview or audit output without redoing workbook logic.

Alternatives considered:
- Write workbook cells directly from raw queries: rejected because that tangles business rules with presentation and makes testing harder.

### 5. Use `employment_status` for name suffixes and leave resignation fields blank

The workbook will append `(thử việc)` when `employment_status = probation` and `(thực tập)` when `employment_status = intern`. The `NHẬN VIỆC/NGHỈ VIỆC` column will remain blank in this first version.

Rationale:
- `employment_status` already exists and is explicit.
- Hire/leave dates do not currently have a stable source of truth in the app’s HR data model.
- The user explicitly approved leaving that column blank for now.

Alternatives considered:
- Infer join/leave notes from `created_at` or audit logs: rejected because that is not reliable enough for payroll export semantics.

### 6. Keep download handling thin in Flutter

The mobile/web client should only trigger export, download the response bytes, and save/share the resulting `.xlsx` file.

Rationale:
- The app already has patterns for downloading browser bytes and saving binary files.
- This keeps Flutter changes localized to a button, request method, and platform-specific file handling.

Alternatives considered:
- Render a preview table in-app before export: rejected as unnecessary for the first version.

## Risks / Trade-offs

- [Permission drift between HR approver checks and controller decorators] → Use the same approver semantics in the export flow and supporting service checks, then verify manager coverage with tests.
- [Payroll cycle logic diverges from existing leave list month filtering] → Treat export as a dedicated payroll path and do not reuse the current client-side month filter implementation for workbook totals.
- [Odoo attendance data and local leave-day records can drift] → Compute all workbook rows in one backend flow and document that the export reflects the system state at generation time.
- [New `.xlsx` dependency increases backend surface area] → Choose a focused workbook library, isolate it behind an export service, and cover the generated sheet structure with automated tests.
- [Large employee counts could produce slow exports] → Aggregate rows before workbook rendering and keep the first version to one worksheet with a fixed column set.

## Migration Plan

1. Add the backend reporting endpoint and workbook generation service.
2. Add automated tests for payroll-cycle mapping, authorization, and workbook row content.
3. Add the mobile export action and binary download handling.
4. Release without replacing the existing leave list browse flow.

Rollback:
- Remove or disable the export action in the client.
- Revert the dedicated export endpoint and workbook dependency without affecting existing leave browsing APIs.

## Open Questions

- Should manager export visibility include every active employee or only the subset they are allowed to approve elsewhere in HR? The current product direction implies all active employees visible to approvers, but the implementation should confirm this against the existing role model.
- Which backend package should generate `.xlsx` in `backend-mobile-19t`? The change assumes a single new workbook dependency but does not mandate a specific library.
