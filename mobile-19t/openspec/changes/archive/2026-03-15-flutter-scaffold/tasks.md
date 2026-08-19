## 1. Project Scaffold

- [x] 1.1 Run `flutter create` inside `apps/mobile/` with platforms: ios, android, windows, macos, web
- [x] 1.2 Create feature-based folder structure: `lib/features/` with 7 subdirectories (auth, chat, call, hr, task, profile, settings)
- [x] 1.3 Create core infrastructure directories: `lib/core/` with 5 subdirectories (theme, network, storage, router, providers) and `lib/shared/`

## 2. Dependencies

- [x] 2.1 Add core dependencies to pubspec.yaml: flutter_riverpod, riverpod_annotation, go_router, drift, sqlite3_flutter_libs, dio, web_socket_channel, flutter_secure_storage, google_fonts
- [x] 2.2 Add dev dependencies: riverpod_generator, build_runner, drift_dev, riverpod_lint

## 3. Environment Config

- [x] 3.1 Create `config/dev.json`, `config/staging.json`, `config/prod.json` with API_URL, APP_NAME, ENV values
- [x] 3.2 Create `lib/core/config/app_config.dart` that reads dart-define values into a typed config class
- [x] 3.3 Create 3 entry points: `lib/main_dev.dart`, `lib/main_staging.dart`, `lib/main_prod.dart`

## 4. Brand Theme

- [x] 4.1 Create `lib/core/theme/app_colors.dart` with all brand color constants (gold, dark backgrounds, text, semantic)
- [x] 4.2 Create `lib/core/theme/app_typography.dart` with Plus Jakarta Sans text styles
- [x] 4.3 Create `lib/core/theme/app_theme.dart` with dark ThemeData using AppColors and AppTypography

## 5. App Shell

- [x] 5.1 Create `lib/core/router/app_router.dart` with go_router configuration and placeholder home route
- [x] 5.2 Create `lib/app.dart` with MaterialApp.router wrapped in ProviderScope, using AppTheme and AppRouter
- [x] 5.3 Create a placeholder home screen widget at `lib/features/auth/screens/placeholder_home_screen.dart`

## 6. Analysis & Verification

- [x] 6.1 Configure `analysis_options.yaml` with strict rules (flutter_lints + custom strict rules)
- [x] 6.2 Verify `flutter pub get` succeeds with no version conflicts
- [x] 6.3 Verify `flutter analyze` passes with no issues
- [x] 6.4 Verify `flutter build web` completes successfully
