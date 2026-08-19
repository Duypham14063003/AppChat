## ADDED Requirements

### Requirement: Employee profiles store normalized payment details
An employee payment profile SHALL support a normalized bank code, bank display name, account number, and account-holder name. New payment fields SHALL be nullable so profiles created before this capability remain readable, and the system SHALL preserve existing bank name and account number values during migration.

#### Scenario: Existing profile is read after migration
- **WHEN** an existing employee profile contains only a bank name and account number
- **THEN** the system SHALL return those values without requiring a bank code, account-holder name, or QR selection

#### Scenario: Supported bank is selected
- **WHEN** an editor selects a supported bank from the bank registry
- **THEN** the profile SHALL store its stable bank code and display name rather than relying only on free-text identification

### Requirement: Employees and HR can manage authorized payment profiles
An employee SHALL be allowed to read and update their own bank code, bank name, account number, account-holder name, and QR selection. Administrators, managers, and the configured HR-manager role SHALL be allowed to manage those fields for an employee. Other users SHALL NOT read or mutate another employee's payment profile.

#### Scenario: Employee updates own bank details
- **WHEN** an authenticated employee submits valid payment details for their own profile
- **THEN** the system SHALL save the allowed payment fields without granting access to other protected HR fields

#### Scenario: HR updates employee bank details
- **WHEN** an administrator, manager, or configured HR manager submits valid payment details for an employee
- **THEN** the system SHALL save the details and record the acting user through the existing profile audit field

#### Scenario: User targets another employee
- **WHEN** a user without employee-management permission attempts to read or update another employee's payment details or QR image
- **THEN** the system SHALL reject the request

### Requirement: The app generates a VietQR-compatible transfer QR
When a profile has a supported bank code and a non-empty account number, the app SHALL generate a VietQR-compatible transfer QR payload and preview without requiring a runtime request to a third-party QR image service. The generated QR SHALL identify the beneficiary bank and account and SHALL omit a fixed amount and transfer message unless a future capability adds them.

#### Scenario: Complete supported bank details are entered
- **WHEN** an editor provides a supported bank code and valid account number
- **THEN** the app SHALL display a scannable generated transfer QR preview for those details

#### Scenario: Details are incomplete or unsupported
- **WHEN** the bank code is unsupported or the account number is empty
- **THEN** the app SHALL withhold the generated QR and explain which payment detail must be corrected

#### Scenario: Generated QR is viewed offline
- **WHEN** the device has the bank registry and payment details but no network connection
- **THEN** the app SHALL still be able to render the generated QR preview

### Requirement: Authorized users can manage a custom QR image
An employee SHALL be able to upload, replace, and remove a custom QR image for their own profile, and authorized HR users SHALL have the same actions for an employee. Upload endpoints SHALL accept only JPEG, PNG, or WebP images up to 5 MiB, use server-generated filenames, and persist the resulting URL in the employee profile.

#### Scenario: Employee uploads a valid image
- **WHEN** an employee uploads a valid supported image no larger than 5 MiB for their own profile
- **THEN** the system SHALL store the image under the authenticated employee QR upload area, save its URL, and select the uploaded QR as the active source

#### Scenario: Invalid image is uploaded
- **WHEN** an upload has an unsupported media type, exceeds 5 MiB, or contains no file
- **THEN** the system SHALL reject it without replacing the current QR image or source

#### Scenario: Custom QR is replaced
- **WHEN** an authorized editor uploads a replacement for an existing custom QR image
- **THEN** the system SHALL select the replacement and SHALL make a best-effort attempt to remove the superseded local file

#### Scenario: Custom QR is removed
- **WHEN** an authorized editor removes the custom QR image
- **THEN** the system SHALL clear its stored URL, make a best-effort attempt to remove the local file, and select the generated source

### Requirement: Editors control the active QR source
The payment profile SHALL record whether the displayed QR source is `generated` or `uploaded`. An uploaded source SHALL be selectable only while a custom image URL exists, and a generated source SHALL be usable only while supported bank details are complete. The UI SHALL identify the active source and allow an authorized editor to switch sources.

#### Scenario: Uploaded QR is active
- **WHEN** a profile has a custom QR image and its selected source is `uploaded`
- **THEN** employee profile views SHALL display that image as the primary QR and identify it as user-uploaded

#### Scenario: Editor returns to generated QR
- **WHEN** an authorized editor selects `generated` and valid supported bank details exist
- **THEN** the profile SHALL retain the optional custom image but display the generated transfer QR as active

#### Scenario: Bank details change while uploaded QR is active
- **WHEN** an editor changes the bank code or account number while a custom QR is active
- **THEN** the UI SHALL warn that the image may no longer match and require the editor to explicitly keep the uploaded source or switch to the regenerated source before saving

### Requirement: Payment QR UI is responsive and resilient
The employee HR profile editor SHALL present payment details and QR controls as a distinct payment section on mobile and wide layouts. It SHALL show generation, upload, success, validation, failure, preview, replace, remove, and retry states without discarding unsaved text fields after a recoverable QR operation error.

#### Scenario: QR upload fails
- **WHEN** an otherwise valid QR upload fails because of a recoverable server or network error
- **THEN** the editor SHALL retain entered payment details, keep the existing QR selection, and allow retry

#### Scenario: QR preview is opened
- **WHEN** a user activates the QR preview
- **THEN** the app SHALL show a readable enlarged preview while preserving the current profile-editing state

