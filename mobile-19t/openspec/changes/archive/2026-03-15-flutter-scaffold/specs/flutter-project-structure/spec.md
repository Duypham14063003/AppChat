## ADDED Requirements

### Requirement: Flutter project builds on all 5 platforms
The Flutter project SHALL be created with platform support for iOS, Android, Windows, macOS, and Web. The project SHALL build successfully on each platform from a clean state.

#### Scenario: Build for web succeeds
- **WHEN** developer runs `flutter build web` inside `apps/mobile/`
- **THEN** the build completes successfully with no errors

#### Scenario: Analyze passes with no issues
- **WHEN** developer runs `flutter analyze` inside `apps/mobile/`
- **THEN** no analysis issues are reported on the scaffold code

### Requirement: Feature-based folder structure exists
The project SHALL contain `lib/features/` with subdirectories for auth, chat, call, hr, task, profile, and settings. Each feature directory SHALL contain a `.gitkeep` placeholder.

#### Scenario: All feature directories exist
- **WHEN** developer inspects `lib/features/`
- **THEN** 7 directories exist: auth, chat, call, hr, task, profile, settings

### Requirement: Core infrastructure directories exist
The project SHALL contain `lib/core/` with subdirectories for theme, network, storage, router, and providers. The project SHALL also contain `lib/shared/` for common widgets and utilities.

#### Scenario: Core directories are present
- **WHEN** developer inspects `lib/core/`
- **THEN** 5 directories exist: theme, network, storage, router, providers

### Requirement: Three environment entry points exist
The project SHALL provide `lib/main_dev.dart`, `lib/main_staging.dart`, and `lib/main_prod.dart` as separate entry points. Each SHALL load its respective environment configuration and launch the app.

#### Scenario: Run dev environment
- **WHEN** developer runs `flutter run -t lib/main_dev.dart --dart-define-from-file=config/dev.json`
- **THEN** the app launches with API_URL pointing to `http://localhost:3000`

#### Scenario: Config files exist for all environments
- **WHEN** developer inspects `config/` directory inside `apps/mobile/`
- **THEN** files `dev.json`, `staging.json`, and `prod.json` exist with appropriate API_URL values

### Requirement: Riverpod is configured as root provider
The application SHALL wrap the root widget in a `ProviderScope` from flutter_riverpod, enabling Riverpod state management throughout the app.

#### Scenario: ProviderScope wraps MaterialApp
- **WHEN** the app starts
- **THEN** the widget tree has `ProviderScope` as the outermost widget above `MaterialApp`

### Requirement: go_router is configured with placeholder routes
The application SHALL use go_router for navigation with at least a root route (`/`) that displays a placeholder home screen.

#### Scenario: App navigates to home on launch
- **WHEN** the app starts
- **THEN** the home screen is displayed at route `/`

### Requirement: All core dependencies are installed
The project SHALL have all dependencies in `pubspec.yaml`: flutter_riverpod, riverpod_annotation, go_router, drift, dio, web_socket_channel, flutter_secure_storage, google_fonts. Dev dependencies SHALL include riverpod_generator, build_runner, drift_dev.

#### Scenario: flutter pub get succeeds
- **WHEN** developer runs `flutter pub get` inside `apps/mobile/`
- **THEN** all dependencies resolve successfully with no version conflicts

### Requirement: Strict Dart analysis is configured
The project SHALL use strict analysis options via `analysis_options.yaml` with flutter_lints and additional strict rules enabled.

#### Scenario: Analysis options enforce strict rules
- **WHEN** developer runs `flutter analyze`
- **THEN** strict rules (prefer_const_constructors, avoid_print, etc.) are enforced

