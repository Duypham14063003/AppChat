## ADDED Requirements

### Requirement: Global search results open the matched message in chat
The system SHALL open the source conversation and reveal the matched message when the user taps a result from the chat-list global search surface.

#### Scenario: Search result opens chat with target message
- **WHEN** the user taps a result returned by the chat-list global message search
- **THEN** the app opens the corresponding conversation and passes the matched message identifier into the existing chat message-jump flow

#### Scenario: Older matched message is revealed after chat opens
- **WHEN** the matched message is older than the initial conversation page loaded by the chat screen
- **THEN** the existing historical message-jump behavior continues loading and scrolling until that matched message is revealed or history is exhausted
