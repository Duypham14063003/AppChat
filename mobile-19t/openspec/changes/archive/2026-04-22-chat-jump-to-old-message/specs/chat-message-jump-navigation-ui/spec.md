## ADDED Requirements

### Requirement: Historical message navigation loads older pages before failing
The system SHALL attempt to load older conversation history when the user requests navigation to a message that is not currently present in the loaded chat timeline.

#### Scenario: Pinned or bookmarked target is older than the loaded window
- **WHEN** the user taps a pinned or bookmarked message whose target is not currently present in the loaded chat timeline
- **THEN** the app loads older message pages and continues checking for the target message before showing a failure state

#### Scenario: Reply target is older than the loaded window
- **WHEN** the user taps a reply preview whose original message is older than the loaded chat timeline
- **THEN** the app loads older history until the original message is found or history is exhausted

### Requirement: Historical message navigation succeeds once the target becomes available
The system SHALL scroll to and highlight the requested message as soon as it becomes available in the loaded chat timeline during historical pagination.

#### Scenario: Target found after loading older pages
- **WHEN** the app loads one or more older pages and the requested target message appears in the timeline
- **THEN** the chat screen scrolls to that message and highlights it

#### Scenario: Deep link uses initial message target
- **WHEN** the chat screen opens with an `initialMessageId` that is not in the first loaded timeline window but becomes available after loading older pages
- **THEN** the chat screen automatically jumps to and highlights that target message

### Requirement: Historical message navigation reports exhausted history truthfully
The system SHALL only report that a target message is unavailable after older history loading is exhausted without finding the requested message.

#### Scenario: Pagination reaches the end without the target
- **WHEN** repeated older-history loads stop returning additional messages and the requested message still is not in the timeline
- **THEN** the app shows a final failure message indicating that the target is not available in the loaded history

#### Scenario: Loading feedback is shown while searching history
- **WHEN** the app is still loading older pages to resolve a historical message jump
- **THEN** the app shows temporary loading feedback instead of immediately reporting that the message is out of range
