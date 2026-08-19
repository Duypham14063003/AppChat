## Why

The Profile tab (index 3 in bottom nav) is empty — no screens, no backend endpoint. Users need to see their profile info (from Odoo) and access app settings. The app currently only supports dark theme (hardcoded `AppTheme.dark`). Users want dark/light mode toggle, which is standard in modern apps. The SRS defines PROF-FR-001 (view profile) and PROF-FR-007 (app settings) as P0 MUST.

## What Changes

Backend (NestJS — minimal):
- Add `GET /profile/me` endpoint to `ProfileModule` returning current user's data (name, email, department, job_title, avatar_url, online status) from existing User entity. No new tables needed.

Frontend (Flutter — build from empty profile/ and settings/ directories):
- ProfileScreen: avatar, name, email, department, job_title, online status, logout button
- SettingsScreen: theme toggle (dark/light/system), notification on/off, sound on/off, font size, language (VI/EN), app version
- Dark/Light mode: create `AppTheme.light` ThemeData, `AppColorScheme` context-aware color helper, `ThemeMode` Riverpod provider with SharedPreferences persistence
- Refactor `App.dart` to use `theme` + `darkTheme` + `themeMode` from provider
- Settings persisted locally via SharedPreferences (no server-side storage)

## Capabilities

### New Capabilities
- `user-profile-screen`: Profile screen showing user info from backend — avatar, name, email, department, job_title, online status, logout action
- `app-settings-screen`: Settings screen with toggles and dropdowns — theme mode, notifications, sound, font size, language, app version display
- `dark-light-theme`: Full dark/light mode support — AppTheme.light, AppColorScheme context helper, ThemeMode provider with SharedPreferences persistence, gradual migration from hardcoded AppColors

### Modified Capabilities
<!-- No existing spec-level requirements are changing. -->

## Impact

- **Backend**: `ProfileModule` populated with controller returning user data. No new tables.
- **Flutter theme**: New `AppTheme.light`, new `AppColorsLight` class, new `AppColorScheme` context extension. `App.dart` refactored to support theme switching. Existing widgets using `AppColors.xxx` directly continue to work (dark is default).
- **Flutter screens**: New ProfileScreen, SettingsScreen in `features/profile/` and `features/settings/`.
- **Flutter storage**: SharedPreferences for theme mode, notification/sound toggles, font size, language preference.
- **Navigation**: Profile tab wired to ProfileScreen, gear icon navigates to SettingsScreen.

