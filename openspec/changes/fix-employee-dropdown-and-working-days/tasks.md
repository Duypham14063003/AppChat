## 1. Backend Completed-Attendance Calculation

- [x] 1.1 Add a shared backend result type and helper that parses Odoo attendance timestamps as UTC, converts them to Asia/Ho_Chi_Minh date keys, and sums unique completed dates with Saturday weighted as `0.5` and other dates as `1`.
- [x] 1.2 Add unit tests for the shared helper covering one completed session, multiple sessions on one date, open sessions, invalid timestamps, overnight sessions, early-morning ICT conversion, Saturday, Sunday, and cycle boundaries.
- [x] 1.3 Refactor payroll aggregation to use the shared helper for `actualWorkedDays` while keeping WFH, paid leave, attendance precedence, per-date caps, and compensated payroll totals behaviorally unchanged.
- [x] 1.4 Update payroll export tests so `CÔNG THỰC TẾ` is attendance-only and add regression cases for WFH without attendance and attendance/WFH overlap.

## 2. Backend Employee Payroll Summary API

- [x] 2.1 Add a validated payroll-summary query DTO accepting `month` in `YYYY-MM` format and a UUID `user_id`.
- [x] 2.2 Add a PayrollExportService employee-summary method that authorizes leave approvers, loads the target non-bot employee, derives the existing payroll cycle, resolves the Odoo employee mapping, and returns cycle metadata, attendance status, and nullable actual working days.
- [x] 2.3 Preserve distinct `available`, `unmapped`, and `unavailable` attendance statuses so valid zero days cannot be confused with missing or failed attendance data.
- [x] 2.4 Add `GET /hr/reports/payroll-summary` to PayrollExportController with admin, manager, and configured HR-manager authorization semantics.
- [x] 2.5 Add backend tests for authorization, unknown employees, missing Odoo mappings, Odoo failures, genuine zero, start-day-25 half-open boundaries, and December-to-January rollover.
- [x] 2.6 Include attendance-session audit details, per-day values/exclusion reasons, and overlapping employee orders in the payroll summary.

## 3. Backend Employee and Leave Filtering Verification

- [x] 3.1 Verify and harden the employee-directory query so paginated results return each eligible non-bot employee once, include inactive employees for historical review, and do not leak admin-only accounts through multi-role joins.
- [x] 3.2 Add employee-directory service tests for active and inactive employees, duplicate role joins, admin-only exclusion, deterministic name ordering, and pagination metadata.
- [x] 3.3 Add or update leave controller/service tests proving approvers can filter by `user_id`, regular employees cannot use that filter to read another employee's orders, and payroll-cycle filtering remains half-open.

## 4. Flutter Repository and Models

- [x] 4.1 Add a typed employee payroll-summary model with cycle dates, attendance status, and nullable actual working days.
- [x] 4.2 Add `HrRepository.getEmployeePayrollSummary(month, userId)` for the new report endpoint and parse each availability state.
- [x] 4.3 Extend `HrRepository.getLeaves` with an optional employee user ID and send it as the `user_id` query parameter.
- [x] 4.4 Add a repository method/provider flow that fetches all employee-directory pages instead of assuming the first page or a 100-item maximum is complete.
- [x] 4.5 Add repository tests for payroll-summary parsing, employee-filter query serialization, and multi-page employee collection.

## 5. Flutter State Management

- [x] 5.1 Replace the leave-list employee name search state with nullable `selectedEmployeeId` state and remove name-based filtering from leave responses.
- [x] 5.2 Pass the selected user ID to the leave request while preserving it across order status, order type, and payroll-month changes; clear it only when "All employees" is selected.
- [x] 5.3 Add an employee-options provider independent of leave-list state and sort/display the fully collected directory without deriving options from orders.
- [x] 5.4 Add an employee payroll-summary provider keyed by payroll month and employee user ID, and ensure order status/type changes do not refetch or alter it.
- [x] 5.5 Add provider tests for selection persistence, duplicate names resolved by ID, employee-with-no-orders behavior, month refresh, all-employees reset, and independent summary state.

## 6. Flutter Leave-Order Screen

- [x] 6.1 Rebuild the employee dropdown from the independent directory provider using user IDs as values and labels that can distinguish duplicate names.
- [x] 6.2 Preserve the complete dropdown option list after selecting an employee and show appropriate directory loading, retry, and empty states without blocking the order list unnecessarily.
- [x] 6.3 Add the `Ngày công thực tế` summary metric for an individually selected employee, including an explicit `0 ngày` for an available zero result.
- [x] 6.4 Render descriptive unmapped/unavailable attendance states instead of a numeric zero, and hide the individual metric when "Tất cả nhân viên" is selected.
- [x] 6.5 Keep the working-days metric visible when the selected employee has no matching orders and make the four-metric summary layout responsive on mobile and web widths.
- [x] 6.6 Add widget tests proving employees without orders remain selectable, options do not collapse after selection, duplicate names filter correctly, all-employees restores unfiltered orders, zero remains visible, unavailable data is non-numeric, and month changes retain the employee.
- [x] 6.7 Make the actual-working-days metric interactive and show a responsive payroll-cycle calendar with counted, excluded, and order markers.
- [x] 6.8 Show per-day attendance session details and all overlapping employee orders, with widget tests covering Saturday `0.5` display and calendar drill-down.

## 7. Verification and Handoff

- [x] 7.1 Run targeted backend HR service/controller tests, then run the backend test suite and production build in `backend-mobile-19t`.
- [x] 7.2 Run targeted Flutter HR repository/provider/widget tests, `flutter analyze`, and formatting checks in `mobile-19t/apps/mobile`.
- [ ] 7.3 Manually compare the selected employee's UI value with `CÔNG THỰC TẾ` in the payroll workbook for the same payroll cycle and attendance records.
- [ ] 7.4 Manually verify a no-order employee, a duplicate-name pair, an open attendance session, a weekend completed session, an overnight session, an unmapped employee, and a start-day-25 cycle.
- [ ] 7.5 Confirm `hr-working-days-display` is treated as superseded and is not applied alongside this change; archive or otherwise retire it through the OpenSpec workflow after this implementation is verified.
