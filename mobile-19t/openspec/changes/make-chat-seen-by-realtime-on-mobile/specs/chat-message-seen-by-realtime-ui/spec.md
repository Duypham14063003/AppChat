## ADDED Requirements

### Requirement: Seen-by markers SHALL refresh from current backend state while a conversation is open
The mobile chat client SHALL refresh message-level seen-by markers for the active conversation when read-receipt websocket activity indicates that seen progress has changed. The client SHALL continue using the seen-by API as the source of truth for displayed readers and SHALL NOT infer readers locally without refreshed API data.

#### Scenario: Active conversation receives a read-receipt event
- **WHEN** the mobile client is viewing a conversation and receives websocket read-receipt activity for that same conversation
- **THEN** the client SHALL invalidate the seen-by state for that conversation
- **AND** the visible seen-by markers SHALL refresh from the seen-by API without requiring the user to leave and re-enter the conversation

#### Scenario: Unrelated conversation receives a read-receipt event
- **WHEN** the mobile client receives websocket read-receipt activity for a different conversation than the one currently open
- **THEN** the client SHALL NOT refresh seen-by markers for the active conversation

### Requirement: Seen-by placement SHALL show each reader on only the newest visible message they have read
The mobile chat client SHALL place each displayed reader on only one message in the visible message window: the newest visible message that the backend currently reports that reader has seen. The currently signed-in user SHALL be excluded from displayed seen-by avatar rows.

#### Scenario: Reader appears in multiple seen-by API responses
- **WHEN** the client refreshes seen-by state for a visible set of messages and the same reader appears in more than one message response
- **THEN** the client SHALL display that reader only on the newest visible message returned in the evaluated window

#### Scenario: Current user is included in backend response
- **WHEN** a seen-by API response includes the currently signed-in user
- **THEN** the client SHALL exclude that user from the seen-by avatar row shown in the chat UI

### Requirement: Seen-by detail views SHALL open with current backend data
The mobile chat client SHALL load the seen-by detail view for a message from the seen-by API at the time the detail view is opened and SHALL display the backend-returned reader order.

#### Scenario: User opens seen-by detail sheet
- **WHEN** the user opens the seen-by detail view for a message
- **THEN** the client SHALL fetch the message seen-by response from the backend
- **AND** the detail view SHALL render avatar, name, and available seen timestamp for each returned reader in backend order

#### Scenario: Seen-by detail request returns no readers
- **WHEN** the seen-by detail request succeeds with an empty `seen_by` list
- **THEN** the client SHALL display an explicit empty state indicating that no one has seen the message yet

### Requirement: Seen-by error states SHALL remain explicit and non-destructive
The mobile chat client SHALL handle seen-by API failures without corrupting message rendering or implying stale readers are current.

#### Scenario: Seen-by API returns a supported business error
- **WHEN** the seen-by API returns a mapped error such as 400, 403, or 404
- **THEN** the client SHALL show the corresponding user-facing error state in the detail view
- **AND** the client SHALL NOT fabricate seen-by readers for that message

#### Scenario: Seen-by refresh fails during realtime invalidation
- **WHEN** seen-by state is invalidated by read-receipt activity but the follow-up API request fails
- **THEN** the client SHALL keep the chat UI stable
- **AND** the failure SHALL NOT break message list rendering for the active conversation
