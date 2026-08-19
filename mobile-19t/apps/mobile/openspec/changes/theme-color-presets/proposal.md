## Why

The app currently ships with a single hardcoded dark theme using a gold accent color. Users who prefer a different visual mood have no way to personalize the interface. This change introduces a theme preset system that lets users choose from a curated palette of color schemes, with the selected preference persisted locally per device.

## What Changes

- Add `shared_preferences` dependency to persist user theme preference.
- Define 5 color presets (4 dark + 1 light), each with full accent, background, surface, and text color sets.
- Create a `ThemeNotifier` (Riverpod `AsyncNotifier`) that loads/saves the active preset ID to `SharedPreferences`.
- Update `AppTheme` to build `ThemeData` dynamically from a preset.
- Replace all hardcoded `AppColors.gold` references throughout the app with a dynamic accent color from the active preset.
- Add a standalone `/settings` route and `SettingsScreen` with a theme preset grid and live preview card.
- Add a settings navigation tile (with AppBar actions) to `AccountScreen`.
- Apply smooth animated theme transitions when the user switches presets.

## Capabilities

### New Capabilities

- `theme-presets`: Allows users to select a color preset from a predefined list. The selected preset is stored locally via `SharedPreferences` and applied immediately to the entire app's UI.

### Modified Capabilities

<!-- No existing spec capabilities are modified. -->

## Impact

- **New dependency**: `shared_preferences` — lightweight key-value storage for Flutter.
- **New files**: `core/theme/theme_presets.dart`, `core/providers/theme_provider.dart`, `core/storage/preferences_storage.dart`, `features/settings/screens/settings_screen.dart`.
- **Modified files**: `pubspec.yaml`, `app.dart`, `core/theme/app_theme.dart`, `core/theme/app_colors.dart`, `core/router/app_router.dart`, `core/router/main_shell.dart`, `features/profile/screens/account_screen.dart`.
- **User-facing**: New Settings screen accessible from the Profile screen. No backend changes required.
