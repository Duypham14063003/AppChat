## ADDED Requirements

### Requirement: Active chat room SHALL verify realtime transport on entry

The mobile chat client SHALL verify or restore websocket connectivity when an authenticated user opens a chat room before relying on room-level realtime updates.

#### Scenario: Authenticated user opens a room while websocket is disconnected

- **WHEN** the user opens a chat room and the websocket session is not connected
- **THEN** the client SHALL initiate websocket recovery for the authenticated session
- **AND** the room SHALL continue rendering cached messages without waiting for the handshake to finish

#### Scenario: User opens a room while websocket is already healthy

- **WHEN** the user opens a chat room and the websocket session is already connected
- **THEN** the client SHALL NOT start redundant reconnect work
- **AND** the room SHALL continue with the existing realtime session

### Requirement: Active chat room SHALL resynchronize after websocket reconnect

The mobile chat client SHALL resynchronize the currently open chat room when websocket connectivity returns after a disconnect or stalled realtime period.

#### Scenario: Websocket reconnects while a room is open

- **WHEN** the websocket state returns to connected while the user is still viewing a chat room
- **THEN** the client SHALL trigger room-scoped synchronization for that conversation
- **AND** missed inbound messages SHALL become visible without leaving and reopening the room

#### Scenario: Websocket reconnects while no room is open

- **WHEN** the websocket state returns to connected while the user is not viewing a chat room
- **THEN** the client SHALL NOT perform room-scoped synchronization for an inactive conversation

### Requirement: Active chat room SHALL converge from persisted message state after realtime recovery

The mobile chat client SHALL continue using persisted room message state as the rendered source of truth and SHALL refresh that state during room-open and reconnect recovery.

#### Scenario: Recovery fetch returns missed messages

- **WHEN** room synchronization runs after room entry or websocket reconnect
- **THEN** the client SHALL persist returned messages into local storage
- **AND** the visible room timeline SHALL update from that persisted state

#### Scenario: Recovery finds no missed messages

- **WHEN** room synchronization completes and there are no newer messages than local state
- **THEN** the visible room timeline SHALL remain stable
- **AND** the user SHALL NOT need to leave and reopen the room to confirm freshness

### Requirement: Outbound room sends SHALL preserve truthful pending state during websocket failure

The mobile chat client SHALL keep optimistic outbound room messages in a retryable pending state when websocket dispatch fails and SHALL actively attempt realtime recovery instead of implying successful delivery.

#### Scenario: Text send fails websocket dispatch

- **WHEN** the user sends a text message from an open room and websocket dispatch fails
- **THEN** the message SHALL remain in a retryable pending state
- **AND** the client SHALL trigger websocket recovery for the authenticated session

#### Scenario: Pending message receives acknowledgement after recovery

- **WHEN** websocket recovery succeeds and the pending room message is acknowledged by the server
- **THEN** the client SHALL transition that message from pending to sent
- **AND** peer clients SHALL be able to receive the message without the sender leaving and reopening the room
