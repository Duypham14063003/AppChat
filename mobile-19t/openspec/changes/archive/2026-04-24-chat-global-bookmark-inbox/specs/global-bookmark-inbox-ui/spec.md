## ADDED Requirements

### Requirement: Chat list entry point opens the saved-messages inbox
The mobile app SHALL expose a saved-messages entry point from the chat-list header so users can open their global bookmark inbox without entering a specific conversation first.

#### Scenario: Open saved-messages inbox from chat list
- **WHEN** the user taps the saved-messages icon in the chat-list header
- **THEN** the app opens the global saved-messages screen

### Requirement: Global saved-messages screen lists bookmarks across conversations
The mobile app SHALL provide a dedicated saved-messages screen that displays the current user's bookmarks from multiple conversations in one list ordered by `marked_at DESC`. Each row SHALL show enough conversation and message context for the user to identify the saved item.

#### Scenario: Render mixed conversation bookmarks
- **WHEN** the saved-messages screen loads bookmarks from direct and group conversations
- **THEN** the app renders them in one ordered list with conversation display info and message preview text

#### Scenario: Show empty state
- **WHEN** the user has no saved messages
- **THEN** the saved-messages screen shows an explicit empty state instead of a blank list

### Requirement: Global saved-messages screen supports top-level filtering
The saved-messages screen SHALL provide a top-level filter with `all`, `direct`, and `group`, defaulting to `all`.

#### Scenario: Default filter shows all saved messages
- **WHEN** the user first opens the saved-messages screen
- **THEN** the `all` filter is selected and the screen shows saved messages from every supported conversation type

#### Scenario: Filter to group bookmarks
- **WHEN** the user changes the filter to `group`
- **THEN** the screen refreshes to show only saved messages originating from group conversations

### Requirement: Saved-message tap opens the source message
The mobile app SHALL open the source conversation and jump to the bookmarked message when the user taps an item in the global saved-messages screen.

#### Scenario: Open bookmarked message from another conversation
- **WHEN** the user taps a saved item whose source conversation is not currently open
- **THEN** the app navigates to that conversation and passes the bookmarked `messageId` so the chat screen scrolls to and highlights the target message

#### Scenario: Open bookmarked message older than the current timeline window
- **WHEN** the saved item targets a message older than the chat screen's initially loaded message window
- **THEN** the existing historical jump flow loads older pages until the bookmarked message is found or history is exhausted

### Requirement: Global bookmark inbox uses cached state before refresh
The mobile app SHALL be able to render cached saved-message items before the latest network refresh completes and SHALL refresh global inbox state after bookmark mutations.

#### Scenario: Cached inbox appears immediately
- **WHEN** locally cached bookmark data exists for the current user
- **THEN** the saved-messages screen can render cached items immediately before the global bookmark inbox refresh finishes

#### Scenario: Bookmark mutation refreshes the global inbox
- **WHEN** the user bookmarks or unbookmarks a message anywhere in chat
- **THEN** the global saved-messages inbox state is refreshed so the list stays coherent with the latest bookmark set
