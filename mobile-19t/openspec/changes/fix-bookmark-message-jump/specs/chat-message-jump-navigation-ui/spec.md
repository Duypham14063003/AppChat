## MODIFIED Requirements

### Requirement: Historical message navigation loads older pages before failing
The system SHALL continue loading older conversation history while the backend reports that older pages remain available whenever the user requests navigation to a message that is not currently present in the loaded chat timeline.

#### Scenario: Pinned or bookmarked target is older than the loaded window
- **WHEN** the user taps a pinned or bookmarked message whose target is not currently present in the loaded chat timeline
- **THEN** the app loads older message pages and continues checking for the target message before showing a failure state

#### Scenario: Reply target is older than the loaded window
- **WHEN** the user taps a reply preview whose original message is older than the loaded chat timeline
- **THEN** the app loads older history until the original message is found or history is exhausted

#### Scenario: Backend reports that older history still exists
- **WHEN** an older-history response does not increase the currently rendered local message count but the backend still reports `hasMore`
- **THEN** the app keeps older-history loading available instead of concluding that history is exhausted

### Requirement: Historical message navigation succeeds once the target becomes available
The system SHALL scroll to and highlight the requested message as soon as it becomes available in the loaded chat timeline during historical pagination, using the rendered timeline position of that message.

#### Scenario: Target found after loading older pages
- **WHEN** the app loads one or more older pages and the requested target message appears in the timeline
- **THEN** the chat screen scrolls to that message and highlights it

#### Scenario: Deep link uses initial message target
- **WHEN** the chat screen opens with an `initialMessageId` that is not in the first loaded timeline window but becomes available after loading older pages
- **THEN** the chat screen automatically jumps to and highlights that target message

#### Scenario: Deep link target changes inside the same conversation
- **WHEN** the app is already showing a conversation and a new route-driven `messageId` targets a different message in that same conversation
- **THEN** the chat screen treats the updated `messageId` as a new jump request and scrolls to and highlights the new target message

#### Scenario: Timeline includes non-message rows
- **WHEN** the target message is rendered in a timeline that also includes date separators or system-message rows
- **THEN** the jump logic scrolls to the rendered row for the target message rather than an offset based on the raw message-array index

### Requirement: Historical message navigation reports exhausted history truthfully
The system SHALL only report that a target message is unavailable after older history loading is exhausted according to backend pagination state and the requested message still is not present in the loaded timeline.

#### Scenario: Pagination reaches the end without the target
- **WHEN** repeated older-history loads stop returning additional available pages and the requested message still is not in the timeline
- **THEN** the app shows a final failure message indicating that the target is not available in the loaded history

#### Scenario: Loading feedback is shown while searching history
- **WHEN** the app is still loading older pages to resolve a historical message jump
- **THEN** the app shows temporary loading feedback instead of immediately reporting that the message is out of range
