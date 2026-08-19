## Context

The app ships with a single dark theme using a gold accent color defined as static `const` values in `AppColors`. Every component in the app references these constants directly, making it impossible to switch themes at runtime without a significant refactor.

Key constraints:
- Must work offline and locally — no backend involvement.
- Theme changes must be immediate with smooth transition.
- No changes to existing data models or API contracts.
- Cross-platform: mobile + web.

## Goals / Non-Goals

**Goals:**
- Allow users to select from 5 color presets via a Settings screen.
- Persist the selected preset to `SharedPreferences` per device.
- Rebuild the entire app's theme on selection change with an animated transition.
- Replace all hardcoded `AppColors.gold` references with a dynamic active accent.
- Add Settings navigation from the Profile screen.

**Non-Goals:**
- Server-side theme sync (local-only storage).
- Custom theme builder (only curated presets, no free-form color picker).
- Light/dark mode toggle separate from presets (presets include both dark and light schemes).
- Changing font family or typography.

## Decisions

### 1. Preset structure: `AppColorPreset` dataclass per theme

Each preset is a plain Dart class holding all color values for that theme. No inheritance or dynamic computation — just static data.

**Rationale**: Simple, predictable, no runtime complexity. Easy to add new presets by adding a new instance. Flutter's `ThemeData` is rebuilt from the preset data at app start and on change.

**Alternatives considered**:
- *Dynamic color calculation* (e.g., generate dark/light variants from a single hue): Over-engineered for a curated preset system.
- *Theme inheritance* (base dark theme + accent overlay): Harder to ensure full coverage across all surface layers.

### 2. Theme provider: `AsyncNotifier<ThemeState>` via Riverpod

`ThemeNotifier` manages:
1. Loading saved preset ID from `SharedPreferences` on init.
2. Persisting new preset ID on user selection.
3. Exposing `ThemeData` derived from the active preset.

**Rationale**: `AsyncNotifier` handles the async initialization (loading from storage) cleanly, and Riverpod's `ref.watch` automatically triggers UI rebuilds when the theme changes. This integrates cleanly with the existing `flutter_riverpod` setup in `app.dart`.

**Alternatives considered**:
- *StateNotifier with separate loading state*: More boilerplate for the same outcome.
- *ChangeNotifier*: Less idiomatic for Riverpod 2 with code generation.

### 3. Accent color propagation: `AppColors` becomes a computed proxy

`AppColors` will expose static getters that delegate to the active preset. Instead of `AppColors.gold`, components use `AppColors.primary` — which reads from the current preset. This minimizes the number of files that need to change.

**Rationale**: Minimizes refactoring. Only `AppColors` needs to change; individual screens/widgets continue using `AppColors.*` as before.

**Alternatives considered**:
- *Inject color into every widget via Provider*: Too invasive — would require changing every widget's API.
- *Create a `ThemeColors.of(context)` context accessor*: Forces `context.read()` calls everywhere. Overkill for static color access.

### 4. Storage: `shared_preferences` package

`SharedPreferences` is the standard Flutter package for app preferences. It's cross-platform, has a simple key-value API, and is appropriate for storing a single preset ID.

**Rationale**: No security requirements for theme data. Lightweight. No need for encrypted storage.

**Alternatives considered**:
- *Drift/SQLite*: Overkill for a single key-value pair.
- *flutter_secure_storage*: Not needed — theme data is not sensitive.

### 5. Settings screen: standalone `/settings` route

The Settings screen is a new route pushed from the AccountScreen. It is not a tab — it's accessed via a settings icon in the AccountScreen's AppBar.

**Rationale**: Settings is a separate concern from Profile (account info). A standalone route keeps concerns separated and makes it easy to extend Settings with more options later (notification preferences, language, etc.).

**Alternatives considered**:
- *Bottom tab (5 tabs)*: Too many tabs for a ~50-employee internal app. Settings is accessed less frequently than Chat/HR/Tasks.
- *Section within AccountScreen*: Settings would compete for space with account info. A dedicated screen is cleaner.

### 6. Animated transition: `AnimatedTheme` wrapper in `app.dart`

`app.dart` wraps the `MaterialApp.router` in an `AnimatedTheme` widget. When `ThemeNotifier` emits a new `ThemeData`, the wrapper animates the color change over 300ms.

**Rationale**: Simple, built-in Flutter widget. No external animation library needed. The transition is purely cosmetic — it makes the theme switch feel intentional rather than jarring.

**Alternatives considered**:
- *Custom animation with `AnimatedContainer` / `TweenAnimationBuilder`*: More control but more code for the same outcome.
- *No animation*: Jarring instant swap. Bad UX.

### 7. Navigation to Settings: AppBar action on AccountScreen

The AccountScreen gets a simple `AppBar` with a settings gear icon (`Icons.settings_outlined`) in the top-right. Tapping it pushes `/settings`.

**Rationale**: Standard pattern for settings access in mobile apps. The gear icon is universally understood. It keeps AccountScreen focused while making Settings discoverable.

## Risks / Trade-offs

- **[Risk] All components hardcode `AppColors.gold`** → **Mitigation**: A grep search identifies every usage. Replace `AppColors.gold` with `AppColors.primary` in `AppColors` and all usages remain compatible.
- **[Risk] Hard to know if a new file uses hardcoded color** → **Mitigation**: Add a Riverpod lint rule or mark `AppColors.gold` as `@Deprecated` to prevent future hardcoding.
- **[Risk] Dark mode toggle vs. preset conflict** → **Mitigation**: Presets explicitly include dark/light distinction (e.g., `white_light` is a light theme). No separate dark mode toggle.

## Migration Plan

1. Add `shared_preferences` to `pubspec.yaml`.
2. Create `core/storage/preferences_storage.dart`.
3. Create `core/theme/theme_presets.dart` with all 5 presets.
4. Update `core/theme/app_colors.dart` to expose computed primary/surface/text from active preset.
5. Update `core/theme/app_theme.dart` to accept a preset and build `ThemeData`.
6. Create `core/providers/theme_provider.dart`.
7. Update `app.dart` to wrap `MaterialApp` in `AnimatedTheme` and watch the theme provider.
8. Update `core/router/app_router.dart` to add `/settings` route.
9. Create `features/settings/screens/settings_screen.dart`.
10. Update `core/router/main_shell.dart` to use `AppColors.primary` (dynamic) instead of hardcoded gold.
11. Update `features/profile/screens/account_screen.dart` to add AppBar with settings icon.
12. Run `flutter pub get` + `flutter analyze` to verify.

**Rollback**: Revert to pre-change `AppColors` and remove the animated wrapper. `SharedPreferences` key is non-destructive — if the key is absent, fall back to the gold default.

## Open Questions

1. Should `senderColors` (the 8-color Telegram-style palette for group chat names) be per-preset or remain fixed? — **Decision**: Keep it fixed. It's a functional distinction, not an aesthetic one.
2. Should the app remember the last scroll position / conversation when switching themes? — **No**: theme switch is instantaneous and does not affect navigation state.