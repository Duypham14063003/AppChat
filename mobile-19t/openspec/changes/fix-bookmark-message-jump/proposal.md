## Why

Saved-message navigation is currently unreliable in two important ways: Flutter Web can stop loading older history before the bookmarked message becomes available, and mobile can scroll to the wrong visual position even after the target message is loaded. A newly observed follow-up bug also prevents repeated message jumps inside the same conversation because the chat screen does not treat a new `messageId` route parameter as a fresh jump request after the first open.

## What Changes

- Fix bookmarked-message navigation so the chat screen keeps loading older history until the target message is found or the backend explicitly reports that history is exhausted.
- Align chat-screen jump scrolling with the rendered timeline so date separators and system rows do not shift the final scroll target away from the bookmarked message.
- Tighten the contract between route-driven message navigation and historical message loading so bookmark taps, global search results, and other `messageId` entry points behave consistently on mobile and web.
- Ensure opening a new target message inside an already open conversation retriggers historical jump resolution instead of only focusing the existing chat screen.
- Add verification coverage for deep historical jumps, exhausted-history handling, and rendered-position accuracy.

## Capabilities

### New Capabilities
<!-- None. -->

### Modified Capabilities
- `chat-message-jump-navigation-ui`: Historical jump loading and scroll targeting must remain accurate across rendered timeline decorations and paginated history boundaries.
- `global-bookmark-inbox-ui`: Tapping a saved message must reliably open the source conversation and reveal the exact bookmarked message on both mobile and web.

## Impact

- **Flutter chat UI**: `chat_screen.dart` historical jump state, scroll targeting, and load-more trigger behavior.
- **Chat data flow**: `chat_providers.dart` pagination handling for older history, including use of backend pagination metadata.
- **Route-driven message navigation**: router query handling, `global_bookmarked_messages_screen.dart`, `chat_list_screen.dart`, and saved-message/search-to-chat handoff.
- **Tests**: chat jump/navigation, bookmark inbox navigation, repeated same-conversation deep-link handling, and regression coverage for older-history loading behavior.
