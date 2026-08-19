## 1. Infrastructure & Storage

- [ ] 1.1 Add `shared_preferences` dependency to `pubspec.yaml`
- [ ] 1.2 Create `core/storage/preferences_storage.dart` with `PreferencesStorage` class wrapping SharedPreferences
- [ ] 1.3 Add `getString`/`setString` methods for theme preset key (`color_preset_id`)
- [ ] 1.4 Add `clear()` method for logout cleanup

## 2. Theme Presets

- [ ] 2.1 Create `core/theme/theme_presets.dart` with `AppColorPreset` dataclass
- [ ] 2.2 Define `gold_dark` preset (current colors as baseline)
- [ ] 2.3 Define `blue_dark` preset (blue accent, dark background)
- [ ] 2.4 Define `green_dark` preset (green accent, dark background)
- [ ] 2.5 Define `red_dark` preset (red accent, dark background)
- [ ] 2.6 Define `white_light` preset (blue accent, light background)
- [ ] 2.7 Export `defaultPreset`, `allPresets` list, and `presetById` lookup

## 3. AppColors Refactor

- [ ] 3.1 Add `AppColors.active` static field that holds current preset's colors
- [ ] 3.2 Add `AppColors.setPreset(AppColorPreset preset)` method to update active colors
- [ ] 3.3 Add `AppColors.primary` getter that returns active primary color
- [ ] 3.4 Add `AppColors.primaryLight`, `AppColors.primaryDark` variants
- [ ] 3.5 Keep existing static constants (`goldLight`, `goldDark`, etc.) for named presets
- [ ] 3.6 Add `AppColors.surface`/`background`/`card` that read from active preset

## 4. Theme Provider

- [ ] 4.1 Create `core/providers/theme_provider.dart`
- [ ] 4.2 Define `ThemeState` class with `presetId`, `preset`, `themeData`
- [ ] 4.3 Create `ThemeNotifier extends AsyncNotifier<ThemeState>`
- [ ] 4.4 Implement `load()` to read preset ID from PreferencesStorage
- [ ] 4.5 Implement `selectPreset(String presetId)` to save and update state
- [ ] 4.6 Implement `refreshColors()` to update AppColors when preset changes
- [ ] 4.7 Create `themeProvider` public provider (auto-generated with riverpod_annotation)

## 5. App Theme Factory

- [ ] 5.1 Update `core/theme/app_theme.dart` to accept `AppColorPreset` parameter
- [ ] 5.2 Add `AppTheme.fromPreset(AppColorPreset preset)` factory method
- [ ] 5.3 Ensure all ColorScheme fields use preset values (primary, surface, etc.)
- [ ] 5.4 Keep existing dark theme structure, just parameterized

## 6. App Initialization

- [ ] 6.1 Update `app.dart` to initialize preferences storage before runApp
- [ ] 6.2 Wrap `MaterialApp.router` in `AnimatedTheme` widget
- [ ] 6.3 Watch `themeProvider` in App build method
- [ ] 6.4 Pass `theme` from provider to `AnimatedTheme.data`
- [ ] 6.5 Set animation duration to 300ms with ease-in-out curve

## 7. Navigation — Settings Route

- [ ] 7.1 Create `features/settings/screens/settings_screen.dart` stub
- [ ] 7.2 Update `core/router/app_router.dart` to add `/settings` route under ShellRoute
- [ ] 7.3 Import `SettingsScreen` in `app_router.dart`

## 8. Settings Screen Implementation

- [ ] 8.1 Build `_ThemeSection` widget with "Giao diện" title
- [ ] 8.2 Create `_PresetCard` widget: 120x100px card showing accent color block + name
- [ ] 8.3 Render preset grid with 3 columns, Wrap or GridView
- [ ] 8.4 Add checkmark overlay on selected preset card
- [ ] 8.5 Build `_PreviewCard` widget: shows full color palette of selected preset
  - Includes: primary swatch, surface swatch, background swatch, text colors
  - Styled as a mini theme card (like a login screen preview)
- [ ] 8.6 Wire up `onTap` on `_PresetCard` to call `themeProvider.selectPreset()`
- [ ] 8.7 Add `_InfoSection` with note: "Mỗi thiết bị chỉ lưu cài đặt cục bộ."
- [ ] 8.8 Apply responsive max-width (880px) for wide screens
- [ ] 8.9 Add AppBar with back button and title "Cài đặt"

## 9. Profile Screen — Settings Navigation

- [ ] 9.1 Update `features/profile/screens/account_screen.dart` with `AppBar`
- [ ] 9.2 Add settings gear icon (`Icons.settings_outlined`) in AppBar actions
- [ ] 9.3 On tap, call `context.push('/settings')`

## 10. Hardcoded Accent Fix — main_shell.dart

- [ ] 10.1 Replace hardcoded `AppColors.gold` in `NavigationRail` selected icon/indicator
- [ ] 10.2 Replace hardcoded `AppColors.gold` in `NavigationBar` selected icon/indicator
- [ ] 10.3 Use `AppColors.primary` (dynamic) for all accent references

## 11. Hardcoded Accent Fix — app_colors.dart

- [ ] 11.1 Update `AppColors` to dynamically compute `primary`/`surface`/`background` from active preset
- [ ] 11.2 Ensure all existing usages of `AppColors.gold` throughout the codebase work without changes

## 12. Verification

- [ ] 12.1 Run `flutter pub get` to fetch `shared_preferences`
- [ ] 12.2 Run `dart run build_runner build --delete-conflicting-outputs` for codegen
- [ ] 12.3 Run `flutter analyze` — fix any lint errors
- [ ] 12.4 Verify: switch preset → UI updates with smooth animation
- [ ] 12.5 Verify: restart app → preset persists
- [ ] 12.6 Verify: Settings screen accessible from Profile → AppBar icon