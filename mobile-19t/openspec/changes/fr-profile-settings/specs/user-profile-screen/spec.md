## ADDED Requirements

### Requirement: Profile API endpoint
The system SHALL expose `GET /profile/me` returning the authenticated user's full profile: id, name, email, department, job_title, avatar_url, is_active, last_seen_at, created_at. The endpoint SHALL use the JWT user ID to query the User entity.

#### Scenario: Fetch own profile
- **WHEN** an authenticated user sends GET /profile/me
- **THEN** the system returns their full profile data

### Requirement: Profile screen layout
The system SHALL provide a ProfileScreen at route `/profile` showing: large avatar (80px circle, fallback to initials if no avatar_url), user name (headlineMedium), job title (textSecondary), and info rows for email, department, job title, and online status (green dot if last_seen_at within 5 minutes).

#### Scenario: View own profile
- **WHEN** the user taps the Profile tab
- **THEN** the ProfileScreen displays their avatar, name, job title, email, department, and online status

#### Scenario: No avatar
- **WHEN** the user has no avatar_url
- **THEN** a circle with their initials on gold background is shown

### Requirement: Settings navigation from profile
The system SHALL display a gear icon (⚙️) in the ProfileScreen AppBar. Tapping it SHALL navigate to the SettingsScreen.

#### Scenario: Navigate to settings
- **WHEN** the user taps the gear icon on the profile screen
- **THEN** the SettingsScreen opens

### Requirement: Logout from profile
The system SHALL display a "Đăng xuất" button at the bottom of the ProfileScreen. Tapping it SHALL show a confirmation dialog. On confirm, the system SHALL call the existing logout flow (clear tokens, disconnect WebSocket, navigate to login).

#### Scenario: Logout confirmed
- **WHEN** the user taps "Đăng xuất" and confirms
- **THEN** the user is logged out and redirected to the login screen

#### Scenario: Logout cancelled
- **WHEN** the user taps "Đăng xuất" but cancels the dialog
- **THEN** nothing happens and the user stays on the profile screen

### Requirement: Profile data from auth state and API
The system SHALL display basic info (name, email) from the existing `authNotifierProvider` immediately. Full profile data (department, job_title, avatar_url) SHALL be fetched from `GET /profile/me` via a `profileProvider` and displayed when loaded.

#### Scenario: Fast initial display
- **WHEN** the user opens the profile screen
- **THEN** name and email appear immediately from JWT, and department/job_title load shortly after from API

