## ADDED Requirements

### Requirement: Authenticated users can create structured PoC requests
The system SHALL allow any authenticated active non-bot user to create a PoC request containing customer/project title, requirement description, product type, priority, demo time, and an optional working conversation, source message, and reference links. The system SHALL record the creator as the sale/request owner and SHALL use `demo_at` as both the completion deadline and customer demo schedule.

#### Scenario: Create an unassigned PoC request
- **WHEN** an authenticated active user submits valid request data with a future `demo_at`
- **THEN** the system creates an `unassigned` PoC owned by that user without requiring a developer or coordinator role

#### Scenario: Create a request from chat
- **WHEN** a user creates a PoC from a message in a conversation they belong to
- **THEN** the system stores the source message and working conversation references while keeping the PoC as the authoritative record

#### Scenario: Reject an invalid demo time
- **WHEN** a user submits a new PoC whose `demo_at` is not in the future
- **THEN** the system rejects the request without creating a PoC

### Requirement: Any active user can assign one primary developer
The system SHALL allow any authenticated active non-bot user to assign or reassign exactly one active primary developer. Assignment SHALL require a planned start before `demo_at` and positive estimated hours, and SHALL record the assigning actor.

#### Scenario: Assign an unassigned PoC
- **WHEN** any active user selects an active developer, valid planned start, and positive estimate for an unassigned PoC
- **THEN** the system stores the single developer, assigning actor, work plan, and changes the status to `assigned`

#### Scenario: Reassign an active PoC
- **WHEN** any active user changes the developer on an assigned or in-progress PoC
- **THEN** the system replaces the primary developer, records old and new values in history, and keeps only one current primary developer

#### Scenario: Reject an invalid work plan
- **WHEN** an assignment has no developer, a non-positive estimate, or a planned start at or after `demo_at`
- **THEN** the system rejects the assignment and preserves the previous PoC state

### Requirement: PoCs follow a controlled lifecycle
The system SHALL enforce the persisted states `unassigned`, `assigned`, `in_progress`, `ready`, `demonstrated`, and `cancelled`. A demonstrated PoC SHALL have an outcome of `completed`, `revision_required`, or `not_proceeding`.

#### Scenario: Developer work reaches demonstration
- **WHEN** users move a PoC through `assigned`, `in_progress`, `ready`, and `demonstrated`
- **THEN** the system records each valid transition and its timestamp in order

#### Scenario: Revision is required after demonstration
- **WHEN** a demonstrated PoC receives outcome `revision_required` with a new future `demo_at`
- **THEN** the system returns it to `in_progress`, clears the prior demonstrated completion state as appropriate, and records a revision history event

#### Scenario: Complete or stop after demonstration
- **WHEN** a demonstrated PoC receives outcome `completed` or `not_proceeding`
- **THEN** the system treats it as terminal for future capacity and reminders

#### Scenario: Cancel an active PoC
- **WHEN** a user cancels a non-terminal PoC with a reason
- **THEN** the system changes it to `cancelled`, records the actor and reason, and removes future planned capacity and notifications

#### Scenario: Reject an invalid transition
- **WHEN** a user requests a lifecycle transition that is not allowed from the current state
- **THEN** the system rejects it without changing the PoC

### Requirement: Schedule and assignment changes are auditable
The system SHALL append immutable history for creation, assignment, reassignment, estimate changes, planned-start changes, demo rescheduling, status changes, link changes, outcomes, and cancellation. History SHALL identify the actor and retain relevant previous and new values.

#### Scenario: Reschedule a demo
- **WHEN** a user changes `demo_at`
- **THEN** the system records both timestamps, the actor, and the resulting readable-code change in PoC history

#### Scenario: View PoC history
- **WHEN** an authenticated user opens a PoC detail history
- **THEN** the system returns chronological actor-attributed events without requiring chat history parsing

### Requirement: Concurrent updates cannot silently overwrite PoC state
The system SHALL version PoC records and require mutations to target the version last read by the client.

#### Scenario: Update the latest version
- **WHEN** a mutation supplies the current PoC version
- **THEN** the system applies the change atomically and increments the version

#### Scenario: Reject a stale assignment
- **WHEN** a second user submits an assignment or schedule update using a stale version
- **THEN** the system returns a conflict with the latest PoC representation and does not overwrite the newer change

### Requirement: Human-readable PoC codes are backend-owned
The system SHALL use UUID as the immutable PoC identity and SHALL generate a collision-safe readable code on first assignment using the operational sale, developer, product, sequence, and demo schedule convention. The system SHALL regenerate the display code when code-bearing assignment or schedule values change and preserve previous codes in history.

#### Scenario: Generate code on assignment
- **WHEN** an unassigned PoC is assigned for the first time
- **THEN** the backend atomically allocates its sequence and returns a readable code without accepting a client-supplied code

#### Scenario: Follow a link after code change
- **WHEN** a developer or demo schedule change regenerates the display code
- **THEN** existing UUID-based API and deep links still resolve the same PoC

### Requirement: PoCs can be queried for coordination queues
The system SHALL provide paginated and filterable PoC queries for requests created by the current user, PoCs assigned to the current user, unassigned PoCs, a selected demo week, status, developer, sale owner, priority, and text search.

#### Scenario: Developer views assigned PoCs
- **WHEN** a user filters by current-user assignment
- **THEN** the system returns PoCs where that user is the primary developer ordered by attention and demo time

#### Scenario: User views the unassigned queue
- **WHEN** any authenticated user requests unassigned PoCs
- **THEN** the system returns requests awaiting developer assignment regardless of that user's role

### Requirement: Time-sensitive attention is derived from authoritative state
The system SHALL derive overdue and upcoming-demo indicators from `demo_at` and current lifecycle state rather than persisting them as workflow states.

#### Scenario: Derive overdue PoC
- **WHEN** `demo_at` has passed and the PoC was not ready or terminal by the deadline
- **THEN** queries mark the PoC overdue without changing its persisted lifecycle status

#### Scenario: Terminal PoC is not overdue
- **WHEN** a PoC is cancelled, completed, or not proceeding
- **THEN** future queries do not mark it overdue
