## 1. Backend: Profile Endpoint

- [ ] 1.1 Create `ProfileController` at `apps/api/src/modules/profile/profile.controller.ts` with `@Controller('profile')`
- [ ] 1.2 Add `GET /profile/me` endpoint: use `@CurrentUser('userId')` to get user ID from JWT, query User entity by ID, return { id, name, email, department, job_title, avatar_url, is_active, last_seen_at, created_at }
- [ ] 1.3 Update `ProfileModule`: import TypeOrmModule.forFeature([User]), AuthModule; register ProfileController
- [ ] 1.4 Verify ProfileModule is imported in AppModule

## 2. Flutter: Light Theme Colors

- [ ] 2.1 Create `AppColorsLight` class at `apps/mobile/lib/core/theme/app_colors_light.dart` with light palette: background (#F5F5F0), surface (#FFFFFF), surfaceVariant (#EEEEE8), card (#FFFFFF), textPrimary (#1A1A1A), textSecondary (#6B6B60), textHint (#9E9E95), bubbleMine (#FFF8E1). Gold and semantic colors same as AppColors.
- [ ] 2.2 Create `AppTheme.light` getter in `app_theme.dart`: ThemeData with Brightness.light, ColorScheme.light using AppColorsLight, AppBarTheme, CardTheme (with elevation for light), TextTheme, InputDecorationTheme — all using AppColorsLight values

## 3. Flutter: AppColorScheme Context Helper

- [ ] 3.1 Create `AppColorScheme` class at `apps/mobile/lib/core/theme/app_color_scheme.dart` with all color properties (background, surface, surfaceVariant, card, textPrimary, textSecondary, textHint, bubbleMine, gold, goldLight, goldDark, online, danger, warning, info)
- [ ] 3.2 Add static `of(BuildContext context)` method: check `Theme.of(context).brightness`, return dark colors (AppColors) or light colors (AppColorsLight) accordingly
- [ ] 3.3 Add BuildContext extension for convenience: `context.colors` → `AppColorScheme.of(context)`

## 4. Flutter: Theme & Settings Providers

- [ ] 4.1 Create `SettingsService` at `apps/mobile/lib/core/storage/settings_service.dart`: wrapper around SharedPreferences for typed read/write of all settings keys (theme_mode, notifications_enabled, sound_enabled, font_size, language)
- [ ] 4.2 Create `themeModeProvider` StateNotifierProvider at `apps/mobile/lib/core/providers/theme_provider.dart`: reads initial ThemeMode from SettingsService, exposes `setThemeMode(ThemeMode)` that updates state + persists
- [ ] 4.3 Create `fontScaleProvider` StateNotifierProvider: reads initial scale (0.85/1.0/1.15) from SettingsService, exposes `setFontScale(double)`
- [ ] 4.4 Create `notificationEnabledProvider` and `soundEnabledProvider` StateNotifierProviders: bool toggles with persistence
- [ ] 4.5 Create `languageProvider` StateNotifierProvider: string (vi/en) with persistence
- [ ] 4.6 Initialize SettingsService in main entry points (before runApp): `await SettingsService.init()`

## 5. Flutter: Refactor App.dart

- [ ] 5.1 Update `App.dart`: change `theme: AppTheme.dark` to `theme: AppTheme.light, darkTheme: AppTheme.dark, themeMode: ref.watch(themeModeProvider)`
- [ ] 5.2 Wrap `MaterialApp.router` with `MediaQuery` override for font scale: `MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(ref.watch(fontScaleProvider))), child: ...)`
- [ ] 5.3 Verify app starts correctly with default dark theme

## 6. Flutter: Migrate Critical Widgets

- [ ] 6.1 Migrate `MainShell` (main_shell.dart): replace hardcoded `AppColors.surface`, `AppColors.textSecondary`, `AppColors.gold` with `context.colors.surface`, etc. for NavigationBar and NavigationRail
- [ ] 6.2 Migrate `ChatListScreen`: replace AppColors references with context.colors for background, text, dividers
- [ ] 6.3 Migrate `MessageInputBar`: replace AppColors for surface, text field fill, hint text, send icon
- [ ] 6.4 Migrate chat bubble colors in message rendering widgets: bubbleMine, text colors
- [ ] 6.5 Test: toggle theme → verify navigation, chat list, chat screen render correctly in both modes

## 7. Flutter: Profile Screen

- [ ] 7.1 Create `ProfileRepository` at `apps/mobile/lib/features/profile/data/profile_repository.dart`: `getProfile()` → GET /profile/me, return typed `UserProfile` model
- [ ] 7.2 Create `profileProvider` AsyncNotifier at `apps/mobile/lib/features/profile/providers/profile_providers.dart`: fetch profile from API, expose refresh
- [ ] 7.3 Create `ProfileScreen` at `apps/mobile/lib/features/profile/screens/profile_screen.dart`: AppBar with "Profile" title + gear icon (→ settings), large avatar circle (80px, initials fallback on gold bg), name (headlineMedium), job title (textSecondary), info rows (email, department, job title, online status with green dot), logout button at bottom (danger color, confirmation dialog)
- [ ] 7.4 Wire logout button: call `ref.read(authNotifierProvider.notifier).logout()` on confirm
- [ ] 7.5 Use `context.colors` throughout for theme-aware rendering

## 8. Flutter: Settings Screen

- [ ] 8.1 Create `SettingsScreen` at `apps/mobile/lib/features/settings/screens/settings_screen.dart`: AppBar with "Cài đặt" title, grouped ListTile sections
- [ ] 8.2 Theme mode section: SegmentedButton or DropdownButton with 3 options (Tối/Sáng/Hệ thống), reads/writes themeModeProvider
- [ ] 8.3 Font size section: SegmentedButton with 3 options (Nhỏ/Vừa/Lớn), reads/writes fontScaleProvider
- [ ] 8.4 Notification toggle: SwitchListTile, reads/writes notificationEnabledProvider
- [ ] 8.5 Sound toggle: SwitchListTile, reads/writes soundEnabledProvider
- [ ] 8.6 Language selector: ListTile with trailing dropdown (Tiếng Việt / English), reads/writes languageProvider
- [ ] 8.7 App version row: ListTile with trailing text showing version from package_info_plus (or hardcoded for now)
- [ ] 8.8 Use `context.colors` throughout

## 9. Flutter: Navigation

- [ ] 9.1 Add GoRouter route `/profile` → ProfileScreen
- [ ] 9.2 Add GoRouter route `/profile/settings` → SettingsScreen
- [ ] 9.3 Verify Profile tab in bottom nav navigates to ProfileScreen
- [ ] 9.4 Verify gear icon in ProfileScreen navigates to SettingsScreen

## 10. Verification

- [ ] 10.1 Run `npm run lint` in apps/api — fix issues
- [ ] 10.2 Run `npm run build` in apps/api — fix TypeScript errors
- [ ] 10.3 Run `flutter analyze` in apps/mobile — fix issues
- [ ] 10.4 Test dark mode: verify all screens render correctly (default)
- [ ] 10.5 Test light mode: toggle to light → verify profile, settings, chat list, chat screen, navigation all render with light colors
- [ ] 10.6 Test system mode: toggle to system → verify follows OS preference
- [ ] 10.7 Test persistence: change theme to light → restart app → verify starts in light mode
- [ ] 10.8 Test font scale: change to large → verify text scales across all screens
- [ ] 10.9 Test profile: verify name, email, department, job_title display correctly
- [ ] 10.10 Test logout: tap logout → confirm → verify redirected to login

