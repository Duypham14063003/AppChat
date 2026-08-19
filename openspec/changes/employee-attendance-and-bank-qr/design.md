## Context

The Flutter employee directory already routes authorized HR roles to an employee detail screen with four tabs. Its `Lịch sử` tab is an unused placeholder. Separately, the active `fix-employee-dropdown-and-working-days` change has implemented a backend employee payroll summary, typed Flutter models/providers, and a responsive working-day calendar containing counted and excluded Odoo attendance sessions plus overlapping employee orders. This change must compose that work rather than introduce another attendance calculation.

Employee profiles currently store nullable `bank_name` and `bank_account_number` values. HR can edit them, but normal employees cannot. There is no normalized bank identifier, account-holder field, QR source, or custom QR image. The backend already serves `/uploads` and has multipart patterns for avatars and contract attachments. Flutter already uses `image_picker`, `file_picker`, and Dio multipart uploads, but no QR encoder is declared.

The feature crosses Flutter and NestJS, changes persisted employee data, handles sensitive payment information, and introduces QR encoding and authenticated file lifecycle concerns. Stakeholders are employees maintaining payment information and HR roles reviewing attendance and administering employee profiles.

## Goals / Non-Goals

**Goals:**

- Put a payroll-cycle attendance audit directly on an authorized employee detail screen.
- Keep the displayed working-day total identical to the existing payroll summary/export rule.
- Normalize supported Vietnamese bank identity sufficiently to generate deterministic VietQR-compatible recipient payloads.
- Let employees manage their own payment details and QR while preserving HR-on-behalf management.
- Support both a generated QR and an optional custom uploaded QR with an explicit active source.
- Preserve old employee profile rows and current clients through additive nullable fields.
- Enforce the same employee-attendance and payment-profile authorization semantics in the UI and backend.

**Non-Goals:**

- Recalculate, edit, approve, or correct Odoo attendance from the employee screen.
- Replace the employee's existing personal attendance history/check-in UI.
- Validate bank-account ownership, call a bank API, or guarantee that a user-uploaded image encodes the stored account.
- Add fixed transfer amounts, transfer messages, payment collection, transaction confirmation, or payout execution.
- Store generated QR bitmap files on the backend.
- Resolve or archive the separate unfinished OpenSpec changes beyond documenting the dependency and conflict.

## Decisions

### 1. Embed the existing payroll summary audit in the employee detail tab

Rename the placeholder `Lịch sử` tab to `Chấm công` for users with employee-attendance permission. The tab will request `GET /hr/reports/payroll-summary?month=<YYYY-MM>&user_id=<id>` through the existing family provider keyed by `(month, userId)` and adapt `EmployeeWorkingDaysDetailView` so its calendar/day-detail body can be embedded as well as opened in a dialog.

This source already owns payroll-cycle boundaries, availability states, completed same-day rules, Saturday weighting, attendance audit rows, and leave-order overlap. Using `GET /hr/attendance` instead would require widening its admin-only authorization and rebuilding payroll semantics in Flutter.

Alternative considered: add an employee-specific raw attendance endpoint and compute summary cards in Flutter. Rejected because it would duplicate the calculation that the payroll export must match and could regress `unmapped` versus genuine-zero behavior.

### 2. Use explicit HR permission helpers across layers

Backend checks will use a shared employee-attendance/employee-management predicate that recognizes `admin`, `manager`, and the configured HR-manager role. Route decorators and service-level checks must not disagree. Flutter tab visibility will use the corresponding existing HR role utility. Employees may use self endpoints for payment details but may not use those endpoints to access another user.

Attendance remains restricted to HR roles in this employee-directory feature. The existing self attendance screens remain the employee-facing source.

Alternative considered: make the employee-detail attendance tab visible to every user for themselves. Rejected for this change because the request is scoped to HR employee administration and the app already has a self attendance history.

### 3. Extend `employee_profiles` with additive payment fields

Add nullable columns:

- `bank_code` for a stable bank identifier used by the QR registry;
- `bank_account_name` for display and HR verification;
- `bank_qr_image_url` for an optional custom upload;
- `bank_qr_source` constrained to `generated` or `uploaded`, nullable for legacy profiles.

Keep `bank_name` and `bank_account_number` intact. When a supported bank is selected, clients send both its stable code and display name. Legacy free-text rows remain readable; they do not generate a QR until a supported code is selected. A response view should normalize an impossible source combination—for example `uploaded` without a URL—to the usable source or no preview rather than emitting a broken image.

Alternative considered: put QR metadata on the `users` table. Rejected because payment data belongs to the HR employee profile and already follows its self-or-HR access policy.

### 4. Generate VietQR payloads locally from a versioned bank registry

Ship a project-owned, versioned registry of supported Vietnamese banks mapping stable code to display name and VietQR/NAPAS participant identifier. Generate the EMVCo/VietQR recipient payload in Dart and render it using a maintained Flutter QR widget dependency. The generated payload includes bank and account identity but no amount or transfer message. Generation therefore works offline and does not disclose account information to a third-party QR image endpoint.

The QR encoder and CRC/payload builder will have deterministic unit vectors. The bank registry should be isolated behind a small data/service abstraction so it can be updated without changing profile contracts.

Alternative considered: use a hosted VietQR image URL. Rejected because it creates a runtime availability/privacy dependency and makes offline preview impossible. Alternative considered: generate a plain-text QR. Rejected because banking apps need a VietQR-compatible transfer payload.

### 5. Manage custom QR images through dedicated profile endpoints

Add self and HR-targeted authenticated multipart/delete actions, following the avatar upload pattern but storing files under `uploads/hr/payment-qr`. Accepted MIME types are JPEG, PNG, and WebP with a 5 MiB limit and server-generated filenames. Uploading saves the URL and atomically selects `uploaded`; removal clears the URL and selects `generated`. Replacing/removing makes a best-effort deletion of the prior local file after database success, restricted to the managed upload directory.

Switching source without deleting the upload is a profile metadata update so a user can return to a saved custom image. The service validates that `uploaded` has an image and `generated` has supported bank details. The regular JSON profile update remains responsible for bank fields and source selection; the upload endpoint handles only file persistence and the upload-source transition.

Alternative considered: send base64 images in the profile update DTO. Rejected due to payload size, validation, caching, and existing multipart conventions.

### 6. Treat bank changes and custom QR selection as an explicit UX decision

The profile editor will split payment fields into a dedicated responsive card. Selecting a bank uses the supported registry rather than a free-text field. When bank code/account number changes while `uploaded` is active, the editor presents a blocking confirmation to keep the custom image or switch to regenerated QR. This makes a potentially stale image visible without pretending the backend can validate its encoded recipient.

Upload mutations preserve the form controllers and current profile state on failure. Preview generation is debounced only for display responsiveness; the actual payload is derived deterministically from current normalized input.

Alternative considered: always discard the custom upload when bank details change. Rejected because users may intentionally upload a branded but still correct QR and deletion would be surprising. Alternative considered: silently keep it. Rejected because stale payment QR images are high-impact.

## Risks / Trade-offs

- [The bank registry becomes stale when institutions change identifiers] → Keep it versioned and isolated, cover participant mappings with tests, and show generated QR only for recognized entries.
- [A custom image can encode different payment details] → Label uploaded sources, warn on bank changes, allow immediate return to generated QR, and explicitly avoid claiming ownership validation.
- [Local upload storage can accumulate orphaned files] → Best-effort delete superseded files, constrain deletion to the managed directory, and log cleanup failures without rolling back a successful profile update.
- [Attendance UI can diverge from payroll if raw records are reused] → Consume only the existing payroll-summary contract and reuse its typed audit presentation.
- [Role UUID/name handling can produce UI/API mismatches] → Centralize predicates and add controller/service tests for admin, manager, configured HR manager, employee self, and unauthorized cross-user access.
- [Five horizontal employee tabs can overflow on narrow devices] → Replace the unused placeholder rather than add a fifth tab; keep the tab row responsive and test narrow widths.
- [Generated QR correctness is safety-sensitive] → Add published/deterministic payload test vectors, CRC tests, and manual scans with multiple Vietnamese banking apps before release.
- [Payment data is sensitive] → Continue using authenticated profile endpoints, avoid public directory exposure, never log full account numbers or QR payloads, and return payment fields only through self-or-HR employee detail responses.

## Migration Plan

1. Complete and verify the required payroll-summary work from `fix-employee-dropdown-and-working-days`; do not apply the conflicting calculation from `hr-working-days-display` to this feature.
2. Deploy a backward-compatible migration adding nullable payment columns and the QR-source constraint/default behavior.
3. Deploy backend DTO/service/controller authorization and custom-image endpoints while old Flutter clients continue using existing bank fields.
4. Deploy Flutter bank registry, VietQR payload tests/rendering, payment editor/upload flow, and embedded employee attendance tab.
5. Validate role matrices, legacy profiles, upload/replace/remove behavior, generated QR scans, unavailable Odoo state, and payroll UI/export parity.
6. Roll back Flutter independently if needed. Backend rollback first removes new clients, then removes uploaded files/metadata only after confirming no active client depends on them; existing bank name/account values remain untouched.

## Open Questions

None blocking. The design assumes generated QR has no amount or message, user-uploaded images are not decoded for semantic validation, and the configured HR-manager role has the same employee-attendance and on-behalf payment-management permission as admin and manager.
