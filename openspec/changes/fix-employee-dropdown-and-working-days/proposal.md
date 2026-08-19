## Why

The employee dropdown on the HR leave-order screen is built from the already filtered monthly order results, so employees without orders are missing and selecting one employee collapses the available options. HR also needs a reliable actual-working-days value per employee for payroll review, based only on completed attendance sessions rather than leave or WFH records.

## What Changes

- Populate the employee dropdown from the employee directory independently of the selected month, order status, order type, or selected employee.
- Identify and filter employees by stable user ID instead of display name, including support for duplicate employee names.
- Keep the full employee option set available after selecting an employee and allow returning to "All employees" without rebuilding options from order data.
- Calculate actual working days as unique Ho Chi Minh City calendar dates that contain at least one completed attendance session whose check-in and check-out occur on that same local date.
- Count each qualifying Saturday as `0.5` actual working day and every other qualifying calendar date as `1` day; multiple completed sessions on the same date apply that date's value only once.
- Exclude open sessions, overnight sessions, WFH, paid leave, unpaid leave, and other leave-order data from actual working days.
- Display actual working days for the individually selected employee and selected payroll cycle, including an explicit zero value when valid attendance data contains no qualifying dates.
- Let HR click the actual-working-days metric to inspect a payroll-cycle calendar with counted and excluded attendance sessions, per-day values, and the employee's overlapping orders.
- Distinguish unavailable attendance data or a missing Odoo employee mapping from a genuine zero-day result.
- Align the payroll workbook's `CÔNG THỰC TẾ` value with the same completed-attendance-only rule.
- Supersede the conflicting working-day behavior described by the unfinished `hr-working-days-display` change, which counted Monday through Saturday check-in dates and targeted a different screen/backend path.

## Capabilities

### New Capabilities

- `leave-list-employee-filter`: Provide a complete, stable employee selector on the leave-order screen and filter orders by employee user ID without shrinking the selector options.
- `completed-attendance-working-days`: Calculate, expose, and display actual working days from same-day completed attendance sessions and keep payroll export values consistent with that calculation.

### Modified Capabilities

<!-- No baseline capabilities currently exist under openspec/specs. -->

## Impact

- Flutter HR leave list UI, Riverpod state, HR repository, response models, and widget/provider tests under `mobile-19t/apps/mobile`.
- NestJS HR employee, leave, attendance/report API contracts, payroll aggregation, authorization, and unit tests under `backend-mobile-19t`.
- Odoo attendance records remain the attendance source; no database migration or new dependency is required.
- The employee list must handle all API pages and preserve historical/inactive employee visibility according to the directory response.
- Payroll-cycle boundaries remain backend-owned and use the existing half-open cycle semantics.
