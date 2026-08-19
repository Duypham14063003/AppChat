## Why

In-conversation chat search currently builds a match counter from a broader result set than the timeline can actually navigate, so users can see counts like `5/8` while the screen does not auto-scroll to the selected match. That mismatch makes search feel unreliable and breaks the expected "find result, jump there, step through matches" workflow.

## What Changes

- Make in-chat search auto-scroll only to results that are actually available for navigation in the current conversation view.
- Align the in-chat search counter with the same navigable result set used by next/previous match navigation.
- Define how the app should handle matches found outside the currently loaded timeline window instead of silently failing to scroll.
- Add verification coverage for first-match auto-scroll, next/previous navigation, and result-count consistency.

## Capabilities

### New Capabilities
- `chat-search-match-navigation-ui`: In-conversation search result navigation, auto-scroll behavior, and consistent match counting for the Flutter chat screen.

### Modified Capabilities
<!-- No existing base spec requirements are being modified. -->

## Impact

- **Flutter chat UI**: `apps/mobile/lib/features/chat/screens/chat_screen.dart`
- **Local chat storage/search**: `apps/mobile/lib/core/database/chat_dao.dart`
- **Chat repository/search integration**: `apps/mobile/lib/features/chat/data/chat_repository.dart`
- **Verification**: Mobile tests for search result navigation and counter coherence
