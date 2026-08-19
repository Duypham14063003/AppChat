## ADDED Requirements

### Requirement: Authenticated bootstrap config is loaded for the current user
The system SHALL provide an authenticated bootstrap config fetch for the current user via `GET /api/v1/config`. The Flutter app SHALL call this endpoint after successful interactive login and after refresh-based authenticated startup before normal app use is considered ready.

#### Scenario: Config returns phone number
- **WHEN** the authenticated app calls `GET /api/v1/config` and the backend returns `{ "phone_number": "0901234567" }`
- **THEN** the app marks bootstrap config as satisfied and allows normal app use

#### Scenario: Config returns missing phone number
- **WHEN** the authenticated app calls `GET /api/v1/config` and the backend returns `{ "phone_number": null }`
- **THEN** the app marks phone-number completion as required and blocks normal app use until the user saves a phone number successfully

### Requirement: Missing phone number is collected through a blocking completion prompt
The Flutter app SHALL present a mandatory completion prompt when bootstrap config reports `phone_number` as null. The prompt SHALL explain that a phone number is required, collect the value, and prevent dismissal into the normal app until completion succeeds.

#### Scenario: User submits a valid phone number
- **WHEN** the blocking prompt is shown and the user enters a valid phone number
- **THEN** the app submits the update through the current-user profile update flow, closes the prompt after success, and resumes normal app use

#### Scenario: Phone number update fails
- **WHEN** the user submits the blocking prompt and the update request fails
- **THEN** the prompt remains open, the app shows an actionable error, and the user can retry without being logged out

### Requirement: Saved phone number is reflected in the current user profile
The Flutter app SHALL keep the current user model and profile UI consistent with the saved phone number after the bootstrap completion flow succeeds.

#### Scenario: Profile reflects newly saved phone number
- **WHEN** the user saves a phone number from the blocking completion prompt
- **THEN** the in-memory authenticated user state and profile UI both show the saved phone number without requiring a fresh login
