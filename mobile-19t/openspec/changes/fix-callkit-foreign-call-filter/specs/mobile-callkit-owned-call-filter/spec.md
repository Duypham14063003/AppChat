## ADDED Requirements

### Requirement: App-created native calls include ownership markers

The mobile client SHALL attach explicit app-owned markers to every CallKit payload it creates for incoming-call presentation. The payload SHALL include an app-specific ownership marker, the business `callId`, and the call direction.

#### Scenario: Foreground incoming call presentation
- **WHEN** the app presents an incoming call through its CallKit wrapper while running in the foreground or background
- **THEN** the native payload SHALL include the app ownership marker
- **AND** the payload SHALL include the business `callId`
- **AND** the payload SHALL include `callDirection` with the correct direction value

#### Scenario: Background push presents incoming call
- **WHEN** the app shows a native incoming call from a background push payload
- **THEN** the created CallKit payload SHALL include the same app ownership marker
- **AND** the payload SHALL preserve the business `callId` used by the app's call state

### Requirement: Native restore only trusts app-owned calls

The mobile client SHALL restore Flutter call state from native active calls only when the active native call can be validated as app-owned through the ownership marker and business call metadata. The client SHALL NOT adopt an arbitrary active native call when no validated app-owned match exists.

#### Scenario: Resume finds app-owned native call
- **WHEN** the app resumes and the native active-calls list contains a validated app-owned incoming or accepted call
- **THEN** the client SHALL restore Flutter call state from that native call
- **AND** the client SHALL navigate to the matching in-app call screen

#### Scenario: Resume finds only foreign native calls
- **WHEN** the app resumes and the native active-calls list contains no validated app-owned call
- **THEN** the client SHALL NOT restore Flutter call state from native calls
- **AND** the client SHALL NOT navigate to an in-app call screen from that native state alone

#### Scenario: Event call does not match validated active call
- **WHEN** a native call event arrives and no active native call can be validated as app-owned for that event
- **THEN** the client SHALL ignore the native restore path
- **AND** the client SHALL NOT fall back to the first active native call

### Requirement: Foreign native CallKit events are ignored

The mobile client SHALL ignore native CallKit events that cannot be proven to belong to the app's own call session.

#### Scenario: Foreign accept event
- **WHEN** a native accept event is received without a valid app ownership marker or business `callId`
- **THEN** the client SHALL ignore the event
- **AND** the client SHALL NOT trigger app call acceptance logic

#### Scenario: Foreign decline or end event
- **WHEN** a native decline or end event is received without a valid app ownership marker or business `callId`
- **THEN** the client SHALL ignore the event
- **AND** the client SHALL NOT mutate the current Flutter call state because of that event

### Requirement: Backend reconcile remains fallback for legitimate pending calls

If the client cannot validate a native call as app-owned, it SHALL rely on the backend reconcile flow to recover a legitimate pending incoming call.

#### Scenario: Native restore ignored but backend has pending call
- **WHEN** the app resumes, ignores ambiguous native call state, and the backend reports a pending incoming call for the user
- **THEN** the client SHALL present the pending incoming call from the backend response

#### Scenario: No validated native call and no pending backend call
- **WHEN** the app resumes and neither validated native state nor backend reconcile reports a pending incoming call
- **THEN** the client SHALL take no call-navigation action
