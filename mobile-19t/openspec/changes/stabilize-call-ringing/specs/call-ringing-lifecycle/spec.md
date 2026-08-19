## ADDED Requirements

### Requirement: Backend owns the ringing lifecycle

The backend SHALL be the single source of truth for the lifecycle of a one-to-one call. Once a call is created in `ringing` status, the backend SHALL keep it in `ringing` for a fixed timeout of 45 seconds unless it is explicitly accepted, rejected, or ended. The client MUST NOT drive ringing teardown using its own timer.

#### Scenario: Ringing call times out to missed

- **WHEN** a call has been in `ringing` status for 45 seconds without being accepted, rejected, or ended
- **THEN** the backend SHALL transition the call to `missed`
- **AND** the backend SHALL notify the caller and receiver that the call ended (missed)

#### Scenario: Ringing persists for the full window

- **WHEN** a call is created in `ringing` status and no terminal action occurs
- **THEN** the call SHALL remain queryable in `ringing` status for up to 45 seconds
- **AND** a receiver reconciling within that window SHALL find the pending call

### Requirement: Backend rejects premature end of a fresh ringing call

The backend SHALL treat an end request for a `ringing`, not-yet-accepted call that arrives within a minimum window (1 second) of the call's creation as a no-op. In this case the backend SHALL NOT write `ended` status and SHALL return the call's current state. This guard is independent of client behavior.

#### Scenario: End within the guard window is ignored

- **WHEN** an end request arrives for a call that is still `ringing`, has not been accepted, and was created less than 1 second ago
- **THEN** the backend SHALL NOT change the call status
- **AND** the backend SHALL return the current `ringing` call state without error

#### Scenario: End after the guard window proceeds normally

- **WHEN** an end request arrives for a `ringing` call created more than 1 second ago
- **THEN** the backend SHALL transition the call to `ended`
- **AND** the backend SHALL notify the other participant

#### Scenario: End of an accepted call is never blocked

- **WHEN** an end request arrives for a call that has already been accepted
- **THEN** the backend SHALL transition the call to `ended` regardless of how recently it was created

### Requirement: End operations are idempotent

The backend SHALL treat ending an already-ended call as a no-op that returns the existing call state without error.

#### Scenario: Ending an already-ended call

- **WHEN** an end request arrives for a call already in `ended` status
- **THEN** the backend SHALL return the existing call state
- **AND** the backend SHALL NOT emit duplicate end notifications

### Requirement: Disconnect does not end ringing calls

When a user's WebSocket connection drops, the backend SHALL NOT end that user's calls that are still in `ringing` status. Automatic teardown on disconnect SHALL apply only to calls that have progressed past ringing (e.g. `accepted`).

#### Scenario: Caller WebSocket drops while ringing

- **WHEN** the caller's last WebSocket connection drops and their call is still `ringing`
- **THEN** the backend SHALL leave the call in `ringing` status
- **AND** the call SHALL continue toward its normal 45-second timeout

#### Scenario: Participant disconnects during an active call

- **WHEN** a participant's last WebSocket connection drops and the call has been `accepted`
- **THEN** the backend MAY end the call as before

### Requirement: Client does not auto-end outgoing calls

The client SHALL NOT issue a backend end request for an `outgoing` call unless the local user explicitly requested to cancel the call. Native CallKit end events SHALL be treated as observational and SHALL NOT trigger a backend end of an outgoing call. The client SHALL NOT present a native CallKit outgoing call on the caller's own device.

#### Scenario: Spurious native CallKit end while dialing

- **WHEN** a native CallKit end event arrives while the local call is in `outgoing` status and the user did not tap cancel
- **THEN** the client SHALL NOT call the backend end endpoint
- **AND** the local outgoing call state SHALL be preserved

#### Scenario: User explicitly cancels an outgoing call

- **WHEN** the user taps the hangup control on the outgoing call screen
- **THEN** the client SHALL call the backend end endpoint with explicit user intent
- **AND** the call SHALL be torn down on both devices

### Requirement: Receiver reconciles pending incoming call on connect

When the receiver's client establishes or re-establishes its realtime connection, or returns to the foreground, the client SHALL query the backend for a pending incoming call and present it if one exists. This SHALL recover incoming calls whose realtime signal was missed.

#### Scenario: Incoming-call signal was missed during reconnect

- **WHEN** the receiver's WebSocket reconnects and the backend has a `ringing` call where the user is the receiver
- **THEN** the client SHALL present the incoming call
- **AND** presentation SHALL be suppressed if the same call was already handled

#### Scenario: No pending call on reconnect

- **WHEN** the receiver's WebSocket reconnects and there is no `ringing` call for the user
- **THEN** the client SHALL take no action

#### Scenario: Stale ringing call is not presented

- **WHEN** the client queries for a pending incoming call and the only matching call has been ringing longer than the 45-second window
- **THEN** the backend SHALL NOT return it as pending
