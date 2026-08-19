## MODIFIED Requirements

### Requirement: Login screen with email and password form
The Flutter app SHALL display a login screen with email input, password input (obscured), and a login button. The screen SHALL show the Nineteen Tech logo, use the brand dark theme with gold accent, and expose the email/password fields to supported OS credential autofill services.

#### Scenario: User enters credentials and logs in
- **WHEN** user enters valid email and password and taps Login
- **THEN** a loading indicator is shown, the app calls `POST /auth/login`, stores tokens securely, and navigates to the home screen

#### Scenario: User selects autofilled credentials and logs in
- **WHEN** the login screen receives valid autofilled email/password credentials from a supported password manager and the user submits login
- **THEN** the app authenticates with the same `POST /auth/login` flow used for manually entered credentials

#### Scenario: Login error is displayed
- **WHEN** the login API returns an error (401, 403, 503)
- **THEN** the error message from the API is displayed on the login screen

#### Scenario: Empty fields show validation error
- **WHEN** user taps Login with empty email or password
- **THEN** inline validation errors are shown ("Email không được để trống", "Mật khẩu không được để trống")
