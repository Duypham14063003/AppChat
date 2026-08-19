# global-bookmark-inbox-backend Specification

## Purpose
TBD - created by archiving change chat-global-bookmark-inbox. Update Purpose after archive.
## Requirements
### Requirement: Global bookmark inbox retrieval
The system SHALL expose a user-scoped REST endpoint for global bookmark retrieval across all conversations the authenticated user can still access. The endpoint SHALL return bookmarked messages ordered by `marked_at DESC` and SHALL include enough bookmark, message, sender, and conversation metadata for the client to render a saved-messages inbox without per-item follow-up fetches.

#### Scenario: Return saved items from multiple conversations
- **WHEN** a user requests their global bookmark inbox and has bookmarks in multiple accessible conversations
- **THEN** the system returns a single ordered list containing only that user's bookmarks from those conversations, newest-marked first

#### Scenario: Return an empty inbox
- **WHEN** a user requests their global bookmark inbox and has no accessible bookmarks
- **THEN** the system returns `200 OK` with an empty result set

### Requirement: Global bookmark inbox supports filter and pagination
The global bookmark inbox endpoint SHALL support pagination and SHALL accept an optional conversation-type filter for `direct` or `group` bookmarks while defaulting to all bookmarkable conversation types.

#### Scenario: Filter to direct conversations
- **WHEN** a user requests the global bookmark inbox with the direct-conversation filter
- **THEN** the system returns only bookmarks whose source conversation type is direct

#### Scenario: Request the next page
- **WHEN** a user requests the global bookmark inbox with a valid pagination cursor
- **THEN** the system returns the next page of bookmarks for the same active filter scope

### Requirement: Global bookmark inbox enforces privacy and current access
The global bookmark inbox SHALL return only bookmarks owned by the authenticated user and SHALL exclude bookmarks whose source conversation or message is no longer accessible to that user.

#### Scenario: Do not leak another user's bookmarks
- **WHEN** two users bookmark messages in the same conversation
- **THEN** each user sees only their own bookmark rows in their global inbox response

#### Scenario: Exclude inaccessible conversation bookmark
- **WHEN** a bookmark still exists in storage but the requesting user no longer has access to the source conversation
- **THEN** the bookmark is omitted from the global inbox response

### Requirement: Global inbox retrieval is additive to conversation bookmark APIs
The system SHALL add global bookmark retrieval without removing or redefining the existing conversation-scoped bookmark create, delete, and list APIs.

#### Scenario: Conversation bookmark APIs still work
- **WHEN** the client continues using the existing `/conversations/:convId/bookmarks` routes for bookmark mutation or per-conversation retrieval
- **THEN** those routes behave as before while the global inbox endpoint remains an additional read path

