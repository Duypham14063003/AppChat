## MODIFIED Requirements

### Requirement: Login screen with email and password form
The Flutter app SHALL display a login screen with email input, password input (obscured), and a login button. The screen SHALL show the Nineteen Tech logo and use the brand dark theme with gold accent.

#### Scenario: User enters credentials and logs in
- **WHEN** user enters valid email and password and taps Login
- **THEN** a loading indicator is shown, the app calls `POST /auth/login`, stores tokens securely, completes authenticated bootstrap checks, and only navigates to normal app use after required profile completion checks have passed

#### Scenario: Login error is displayed
- **WHEN** the login API returns an error (401, 403, 503)
- **THEN** the error message from the API is displayed on the login screen

#### Scenario: Empty fields show validation error
- **WHEN** user taps Login with empty email or password
- **THEN** inline validation errors are shown ("Email không được để trống", "Mật khẩu không được để trống")

### Requirement: Auto-login on app start
The Flutter app SHALL check for a stored refresh token on startup. If found, the app SHALL attempt to refresh the access token silently. On success, the app SHALL complete authenticated bootstrap checks before allowing normal app use. On failure, the app SHALL show the login screen.

#### Scenario: Auto-login succeeds with valid refresh token and complete profile
- **WHEN** app starts and a valid refresh token exists in secure storage
- **THEN** the app refreshes the access token silently, completes authenticated bootstrap checks, and navigates to the home screen without showing the login form

#### Scenario: Auto-login requires phone completion
- **WHEN** app starts, a valid refresh token exists in secure storage, and bootstrap config reports `phone_number` as null
- **THEN** the app keeps the user authenticated but blocks normal app use until the required phone number is submitted successfully

#### Scenario: Auto-login fails with expired refresh token
- **WHEN** app starts and the stored refresh token is expired
- **THEN** the app shows the login screen

#### Scenario: First launch with no stored tokens
- **WHEN** app starts for the first time with no tokens in storage
- **THEN** the app shows the login screen
