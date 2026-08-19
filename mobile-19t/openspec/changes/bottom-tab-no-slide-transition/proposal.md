## Why

The mobile app's bottom navigation currently switches root tabs through normal route transitions, which produces a left-to-right page animation that feels like a push navigation. For persistent bottom tabs such as Chat, HR, Tasks, and Profile, that motion is misleading and makes the shell feel less native and less stable than a true tab container.

## What Changes

- Remove the horizontal page-slide transition when switching between bottom navigation root tabs.
- Treat bottom-tab selection as shell or branch switching rather than standard push-style page navigation.
- Preserve normal push navigation behavior for detail screens opened from within each tab.
- Add verification coverage for root-tab switching behavior and state preservation expectations.

## Capabilities

### New Capabilities
- `bottom-tab-navigation-ui`: Root tab navigation behavior for the Flutter shell, including non-sliding tab switches and preserved per-tab navigation semantics.

### Modified Capabilities
<!-- No existing base spec requirements are being modified. -->

## Impact

- **Flutter router**: `apps/mobile/lib/core/router/app_router.dart`
- **Shell navigation UI**: `apps/mobile/lib/core/router/main_shell.dart`
- **Navigation behavior**: Bottom tab switching between `/chat`, `/hr`, `/tasks`, and `/profile`
- **Testing**: Router or widget coverage for tab switching transitions and root-tab state behavior
