## Why

The monorepo structure (Task 0.1) provides an empty `apps/mobile/` directory. Before any frontend feature development can begin, the Flutter project needs to be scaffolded with multi-platform support (iOS, Android, Windows, macOS, Web), the correct folder architecture, environment/flavor configuration, brand theming, and all core dependencies. This is Task 0.3 in the project roadmap and blocks all frontend feature tasks (login screen, chat UI, HR screens, etc.).

## What Changes

- Create Flutter project inside `apps/mobile/` with all 5 platforms enabled (iOS, Android, Windows, macOS, Web)
- Create feature-based folder structure under `lib/`: `core/` (theme, network, storage, router, providers), `features/` (auth, chat, call, hr, task, profile, settings), `shared/`
- Create 3 entry points: `main_dev.dart`, `main_staging.dart`, `main_prod.dart`
- Configure environment flavors using `--dart-define-from-file` approach with JSON config files (`config/dev.json`, `config/staging.json`, `config/prod.json`)
- Implement brand theme: dark theme with gold accent (#C9A84C), Plus Jakarta Sans font, AppColors and typography constants
- Install all core dependencies: flutter_riverpod, go_router, drift, dio, web_socket_channel, flutter_secure_storage
- Configure strict Dart analysis options and flutter_lints
- Set up basic go_router configuration with placeholder routes
- Set up Riverpod as the root state management provider

## Capabilities

### New Capabilities
- `flutter-project-structure`: Flutter project scaffold with feature-based architecture, multi-platform support, and all core dependencies
- `flutter-environment-config`: Environment flavor system using `--dart-define-from-file` with dev/staging/prod JSON configs
- `flutter-brand-theme`: Nineteen Tech brand identity implementation — AppColors, typography, dark theme with gold accent

### Modified Capabilities
<!-- No existing capabilities to modify -->

## Impact

- **`apps/mobile/`**: Transforms from empty placeholder to full Flutter project
- **Dependencies**: ~10 pub packages (state management + navigation + local DB + HTTP + WebSocket + secure storage)
- **Flutter SDK**: Requires Flutter 3.41+ stable
- **Build commands**: `flutter run --dart-define-from-file=config/dev.json` for local development
- **Subsequent tasks**: Unblocks all frontend feature tasks (1.5 login screen, 2.5 WebSocket manager, 2.6 Drift schema, 3.5 chat list, etc.)

