## Why

Several chat and group-management screens still hardcode dark-only colors even though the app now supports light theme presets through `AppThemePalette`. In light mode, that leaves dialogs, search fields, empty states, and overlays with incorrect contrast and a visually broken mix of dark and light surfaces.

## What Changes

- Align chat and group-management dialogs, sheets, and search surfaces with the active theme palette in light mode.
- Replace dark-only color usage in the affected chat/group flows with palette-driven colors so text, hints, icons, backgrounds, and overlays adapt correctly.
- Keep semantic destructive/warning accents intact while moving neutral surfaces and typography to theme-aware styling.

## Capabilities

### New Capabilities
- `chat-group-theme-adaptive-ui`: Ensures key chat and group-management flows render with palette-aware colors in light mode and dark mode.

### Modified Capabilities
- None.

## Impact

- Affected chat/group UI screens such as `group_info_screen.dart`, `group_create_members_screen.dart`, `group_create_name_screen.dart`, `contact_picker_screen.dart`, and `chat_screen.dart`
- Affected dialogs, search fields, empty states, and loading overlays in chat/group flows
- Reuses the existing palette system in `apps/mobile/lib/core/theme/theme_color_presets.dart`
- No backend, API, or data-model changes are expected
