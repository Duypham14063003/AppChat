## ADDED Requirements

### Requirement: Users can create message-linked reminders from chat messages
The system SHALL allow a user to create a reminder from a normal chat message and choose whether the reminder should notify only the creator or everyone in the conversation.

#### Scenario: Create reminder for self
- **WHEN** a user creates a reminder from a non-system chat message and selects the `self` audience with a future reminder time
- **THEN** the system stores the reminder as a pending reminder owned by that user

#### Scenario: Create reminder for everyone
- **WHEN** a user creates a reminder from a non-system chat message and selects the `everyone` audience with a future reminder time
- **THEN** the system stores the reminder as a pending reminder for that conversation audience

#### Scenario: Reject reminder for invalid source message
- **WHEN** a user attempts to create a reminder for a message that is not a normal message in the same conversation
- **THEN** the system rejects the request

### Requirement: Reminder lifecycle events appear in the chat timeline
The system SHALL create chat-visible system messages when a reminder is created, updated, cancelled, or fired.

#### Scenario: Reminder creation inserts system message
- **WHEN** a reminder is created successfully
- **THEN** the conversation receives a system message that identifies the reminder event and includes metadata for the source message preview, reminder time, creator, and audience

#### Scenario: Reminder update inserts system message
- **WHEN** the reminder creator updates an existing reminder
- **THEN** the conversation receives a system message describing the reminder update

#### Scenario: Reminder cancellation inserts system message
- **WHEN** the reminder creator cancels an existing reminder
- **THEN** the conversation receives a system message describing the reminder cancellation

#### Scenario: Reminder firing inserts system message
- **WHEN** a pending reminder reaches its scheduled time
- **THEN** the conversation receives a system message describing the fired reminder

### Requirement: Reminder recipients follow the selected audience
The system SHALL notify reminder recipients according to the reminder audience selected at creation or most recent update time.

#### Scenario: Self reminder fires
- **WHEN** a reminder with audience `self` fires
- **THEN** only the reminder creator is notified by the reminder delivery flow

#### Scenario: Everyone reminder fires
- **WHEN** a reminder with audience `everyone` fires
- **THEN** the system notifies all intended conversation recipients for that reminder

### Requirement: Reminder updates and cancellations are creator-owned
The system SHALL allow the reminder creator to update or cancel a pending reminder and SHALL reject lifecycle changes from unauthorized users.

#### Scenario: Creator updates reminder
- **WHEN** the reminder creator changes the reminder audience or reminder time before it fires
- **THEN** the system updates the pending reminder and reschedules delivery

#### Scenario: Creator cancels reminder
- **WHEN** the reminder creator cancels a pending reminder
- **THEN** the system marks the reminder as cancelled and prevents it from firing

#### Scenario: Non-creator attempts reminder change
- **WHEN** a user who did not create the reminder attempts to update or cancel it
- **THEN** the system rejects the request

### Requirement: Duplicate reminders at the same time are prevented within scope
The system SHALL allow multiple reminders on the same source message, but SHALL reject duplicate reminders at the same scheduled time within the same audience scope rules.

#### Scenario: Reject duplicate self reminder
- **WHEN** the same user creates or updates a `self` reminder on the same source message for a time that already exists on another active `self` reminder they own
- **THEN** the system rejects the duplicate reminder

#### Scenario: Reject duplicate everyone reminder
- **WHEN** a user creates or updates an `everyone` reminder on the same source message for a time that already exists on another active `everyone` reminder
- **THEN** the system rejects the duplicate reminder

#### Scenario: Allow distinct reminders on same message
- **WHEN** reminders on the same source message differ by scheduled time or audience scope
- **THEN** the system allows them to coexist

### Requirement: Reminder firing is idempotent
The system SHALL ensure reminder delivery creates at most one fired reminder result for a given reminder even if the scheduling worker retries.

#### Scenario: Worker retries fired reminder job
- **WHEN** a reminder firing job is retried after the reminder has already transitioned to fired
- **THEN** the system does not create duplicate fired system messages or duplicate recipient notifications
