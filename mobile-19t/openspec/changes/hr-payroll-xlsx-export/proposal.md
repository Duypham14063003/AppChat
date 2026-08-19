## Why

HR approvers currently can review leave requests on the "Xem Don" screen, but they cannot export a payroll-ready monthly workbook for salary processing. The existing APIs only support per-user attendance summaries and client-side month filtering, which is not sufficient for a reliable cross-user payroll export or for payroll cycles that run from one month boundary to another such as 25/06/2026 through 24/07/2026.

## What Changes

- Add a dedicated HR payroll export capability that generates a `.xlsx` workbook for active employees only.
- Add an export action to the HR leave list page for users who can approve leave requests.
- Add a backend payroll export endpoint that computes payroll-cycle totals server-side instead of reusing the current client-side leave list filters.
- Include payroll rows with the required salary-processing columns, using `user.employment_status` to append `(thử việc)` for `probation` and leaving the employee note / confirmation / discrepancy columns blank.
- Enforce payroll-cycle date ranges using the configured payroll start day, so a selected month such as `07/2026` maps to `2026-06-25` through `2026-07-24` when the start day is 25.
- Extend HR export permissions so both `admin` and `manager` can download the workbook, with behavior aligned to existing HR approver logic.

## Capabilities

### New Capabilities
- `hr-payroll-xlsx-export`: Generates a payroll-cycle `.xlsx` workbook for active employees from the HR leave list workflow, including salary-oriented attendance, leave, WFH, and OT totals.

### Modified Capabilities
- `rbac-authorization`: Clarify role-based access requirements for HR payroll export so admin and manager users can access the export flow and supporting summary data.

## Impact

- Affected mobile HR UI in `apps/mobile/lib/features/hr/screens/leave_list_screen.dart`
- Affected mobile HR data access in `apps/mobile/lib/features/hr/data/hr_repository.dart`
- Affected mobile HR state in `apps/mobile/lib/features/hr/providers/hr_providers.dart`
- Affected backend HR controllers and services in `/Users/phamngocduy/Documents/CTY/19t/mobile-19t/backend-mobile-19t/src/modules/hr`
- Likely new backend workbook generation dependency for `.xlsx` output
- Permission handling must stay consistent with existing HR approver role logic and payroll configuration behavior
