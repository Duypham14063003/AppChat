## Context

Greenfield Flutter project for Nineteen Tech Internal App. The monorepo root is being set up in Task 0.1. This task scaffolds the Flutter application inside `apps/mobile/` with all 5 target platforms.

Key constraints from SRS:
- Cross-platform: iOS 15+, Android API 24+, Windows 10+, macOS 12+, Web (Chrome 90+)
- Riverpod for state management with `select()` for optimal rebuilds (KICKOFF 3.1)
- go_router for navigation with deep link support
- Drift (SQLite) for local cache — 7 day retention (NFR-PERF-004)
- Dark theme, gold accent #C9A84C, Plus Jakarta Sans font (NFR-USE-001)
- Strict Dart analysis (NFR-MAINT-001)
- App cold start < 3 seconds (NFR-PERF-004)

## Goals / Non-Goals

**Goals:**
- Runnable Flutter project on all 5 platforms with a placeholder home screen
- Feature-based folder structure matching KICKOFF.md section 5
- Environment config system (dev/staging/prod) via `--dart-define-from-file`
- Brand theme implemented (AppColors, typography, ThemeData)
- Core dependencies installed and importable
- Basic go_router setup with placeholder routes
- Riverpod ProviderScope at root

**Non-Goals:**
- Implementing any feature screens (login, chat, etc.) — separate tasks
- Drift database schema — Task 2.6
- Dio HTTP client configuration — Task 1.6
- WebSocket manager — Task 2.5
- Firebase setup — Task 4.3
- Native flavor configuration (different bundle IDs) — deferred, using `--dart-define-from-file` instead

## Decisions

### D1: --dart-define-from-file for environment config
**Choice**: JSON config files (`config/dev.json`, `config/staging.json`, `config/prod.json`) passed via `--dart-define-from-file`
**Rationale**: Simplest approach for internal app. No native-level configuration needed. Same bundle ID across environments is acceptable for < 50 users.
**Alternatives**: Native flavors (Android productFlavors + iOS schemes) — more complex, needed only if installing dev+prod side-by-side on same device.

### D2: Feature-based folder structure
**Choice**: `lib/features/<name>/` with each feature containing its own screens, widgets, providers, models
**Rationale**: Scales well as features grow. Each feature is self-contained. Matches KICKOFF section 5 layout.
**Alternatives**: Layer-based (`lib/screens/`, `lib/providers/`, `lib/models/`) — doesn't scale, cross-feature imports become messy.

### D3: Plus Jakarta Sans via google_fonts
**Choice**: Use `google_fonts` package to load Plus Jakarta Sans
**Rationale**: No need to bundle font files. Caches after first load. Supports Vietnamese characters fully.
**Alternatives**: Bundle font assets manually — works offline but increases app size. Can switch later if needed.

### D4: Three entry points (main_dev/staging/prod)
**Choice**: Separate `main_*.dart` files that configure environment then call shared `app.dart`
**Rationale**: Each entry point loads its config JSON and initializes the app. Clear separation. Run with `-t lib/main_dev.dart`.
**Alternatives**: Single main.dart with runtime env detection — less explicit, harder to tree-shake.

## Risks / Trade-offs

- **[google_fonts requires network on first run]** → Acceptable for internal app with WiFi. Font caches after first load. Can bundle as fallback later.
- **[--dart-define-from-file not supported in all IDEs equally]** → VS Code and Android Studio both support it via launch.json / run configurations. Document setup.
- **[Drift requires build_runner code generation]** → Standard Flutter practice. Add `build_runner` and `drift_dev` as dev dependencies. Document the `dart run build_runner build` command.
- **[5 platforms = 5x testing surface]** → Focus on mobile (iOS/Android) first. Desktop and Web are secondary targets per SRS priority.

