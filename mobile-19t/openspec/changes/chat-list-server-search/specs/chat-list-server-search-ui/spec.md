## ADDED Requirements

### Requirement: Chat-list search queries the global message search API for valid input
The system SHALL call `GET /api/v1/search/messages` from the chat-list search entry whenever the user enters a valid global search query.

#### Scenario: Valid query triggers server search after debounce
- **WHEN** the user types a query with at least 2 characters in the chat-list search field and pauses for the configured debounce interval
- **THEN** the app issues an authenticated request to `GET /api/v1/search/messages` with `q` set to the current query

#### Scenario: Invalid query does not call the API
- **WHEN** the user input is empty or shorter than 2 characters
- **THEN** the app does not call `GET /api/v1/search/messages` and instead keeps or returns to the non-search chat-list state

### Requirement: Chat-list search renders server response data as global message results
The system SHALL render chat-list search results from the server response using the API fields for conversation identity, snippet, and message timestamp.

#### Scenario: Result row maps server fields to the search UI
- **WHEN** `GET /api/v1/search/messages` returns one or more results
- **THEN** each row shows the conversation avatar from `conv_avatar_url`, the conversation name from `conv_name`, the preview from `snippet` or `content` fallback, and the right-aligned relative time derived from `created_at`

#### Scenario: Group result shows sender context
- **WHEN** a search result belongs to a group conversation and includes `sender_name`
- **THEN** the search row shows sender context alongside the snippet so the user can identify who wrote the matched message

### Requirement: Chat-list search exposes server-driven loading, empty, error, and pagination states
The system SHALL present search states based on the global message search API response lifecycle rather than on a manual "search all" escalation step.

#### Scenario: Loading state is shown during server search
- **WHEN** a valid chat-list search request is in flight
- **THEN** the UI shows loading feedback for the global search results area

#### Scenario: Empty state is shown when the API returns no matches
- **WHEN** `GET /api/v1/search/messages` returns an empty `results` array for a valid query
- **THEN** the UI shows a no-results state for the global search flow

#### Scenario: Error state is shown when the API request fails
- **WHEN** the global message search request fails with a transport or server error
- **THEN** the UI shows an error state for the search flow instead of silently falling back to stale local-only results

#### Scenario: Additional pages load from next cursor
- **WHEN** the current search response has `has_more = true` and the user requests more results
- **THEN** the app calls `GET /api/v1/search/messages` again with the same `q` and the returned `next_cursor`, then appends the new results
