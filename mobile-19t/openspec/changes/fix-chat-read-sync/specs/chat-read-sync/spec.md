## ADDED Requirements

### Requirement: Conversation entry SHALL show the latest available messages
The system SHALL synchronize a conversation's message set when the user opens that conversation so that messages already represented in the conversation list preview or local realtime cache are visible in the conversation detail view.

#### Scenario: New message preview exists before conversation entry
- **WHEN** a conversation shows a newer message preview in the conversation list and the user opens that conversation
- **THEN** the conversation detail view SHALL load a message set that includes that latest message before the screen is considered up to date

#### Scenario: Conversation provider state is stale on re-entry
- **WHEN** the user re-enters a previously opened conversation whose provider still holds older state
- **THEN** the system SHALL perform a conversation-scoped synchronization step instead of relying only on the stale in-memory message list

### Requirement: Read state SHALL converge after a conversation is viewed
The system SHALL clear unread and unread-mention indicators for a conversation after the user has viewed the latest visible message and the client has reconciled that read state with authoritative conversation data.

#### Scenario: User opens a conversation with unread messages
- **WHEN** the user opens a conversation that has unread messages
- **THEN** the system SHALL clear the local unread indicators immediately for responsive UI and SHALL reconcile them with authoritative conversation state so the indicators do not reappear incorrectly

#### Scenario: API refresh arrives after local unread reset
- **WHEN** a later API or websocket-driven conversation refresh occurs after the client has already cleared unread state for a viewed conversation
- **THEN** the system SHALL preserve or restore the correct read result instead of reintroducing stale unread counters

### Requirement: Unread counters SHALL not be globally suppressed by non-authoritative local heuristics
The system SHALL keep server unread counters authoritative for conversations that are not actively confirmed as read in the current client context.

#### Scenario: Local timestamp heuristic conflicts with server unread state
- **WHEN** local read/view timestamps suggest a conversation is read but the server still reports unread messages for that conversation
- **THEN** the conversation list SHALL not force unread counters to `0` solely from that local heuristic

#### Scenario: Inactive conversation receives new unread message
- **WHEN** a new inbound message arrives for a conversation that is not actively open/read by the user
- **THEN** the conversation list SHALL continue to show unread indication until a valid read reconciliation occurs

#### Scenario: Active conversation read confirmation remains responsive
- **WHEN** the user actively views a conversation and the client sends read reconciliation
- **THEN** unread indicators for that same conversation MAY clear immediately for responsive UX and SHALL converge with authoritative state after reconciliation

### Requirement: Conversation list and detail SHALL remain synchronized after inbound messages
The system SHALL persist inbound messages and update list/detail state from a shared durable source so that websocket timing differences do not cause the conversation list and conversation detail view to disagree about the latest message state.

#### Scenario: Inbound message arrives while conversation list is visible
- **WHEN** an inbound message is received for a conversation that is not currently open
- **THEN** the system SHALL update the conversation preview and SHALL make that same message available to the conversation detail synchronization flow when the user opens the conversation

#### Scenario: Inbound message arrives while the conversation is open
- **WHEN** an inbound message is received for the conversation currently being viewed
- **THEN** the system SHALL persist the message, render it in the conversation detail view, and keep the conversation list preview consistent with that persisted message
