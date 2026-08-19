## ADDED Requirements

### Requirement: Settings screen layout
The system SHALL provide a SettingsScreen at route `/profile/settings` with grouped sections: "Giao diện" (theme mode, font size), "Thông báo" (notification toggle, sound toggle), "Ngôn ngữ" (language selector), "Thông tin" (app version). Each setting SHALL use appropriate controls (dropdown, toggle switch, or display-only).

#### Scenario: View settings
- **WHEN** the user opens the settings screen
- **THEN** all setting groups are displayed with current values

### Requirement: Theme mode setting
The system SHALL display a theme mode selector with three options: "Tối" (dark), "Sáng" (light), "Hệ thống" (system). The current selection SHALL be highlighted. Changing the selection SHALL immediately apply the theme and persist the choice.

#### Scenario: Switch to light mode
- **WHEN** the user selects "Sáng"
- **THEN** the app immediately switches to light theme and the preference is saved

#### Scenario: Switch to system mode
- **WHEN** the user selects "Hệ thống"
- **THEN** the app follows the OS dark/light preference

### Requirement: Notification toggle
The system SHALL display a switch for "Thông báo" (default: on). Toggling off SHALL disable push notifications by not registering FCM token on next app start. The preference SHALL be persisted in SharedPreferences.

#### Scenario: Disable notifications
- **WHEN** the user toggles notifications off
- **THEN** the preference is saved and push notifications are suppressed

### Requirement: Sound toggle
The system SHALL display a switch for "Âm thanh" (default: on). Toggling off SHALL mute notification sounds. The preference SHALL be persisted in SharedPreferences.

#### Scenario: Mute sounds
- **WHEN** the user toggles sound off
- **THEN** the preference is saved and notification sounds are muted

### Requirement: Font size setting
The system SHALL display a font size selector with three options: "Nhỏ" (0.85x), "Vừa" (1.0x, default), "Lớn" (1.15x). Changing font size SHALL apply a text scale factor to the app via `MediaQuery.textScalerOf`. The preference SHALL be persisted.

#### Scenario: Increase font size
- **WHEN** the user selects "Lớn"
- **THEN** all text in the app scales to 1.15x and the preference is saved

### Requirement: Language setting
The system SHALL display a language selector with two options: "Tiếng Việt" (default) and "English". The preference SHALL be persisted in SharedPreferences. Actual string translations are not implemented in this change — the toggle saves the preference for future i18n support.

#### Scenario: Select English
- **WHEN** the user selects "English"
- **THEN** the preference is saved (UI remains Vietnamese until i18n is implemented)

### Requirement: App version display
The system SHALL display the current app version (from package info) in the settings screen as a read-only info row.

#### Scenario: View version
- **WHEN** the user scrolls to the bottom of settings
- **THEN** the app version (e.g., "v1.0.0") is displayed

### Requirement: Settings persistence via SharedPreferences
All settings SHALL be persisted in SharedPreferences with keys: `theme_mode` (string: dark/light/system), `notifications_enabled` (bool), `sound_enabled` (bool), `font_size` (string: small/medium/large), `language` (string: vi/en). Settings SHALL be loaded on app start and applied before the first frame renders.

#### Scenario: Settings persist across restart
- **WHEN** the user changes theme to light and restarts the app
- **THEN** the app starts in light mode

