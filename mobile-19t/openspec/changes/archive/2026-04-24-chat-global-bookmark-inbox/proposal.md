## Why

Users can already bookmark messages privately, but retrieval is limited to a single conversation at a time. That makes saved messages hard to use as a personal inbox because users must remember where a message was bookmarked before they can find it again.

## What Changes

- Add a global bookmark inbox API that returns the current user's bookmarked messages across all accessible conversations.
- Extend mobile bookmark state and cache handling so saved messages can be browsed as one ordered inbox instead of only per conversation.
- Add a chat-list entry point for a dedicated "Saved Messages" screen that matches the existing chat app navigation model.
- Let users open a saved item, navigate into the source conversation, and jump directly to the bookmarked message with highlight feedback.
- Preserve the existing per-conversation bookmark behavior and REST APIs as the lower-level bookmark management flow.

## Capabilities

### New Capabilities
- `global-bookmark-inbox-backend`: Private cross-conversation bookmark retrieval, pagination, and metadata shaping for the authenticated user.
- `global-bookmark-inbox-ui`: Global saved-messages entry point, inbox browsing UI, filtering, and jump-to-message navigation from chat list.

### Modified Capabilities
<!-- No existing base spec requirements are being modified. -->

## Impact

- **Backend**: Chat controller/service/query layer must expose a global bookmark listing endpoint that filters by the authenticated user and accessible conversations.
- **API**: New bookmark inbox retrieval contract must include enough message and conversation metadata for the mobile client to render a global saved-messages list.
- **Mobile data flow**: Chat providers/DAO/cache logic must support global bookmark reads in addition to the current conversation-scoped provider.
- **Mobile UI**: `chat_list_screen.dart`, chat routing, and a new saved-messages screen will be affected; existing bookmark list behavior inside `chat_screen.dart` remains supported.
- **Navigation**: The change relies on the existing chat message jump behavior so a saved item can deep-link back to its original message.
