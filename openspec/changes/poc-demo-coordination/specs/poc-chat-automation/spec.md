## ADDED Requirements

### Requirement: PoC lifecycle changes appear in the working conversation
The system SHALL create structured chat system messages for assignment, reassignment, material plan changes, readiness, revision, cancellation, overdue detection, and demonstration when a PoC has a working conversation.

#### Scenario: Publish an assignment event
- **WHEN** a user assigns a developer to a PoC with a working conversation
- **THEN** the conversation receives a realtime system message containing PoC identity, developer, actor, planned start, estimate, `demo_at`, and deep link

#### Scenario: Publish old and new schedule values
- **WHEN** a user changes the planned start, estimate, developer, or `demo_at`
- **THEN** the conversation event identifies the changed fields and their previous and current values

#### Scenario: PoC has no working conversation
- **WHEN** a PoC lifecycle change occurs without a working conversation
- **THEN** the authoritative PoC mutation succeeds without creating a chat message

### Requirement: PoC reminders use independent idempotent scheduling
The system SHALL schedule PoC jobs independently from message-linked chat reminders, use deterministic job identity, and persist a unique delivery event before producing each reminder result.

#### Scenario: Schedule standard demo reminders
- **WHEN** a PoC is assigned or rescheduled with sufficient future lead time
- **THEN** the system schedules applicable 24-hour, 30-minute, and deadline checks for its current `demo_at`

#### Scenario: Plan is created inside a reminder window
- **WHEN** a PoC is assigned less than 24 hours before `demo_at`
- **THEN** the system skips elapsed lead-time reminders and schedules only future applicable jobs

#### Scenario: Reschedule a PoC
- **WHEN** `demo_at` changes
- **THEN** obsolete pending jobs are removed or made harmless and the system schedules jobs for the new time

#### Scenario: Retry an already delivered event
- **WHEN** a worker retries a PoC notification event already claimed or delivered
- **THEN** the system does not create a duplicate chat event or duplicate push notification

### Requirement: Notification recipients follow the PoC event
The system SHALL send targeted push notifications using existing active user sessions and event-specific recipient rules.

#### Scenario: Notify assigned developer
- **WHEN** a developer is assigned or a deadline reminder fires
- **THEN** the system sends the relevant push to that primary developer's active sessions

#### Scenario: Notify sale owner that PoC is ready
- **WHEN** a PoC enters `ready`
- **THEN** the system notifies the sale/request owner and includes a deep link to the PoC

#### Scenario: Notification service is unavailable
- **WHEN** push or chat delivery fails after a PoC mutation commits
- **THEN** the PoC remains committed and the delivery event is retryable or marked failed for operational visibility

### Requirement: Overdue checks are state-aware
The system SHALL evaluate current state at `demo_at` before publishing an overdue event.

#### Scenario: PoC misses readiness deadline
- **WHEN** the deadline job runs and the PoC has not reached `ready`, `demonstrated`, `cancelled`, or another terminal outcome
- **THEN** the system emits one overdue event and notifies the developer and sale owner

#### Scenario: PoC was ready before deadline
- **WHEN** the deadline job runs after the PoC reached `ready`
- **THEN** the system does not emit an overdue event

### Requirement: Weekly PoC reporting uses the configured main conversation
The system SHALL default `POC_REPORT_CONVERSATION_ID` to `35353995-517b-4fcb-b4d7-e0f23c5f4042` and SHALL publish the weekly PoC summary at Friday 12:00 in `Asia/Ho_Chi_Minh`.

#### Scenario: Publish the scheduled weekly summary
- **WHEN** the Friday publication job runs for an ISO week
- **THEN** the system posts a bot-authored summary to the configured conversation and stores its message ID against that week

#### Scenario: Weekly summary contents
- **WHEN** a summary is generated
- **THEN** it contains counts by relevant state, overdue PoCs, chronologically ordered demos, sale and developer names, developer planned capacity, overload warnings, and a deep link to the weekly view

### Requirement: Each week has one stable summary message
The system SHALL maintain at most one PoC weekly-report record and one current summary message per ISO week in the configured conversation.

#### Scenario: Refresh after PoC changes
- **WHEN** relevant PoC data changes after that week's summary was published
- **THEN** a debounced job edits the existing bot message and updates its snapshot metadata instead of posting another summary

#### Scenario: Weekly publisher retries
- **WHEN** the scheduled publisher retries after the weekly message was created
- **THEN** the system reuses the stored message and does not create a duplicate weekly summary

#### Scenario: Operator manually refreshes report
- **WHEN** an authorized authenticated user triggers recovery refresh for a week
- **THEN** the system regenerates figures from authoritative PoC data and creates or updates the stable weekly message

### Requirement: PoC chat projections are distinguishable from other bot traffic
The system SHALL attach PoC-specific metadata kinds and PoC deep-link context to lifecycle and weekly report messages.

#### Scenario: Client receives PoC system metadata
- **WHEN** a PoC chat event arrives in a conversation also used for daily reports
- **THEN** the client can identify it as PoC content and render its PoC-specific presentation without parsing free-form text
