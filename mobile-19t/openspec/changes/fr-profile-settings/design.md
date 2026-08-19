## Context

The app has a complete dark theme system: `AppColors` (static const dark colors), `AppTypography` (Plus Jakarta Sans), `AppTheme.dark` (ThemeData). `App.dart` hardcodes `theme: AppTheme.dark`. The Profile tab exists in bottom nav (index 3, route `/profile`) but leads to empty directory. `ProfileModule` is an empty NestJS shell. User data (name, email, department, job_title, avatar_url) is already in the `users` table and available via `AuthService`. The auth state in Flutter already holds basic user info from JWT.

The entire codebase uses `AppColors.xxx` directly (hardcoded dark colors) in ~100+ widget files. A full refactor to `Theme.of(context)` is impractical in this change.

## Goals / Non-Goals

**Goals:**
- Profile screen showing user info
- Settings screen with theme/notification/sound/font/language toggles
- Dark/light mode with smooth toggle and persistence
- Backward-compatible theme approach (existing widgets keep working)

**Non-Goals:**
- Avatar upload (PROF-FR-006, P1 SHOULD — future)
- View other user's profile (PROF-FR-005, P1 SHOULD — future)
- Attendance/leave/task statistics on profile (PROF-FR-002/003/004, P1 SHOULD — future)
- App version check / force update (PROF-FR-008, P1 SHOULD — future)
- Server-side settings storage (local SharedPreferences only)
- Full refactor of all widgets from AppColors to Theme.of(context)
- i18n/l10n implementation (language toggle saves preference but actual translations are future)

## Decisions

### D1: Light theme — AppColorsLight + AppTheme.light

**Decision**: Create `AppColorsLight` class mirroring `AppColors` structure with light palette. Create `AppTheme.light` ThemeData using `AppColorsLight`. Both themes share the same gold brand colors and typography.

**Light palette**:
- background: #F5F5F0 (warm off-white)
- surface: #FFFFFF (white)
- surfaceVariant: #EEEEE8 (light warm gray)
- card: #FFFFFF (white, uses elevation shadow)
- textPrimary: #1A1A1A (near black)
- textSecondary: #6B6B60 (medium gray)
- textHint: #9E9E95 (light gray)
- bubbleMine: #FFF8E1 (light gold tint)

**Why**: Maintains brand identity (gold accent) while providing comfortable light reading experience. Warm tones match the luxury brand feel.

### D2: AppColorScheme — context-aware color accessor

**Decision**: Create `AppColorScheme` class with static `of(context)` method that returns the appropriate color set based on current theme brightness. Provides `background`, `surface`, `textPrimary`, etc. New widgets use `AppColorScheme.of(context).background`. Existing widgets keep using `AppColors.xxx` (still correct for dark theme, which is default).

**Why**: Gradual migration path. No breaking changes. New code is theme-aware, old code works as-is. Over time, widgets can be migrated one by one.

**Alternative**: Refactor all ~100+ files to use `Theme.of(context).colorScheme`. Rejected — too large a scope for this change, high risk of regressions.

### D3: ThemeMode provider with SharedPreferences

**Decision**: Riverpod `StateNotifier<ThemeMode>` that reads/writes to SharedPreferences key `theme_mode`. Values: `dark` (default), `light`, `system`. Initialized on app start before `runApp`.

**Why**: Instant theme switch without restart. Persists across sessions. `ThemeMode.system` follows OS preference. SharedPreferences is already available (used for secure token storage pattern).

### D4: Profile data — reuse auth state + lightweight API

**Decision**: ProfileScreen reads basic info from `authNotifierProvider` (already has name, email from JWT). For full profile (department, job_title, avatar_url), add `GET /profile/me` that returns the full User entity. Cache in a `profileProvider`.

**Why**: JWT already has name/email — no API call needed for basic display. Full profile endpoint is simple (query User by ID from JWT). No new tables.

### D5: Settings — local-only, no server sync

**Decision**: All settings (theme, notifications, sound, font size, language) stored in SharedPreferences. No server-side settings table. Each setting has its own Riverpod provider reading from SharedPreferences.

**Why**: Settings are device-specific (theme preference may differ between phone and desktop). No need for cross-device sync for <50 users. Simplest implementation.

## Risks / Trade-offs

- **[Risk] Existing widgets hardcode AppColors** → They continue to work because dark is default. Light mode may have visual issues in widgets not yet migrated to AppColorScheme. Mitigated by testing key screens and migrating critical widgets (chat bubbles, input bars, navigation).

- **[Trade-off] Gradual migration** → Light mode won't be pixel-perfect on day 1 for every screen. Priority: profile, settings, chat list, chat screen, navigation shell. Other screens migrated incrementally.

- **[Trade-off] Language toggle is UI-only** → Saves preference but actual i18n (string translations) is a separate future change. Toggle shows intent and stores preference for when translations are added.

