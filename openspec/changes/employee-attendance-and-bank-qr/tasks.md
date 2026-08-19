## 1. Prerequisite Attendance Alignment

- [x] 1.1 Confirm the payroll-summary API, completed-attendance helper, session audit details, and Flutter summary models/providers from `fix-employee-dropdown-and-working-days` are present and passing targeted tests before integrating the employee tab.
- [x] 1.2 Add or consolidate shared backend and Flutter role predicates for employee-attendance and employee-profile management, covering admin, manager, configured HR manager, employee self, and unauthorized cross-user cases.
- [x] 1.3 Add regression coverage proving the employee attendance view uses payroll-summary cycle boundaries and completed-attendance values rather than the conflicting `hr-working-days-display` calculation.

## 2. Backend Employee Payment Data

- [x] 2.1 Add a backward-compatible migration for nullable `bank_code`, `bank_account_name`, `bank_qr_image_url`, and constrained `bank_qr_source` employee-profile columns while preserving legacy bank fields.
- [x] 2.2 Extend `EmployeeProfile`, employee detail views, and update DTO validation with normalized payment fields and valid generated/uploaded source values.
- [x] 2.3 Update employee profile service authorization so employees can mutate only their own allowed contact/payment fields and HR roles can manage employee payment data on behalf of another user.
- [x] 2.4 Validate QR source invariants in the service and normalize legacy or impossible source combinations without breaking old employee profiles.
- [x] 2.5 Add employee service/controller tests for migration-compatible reads, employee self updates, HR updates, protected-field isolation, invalid bank/source combinations, and unauthorized cross-user access.

## 3. Backend Custom QR Upload Lifecycle

- [x] 3.1 Add authenticated self and HR-targeted multipart endpoints for uploading/replacing custom employee payment QR images under `uploads/hr/payment-qr`.
- [x] 3.2 Enforce JPEG, PNG, or WebP MIME types, a 5 MiB limit, required files, server-generated filenames, and managed upload-directory path safety.
- [x] 3.3 Persist the uploaded URL and select `uploaded` atomically; implement removal that clears the URL, selects `generated`, and performs best-effort old-file cleanup.
- [x] 3.4 Implement best-effort cleanup for superseded local files after successful replacement without deleting paths outside the managed upload directory.
- [x] 3.5 Add controller/service tests for valid self and HR uploads, replace/remove behavior, missing files, MIME/size rejection, authorization, source transitions, and cleanup failure handling.

## 4. Flutter Payment Models and Data Access

- [x] 4.1 Extend Flutter employee profile and update-request models with bank code, account-holder name, QR image URL, and active source while retaining legacy parsing behavior.
- [x] 4.2 Add HR repository methods for self and HR-targeted QR upload/removal and source switching using Dio multipart requests.
- [x] 4.3 Extend profile mutation providers to upload, replace, remove, and select QR sources while invalidating the correct self/detail providers and preserving form state after failures.
- [x] 4.4 Add repository/provider tests for new profile fields, multipart serialization, self versus HR endpoint selection, source transitions, invalidation, and recoverable failures.

## 5. VietQR Generation

- [x] 5.1 Add a versioned supported-bank registry containing stable bank code, display name, and VietQR/NAPAS participant identifiers without exposing it through free-text-only input.
- [x] 5.2 Add a maintained Flutter QR-rendering dependency and implement a local EMVCo/VietQR payload builder for bank/account recipient data with no fixed amount or transfer message.
- [x] 5.3 Add deterministic payload, field-length, Unicode/account normalization, CRC, unsupported-bank, missing-account, and known-vector unit tests.
- [x] 5.4 Add a reusable generated/custom payment QR preview component with enlarged preview, active-source label, incomplete-data, generation-error, and offline rendering states.

## 6. Employee Payment Profile UI

- [x] 6.1 Refactor the HR profile view/editor to present bank selection, account number, account-holder name, generated preview, and custom image controls in a dedicated responsive payment section.
- [x] 6.2 Allow employee self-service editing of payment fields without unlocking protected identity, tax, employment, or contract fields; retain HR on-behalf editing.
- [x] 6.3 Implement custom image pick/upload/replace/remove/retry flows with progress, type/size feedback, current-image retention on failure, and generated-source fallback.
- [x] 6.4 Warn when bank code or account number changes while an uploaded QR is active and require an explicit choice to keep the custom image or switch to regenerated QR before saving.
- [x] 6.5 Add a discoverable route/action from the employee's account/profile area to their own HR payment profile.
- [x] 6.6 Add responsive widget tests for legacy values, supported bank selection, incomplete details, generated preview, self-field restrictions, HR editing, upload states, source switching, stale-image confirmation, and narrow/wide layouts.

## 7. Employee Attendance Tab

- [x] 7.1 Replace the unused employee detail `Lịch sử` placeholder with a permission-gated `Chấm công` tab without adding a fifth narrow-screen tab.
- [x] 7.2 Add current payroll-month initialization and previous/next payroll-month navigation keyed by employee user ID and `YYYY-MM`, with correct cache invalidation on employee/month changes.
- [x] 7.3 Reuse the employee payroll summary provider to display actual working days, cycle range, session/order metrics, refresh/retry controls, explicit zero, unmapped, unavailable, loading, and no-session states.
- [x] 7.4 Refactor `EmployeeWorkingDaysDetailView` for embedded and dialog use, then embed the responsive payroll-cycle calendar and selected-day session/order audit in the attendance tab.
- [x] 7.5 Add widget/provider tests for permitted roles, unauthorized API access, month navigation, employee switching, inactive employees, zero/unmapped/unavailable states, Saturday `0.5`, excluded sessions, leave markers, refresh, and mobile/web widths.

## 8. Verification and Handoff

- [x] 8.1 Run targeted backend employee, payroll-summary, authorization, migration, and upload tests, then run the backend test suite, lint, and production build.
- [x] 8.2 Run targeted Flutter HR repository/provider/widget and VietQR tests, then run formatting, `flutter analyze`, and the relevant Flutter test suite.
- [ ] 8.3 Manually compare an employee attendance tab with payroll export for the same configured cycle, including genuine zero, unmapped Odoo, source failure, Saturday, open, and overnight sessions.
- [ ] 8.4 Manually scan generated QR codes for multiple supported banks with multiple banking apps and verify that beneficiary bank/account are correct with no preset amount or message.
- [ ] 8.5 Manually verify legacy profile display, employee self edits, HR edits, upload/replace/remove, source switching, bank-change warning, invalid/oversized images, offline generated preview, and mobile/web responsive layouts.
- [x] 8.6 Document deployment ordering, nullable-column rollback, custom-upload cleanup behavior, supported-bank registry maintenance, and the dependency on completing `fix-employee-dropdown-and-working-days` without applying the superseded calculation.
