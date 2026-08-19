## ADDED Requirements

### Requirement: In-chat search counter reflects navigable matches
The system SHALL show the in-conversation search counter using the same match set that next/previous navigation can actually move through in the current chat timeline.

#### Scenario: Counter excludes unavailable timeline hits
- **WHEN** the search query matches messages that are not currently present in the loaded conversation timeline
- **THEN** those unavailable hits are not counted in the in-chat search counter shown on the chat screen

#### Scenario: Counter stays aligned with navigation
- **WHEN** the user taps next or previous search result
- **THEN** the counter index and total both correspond to the same navigable match list used for scrolling

### Requirement: First in-chat search result auto-scrolls to a navigable match
The system SHALL auto-scroll to the first navigable match after the user enters a valid in-conversation search query.

#### Scenario: Search finds navigable matches
- **WHEN** the user enters a query with one or more matches in the currently loaded conversation timeline
- **THEN** the chat screen scrolls to the first navigable match and highlights it

#### Scenario: Raw search hits are not navigable
- **WHEN** the raw local or server search response includes matches outside the currently loaded conversation timeline
- **THEN** the app does not pretend those unavailable hits were auto-scrolled to

### Requirement: Next and previous search navigation never target unreachable matches
The system SHALL move only among matches that are currently resolvable in the loaded conversation timeline.

#### Scenario: Navigate forward through matches
- **WHEN** the user taps the next-match action
- **THEN** the app scrolls to the next navigable match in the current in-chat search result list

#### Scenario: Navigate backward through matches
- **WHEN** the user taps the previous-match action
- **THEN** the app scrolls to the previous navigable match in the current in-chat search result list
