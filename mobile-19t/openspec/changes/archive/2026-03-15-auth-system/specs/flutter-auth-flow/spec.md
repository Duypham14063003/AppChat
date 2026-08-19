## ADDED Requirements

### Requirement: Login screen with email and password form
The Flutter app SHALL display a login screen with email input, password input (obscured), and a login button. The screen SHALL show the Nineteen Tech logo and use the brand dark theme with gold accent.

#### Scenario: User enters credentials and logs in
- **WHEN** user enters valid email and password and taps Login
- **THEN** a loading indicator is shown, the app calls `POST /auth/login`, stores tokens securely, and navigates to the home screen

#### Scenario: Login error is displayed
- **WHEN** the login API returns an error (401, 403, 503)
- **THEN** the error message from the API is displayed on the login screen

#### Scenario: Empty fields show validation error
- **WHEN** user taps Login with empty email or password
- **THEN** inline validation errors are shown ("Email không được để trống", "Mật khẩu không được để trống")

### Requirement: Tokens stored in platform-specific secure storage
The Flutter app SHALL store JWT access token and refresh token using `flutter_secure_storage`, which uses Keychain on iOS, Keystore on Android, and encrypted file on Windows/macOS.

#### Scenario: Tokens persisted after login
- **WHEN** login succeeds
- **THEN** access token and refresh token are stored in secure storage and survive app restart

#### Scenario: Tokens cleared on logout
- **WHEN** user logs out
- **THEN** both tokens are removed from secure storage

### Requirement: Dio interceptor auto-refreshes expired tokens
The Flutter app SHALL configure a Dio interceptor that detects 401 responses, automatically calls `POST /auth/refresh` with the stored refresh token, updates stored tokens, and retries the original request. If refresh fails, the app SHALL navigate to the login screen.

#### Scenario: Expired access token triggers auto-refresh
- **WHEN** an API call returns 401 and a valid refresh token exists in storage
- **THEN** the interceptor calls `/auth/refresh`, stores new tokens, and retries the original request transparently

#### Scenario: Concurrent requests during refresh are queued
- **WHEN** multiple API calls return 401 simultaneously
- **THEN** only one refresh request is made, and all pending requests are retried with the new token

#### Scenario: Refresh failure navigates to login
- **WHEN** the refresh call itself returns 401 (refresh token expired)
- **THEN** the app clears stored tokens and navigates to the login screen

### Requirement: Auto-login on app start
The Flutter app SHALL check for a stored refresh token on startup. If found, the app SHALL attempt to refresh the access token silently. On success, navigate to home. On failure, show the login screen.

#### Scenario: Auto-login succeeds with valid refresh token
- **WHEN** app starts and a valid refresh token exists in secure storage
- **THEN** the app refreshes the access token silently and navigates to the home screen without showing the login form

#### Scenario: Auto-login fails with expired refresh token
- **WHEN** app starts and the stored refresh token is expired
- **THEN** the app shows the login screen

#### Scenario: First launch with no stored tokens
- **WHEN** app starts for the first time with no tokens in storage
- **THEN** the app shows the login screen

