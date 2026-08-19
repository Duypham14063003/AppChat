## ADDED Requirements

### Requirement: Contract action reminders use contract-type thresholds
The system SHALL evaluate active employee contracts with an `end_date` and send action reminders according to the contract type: internship and probation contracts 7 days before `end_date`, official contracts 10 days before `end_date`, and no reminders for temporary contracts.

#### Scenario: Internship contract reaches one-week threshold
- **WHEN** an active internship contract has `end_date` exactly 7 days after the reminder processing date
- **THEN** the system sends a contract action reminder for proposing an official contract

#### Scenario: Probation contract reaches one-week threshold
- **WHEN** an active probation contract has `end_date` exactly 7 days after the reminder processing date
- **THEN** the system sends a contract action reminder for proposing an official contract

#### Scenario: Official contract reaches ten-day threshold
- **WHEN** an active official contract has `end_date` exactly 10 days after the reminder processing date
- **THEN** the system sends a contract action reminder for proposing contract renewal

#### Scenario: Temporary contract is ignored
- **WHEN** an active temporary contract has an `end_date` exactly 7 or 10 days after the reminder processing date
- **THEN** the system does not send a contract action reminder for that contract

### Requirement: Contract action reminders target admin and manager role names only
The system SHALL send contract action reminders only to active users whose role name is `admin` or `manager`, matched case-insensitively.

#### Scenario: Admin and manager users receive reminders
- **WHEN** contract action reminder recipients are resolved
- **THEN** active users with role names `admin` or `manager` are included

#### Scenario: Other HR roles are excluded
- **WHEN** an active user has an HR-related role id but the role name is not `admin` or `manager`
- **THEN** that user is not included as a contract action reminder recipient

#### Scenario: Inactive users are excluded
- **WHEN** a user has role name `admin` or `manager` but is inactive
- **THEN** that user is not included as a contract action reminder recipient

### Requirement: Contract action reminder notifications expose action semantics
The system SHALL include action-specific notification title/body copy and payload data that distinguishes official-contract proposal reminders from renewal proposal reminders.

#### Scenario: Official-contract proposal reminder payload
- **WHEN** an internship or probation contract action reminder is sent
- **THEN** the notification payload includes `type` equal to `hr_contract_action_reminder`, `action` equal to `propose_official_contract`, the contract id, and the employee user id

#### Scenario: Renewal proposal reminder payload
- **WHEN** an official contract action reminder is sent
- **THEN** the notification payload includes `type` equal to `hr_contract_action_reminder`, `action` equal to `propose_contract_renewal`, the contract id, and the employee user id

### Requirement: Contract action reminders are not duplicated
The system SHALL deliver at most one reminder event for the same contract id, threshold day count, and reminder processing date.

#### Scenario: Existing reminder event suppresses duplicate delivery
- **WHEN** a reminder event already exists for a contract id, threshold day count, and reminder processing date
- **THEN** the system does not send another notification for that same reminder
