## MODIFIED Requirements

### Requirement: Saved-message tap opens the source message
The mobile app SHALL open the source conversation and reliably reveal the bookmarked message when the user taps an item in the global saved-messages screen, including targets outside the initially loaded timeline window.

#### Scenario: Open bookmarked message from another conversation
- **WHEN** the user taps a saved item whose source conversation is not currently open
- **THEN** the app navigates to that conversation and passes the bookmarked `messageId` so the chat screen scrolls to and highlights the target message

#### Scenario: Open bookmarked message older than the current timeline window
- **WHEN** the saved item targets a message older than the chat screen's initially loaded message window
- **THEN** the existing historical jump flow loads older pages until the bookmarked message is found or history is exhausted

#### Scenario: Open bookmarked message on a rendered timeline with inserted rows
- **WHEN** the bookmarked message is found in a chat timeline that includes date separators or system rows
- **THEN** the chat screen reveals the exact bookmarked message instead of stopping at a neighboring visual row

#### Scenario: Open bookmarked message while older history is still available on web
- **WHEN** the user opens a saved message on Flutter Web and the target is older than the currently loaded timeline
- **THEN** the chat screen continues requesting older history while backend pagination reports more pages remain

#### Scenario: Open another saved message in the same conversation
- **WHEN** the user is already viewing a conversation opened from a saved message and then opens a different saved message that belongs to that same conversation
- **THEN** the app passes the new bookmarked `messageId` through the existing chat route and the chat screen jumps to the newly requested message instead of only focusing the current conversation
