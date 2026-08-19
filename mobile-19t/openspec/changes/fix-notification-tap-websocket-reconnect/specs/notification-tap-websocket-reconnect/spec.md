## ADDED Requirements

### Requirement: Chat notification entry restores realtime connection
The mobile app SHALL trigger WebSocket recovery for authenticated users when a chat notification tap opens a conversation from a background, locked, or cold-open notification flow.

#### Scenario: Background notification tap opens chat while disconnected
- **WHEN** an authenticated user taps a chat notification and the WebSocket state is disconnected
- **THEN** the app SHALL attempt to reconnect the WebSocket while navigating to the target chat conversation

#### Scenario: Background notification tap while already connecting
- **WHEN** an authenticated user taps a chat notification and the WebSocket state is connecting
- **THEN** the app SHALL keep the existing connection attempt and SHALL NOT start a duplicate WebSocket connection

#### Scenario: Background notification tap while already connected
- **WHEN** an authenticated user taps a chat notification and the WebSocket state is connected
- **THEN** the app SHALL navigate to the target chat conversation without restarting the WebSocket connection

#### Scenario: Unauthenticated notification tap
- **WHEN** a chat notification tap is processed while the auth state is unauthenticated or still unresolved
- **THEN** the app SHALL preserve existing auth routing behavior and SHALL NOT create an unauthenticated WebSocket connection

### Requirement: App resume restores realtime connection
The mobile app SHALL trigger WebSocket recovery when returning to the foreground for an authenticated session if the WebSocket is not connected.

#### Scenario: Resume from lock screen while disconnected
- **WHEN** the app lifecycle changes to resumed for an authenticated user and the WebSocket state is disconnected
- **THEN** the app SHALL attempt to reconnect the WebSocket

#### Scenario: Resume while connected
- **WHEN** the app lifecycle changes to resumed for an authenticated user and the WebSocket state is connected
- **THEN** the app SHALL keep the existing WebSocket connection and SHALL NOT restart it

#### Scenario: Resume keeps existing chat sync behavior
- **WHEN** the app lifecycle changes to resumed
- **THEN** the app SHALL keep refreshing chat list and badge state according to the existing resume behavior

### Requirement: Token refresh keeps WebSocket reconnect authenticatable
The mobile app SHALL keep the token used for WebSocket auth handshakes synchronized with successful access-token refreshes.

#### Scenario: HTTP token refresh succeeds before WebSocket reconnect
- **WHEN** the HTTP auth interceptor refreshes the access token successfully
- **THEN** the next WebSocket auth handshake SHALL use the refreshed access token

#### Scenario: WebSocket auth error is recoverable when session remains valid
- **WHEN** a WebSocket auth attempt fails because the cached access token is stale but the authenticated session remains valid
- **THEN** the app SHALL be able to recover by using the refreshed token and SHALL NOT remain permanently disconnected until process restart

### Requirement: Intentional logout stops reconnect
The mobile app SHALL distinguish intentional logout/dispose disconnects from recoverable WebSocket loss.

#### Scenario: Logout disconnects WebSocket
- **WHEN** the user logs out
- **THEN** the app SHALL close the WebSocket and cancel reconnect attempts for that unauthenticated session

#### Scenario: Recoverable socket loss schedules reconnect
- **WHEN** the WebSocket closes unexpectedly during an authenticated session
- **THEN** the app SHALL transition to disconnected and schedule or allow a reconnect attempt
