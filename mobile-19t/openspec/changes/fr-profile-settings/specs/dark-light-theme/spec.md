## ADDED Requirements

### Requirement: Light theme color palette
The system SHALL define `AppColorsLight` class with light mode colors: background (#F5F5F0), surface (#FFFFFF), surfaceVariant (#EEEEE8), card (#FFFFFF), textPrimary (#1A1A1A), textSecondary (#6B6B60), textHint (#9E9E95), bubbleMine (#FFF8E1). Gold brand colors and semantic colors (online, danger, warning, info) SHALL remain identical to dark theme.

#### Scenario: Light colors defined
- **WHEN** the app is in light mode
- **THEN** AppColorsLight values are used for backgrounds, surfaces, and text

### Requirement: AppTheme.light ThemeData
The system SHALL create `AppTheme.light` getter returning a `ThemeData` with `brightness: Brightness.light`, using `AppColorsLight` for `ColorScheme`, `AppBarTheme`, `CardTheme`, `TextTheme`, and `InputDecorationTheme`. Typography (Plus Jakarta Sans) SHALL be shared with dark theme.

#### Scenario: Light ThemeData applied
- **WHEN** the user switches to light mode
- **THEN** MaterialApp uses AppTheme.light and all Material widgets render with light colors

### Requirement: AppColorScheme context-aware accessor
The system SHALL provide an `AppColorScheme` class with a static `of(BuildContext context)` method that returns the appropriate color set (dark or light) based on `Theme.of(context).brightness`. The returned object SHALL expose all color properties: background, surface, surfaceVariant, card, textPrimary, textSecondary, textHint, bubbleMine, gold, goldLight, goldDark.

#### Scenario: Dark mode colors
- **WHEN** `AppColorScheme.of(context)` is called in dark mode
- **THEN** it returns AppColors (dark) values

#### Scenario: Light mode colors
- **WHEN** `AppColorScheme.of(context)` is called in light mode
- **THEN** it returns AppColorsLight values

### Requirement: ThemeMode Riverpod provider
The system SHALL provide a `themeModeProvider` StateNotifier that manages `ThemeMode` state (dark, light, system). The provider SHALL read the initial value from SharedPreferences on creation and write changes to SharedPreferences on every update.

#### Scenario: Theme mode persisted
- **WHEN** the user changes theme to light
- **THEN** SharedPreferences stores "light" and the provider emits ThemeMode.light

#### Scenario: Default theme mode
- **WHEN** no theme preference is stored
- **THEN** the provider defaults to ThemeMode.dark

### Requirement: App.dart supports theme switching
The system SHALL refactor `App.dart` to use `theme: AppTheme.light`, `darkTheme: AppTheme.dark`, and `themeMode: ref.watch(themeModeProvider)` in `MaterialApp.router`. This enables runtime theme switching without app restart.

#### Scenario: Runtime theme switch
- **WHEN** the user toggles from dark to light in settings
- **THEN** the entire app immediately re-renders with light theme colors

### Requirement: Migrate critical widgets to AppColorScheme
The system SHALL migrate the following critical widgets to use `AppColorScheme.of(context)` instead of hardcoded `AppColors`: MainShell (navigation bar/rail), ChatListScreen, ChatScreen (message input bar, bubbles), ProfileScreen, SettingsScreen. Other widgets MAY continue using `AppColors` and will be migrated incrementally.

#### Scenario: Navigation bar adapts to theme
- **WHEN** the user switches to light mode
- **THEN** the bottom navigation bar and navigation rail use light background and appropriate icon colors

#### Scenario: Chat bubbles adapt to theme
- **WHEN** the user is in light mode viewing a chat
- **THEN** chat bubbles use light-appropriate colors (bubbleMine uses #FFF8E1)

### Requirement: Font size scaling via provider
The system SHALL provide a `fontScaleProvider` that reads/writes font size preference (small=0.85, medium=1.0, large=1.15) from SharedPreferences. `App.dart` SHALL wrap `MaterialApp.router` with a `MediaQuery` override applying the text scale factor.

#### Scenario: Large font applied
- **WHEN** the user selects "Lớn" font size
- **THEN** all text in the app renders at 1.15x scale

