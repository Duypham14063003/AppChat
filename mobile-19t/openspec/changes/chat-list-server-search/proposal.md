## Why

The chat list search entry currently behaves as a local-cache search first and only reaches full-history results after the user explicitly taps a separate server-search action. That behavior does not match the desired UX for the global chat search surface, and it can miss valid results whenever the device cache is incomplete.

## What Changes

- Switch the chat list search entry to call the authenticated global message search API as soon as the user enters a valid query.
- Replace the current local-first search presentation with server-driven result loading, pagination, and error handling for the chat list search surface.
- Keep the existing message-open behavior so tapping a result still opens the conversation and navigates to the matched message.
- Update chat list search copy and states so the UI reflects full-history server results instead of device-only recent cache results.
- Preserve local cache and in-conversation search behavior outside this chat list global search flow.

## Capabilities

### New Capabilities
- `chat-list-server-search-ui`: Global chat-list search that queries `/api/v1/search/messages`, renders full-history results, paginates with cursors, and opens matched messages from the result list

### Modified Capabilities
- `chat-message-jump-navigation-ui`: Search-result entry into a conversation must continue to reveal the matched message when the chat screen opens from global search

## Impact

- Affected Flutter code: `apps/mobile/lib/features/chat/screens/chat_list_screen.dart`, `apps/mobile/lib/features/chat/providers/chat_providers.dart`, `apps/mobile/lib/features/chat/data/chat_repository.dart`, and search result presentation widgets/models
- API dependency: authenticated `GET /api/v1/search/messages` with `q`, optional `conv_id`, optional `cursor`, and `limit`
- UX impact: chat list search becomes server-driven for valid queries and should expose loading, empty, error, and pagination states
- No backend schema migration or new package dependency is required for this change
