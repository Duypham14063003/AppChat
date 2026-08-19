## ADDED Requirements

### Requirement: PoC is available from the responsive Work hub
The Flutter application SHALL expose PoC and existing Task views within a visible Work destination using a segmented or tabbed mode selector, and SHALL keep root mobile navigation at no more than five destinations.

#### Scenario: Open Work on a narrow viewport
- **WHEN** an authenticated user selects Work on a mobile viewport
- **THEN** the app opens a full-screen PoC/Task hub with stable bottom navigation and no sixth destination

#### Scenario: Preserve employee management access
- **WHEN** an authorized HR user needs employee management after Work is added
- **THEN** the app exposes employee management from HR while preserving its existing routes and authorization

#### Scenario: Open Work on a wide viewport
- **WHEN** an authenticated user opens Work on a desktop or tablet viewport
- **THEN** the app uses the existing navigation rail and responsive content area without nested root navigation

### Requirement: Users can scan and filter PoC coordination queues
The PoC list SHALL provide `My requests`, `My PoCs`, `Unassigned`, and `This week` modes plus search and filters for status, developer, sale owner, priority, and demo period. List items SHALL display code or unassigned state, customer/title, status, sale, developer, estimate, and demo time.

#### Scenario: View unassigned requests
- **WHEN** any authenticated user selects `Unassigned`
- **THEN** the list shows requests awaiting assignment and provides an assignment action

#### Scenario: View current developer work
- **WHEN** a user selects `My PoCs`
- **THEN** the list shows PoCs assigned to that user ordered by overdue/attention state and demo time

#### Scenario: Empty or failed queue
- **WHEN** a query returns no PoCs or fails
- **THEN** the UI displays a clear empty or retry state without shifting navigation or hiding available actions

### Requirement: Request creation is concise and can start from chat
The app SHALL provide a PoC request form for customer/title, requirement, product type, priority, `demo_at`, working conversation, and reference links. The form SHALL not ask the user to create a PoC code.

#### Scenario: Create from Work
- **WHEN** a user completes the form with valid required values
- **THEN** the app submits the request and opens the resulting PoC detail

#### Scenario: Create from a chat message
- **WHEN** a user chooses `Create PoC request` from a normal chat message action
- **THEN** the form opens prefilled with that conversation and source message context

#### Scenario: Invalid demo schedule
- **WHEN** the selected `demo_at` is not in the future
- **THEN** the form explains the validation error and does not submit

### Requirement: Assignment shows candidate capacity before confirmation
The assignment experience SHALL let any authenticated user choose one active developer, planned start, estimated hours, and `demo_at`, and SHALL show each candidate's existing and projected capacity, overlaps, and overload warnings.

#### Scenario: Compare candidate developers
- **WHEN** the assignment screen loads for a valid plan range
- **THEN** each candidate row shows current/projected weekly hours and a clear normal, overlap, or overload state

#### Scenario: Confirm an overloaded assignment
- **WHEN** the selected developer has a warning
- **THEN** the UI requires explicit confirmation but allows the valid assignment

#### Scenario: Reassign developer
- **WHEN** a user changes the primary developer
- **THEN** the UI identifies the existing developer, previews the replacement's capacity, and submits the current record version

### Requirement: PoC detail exposes current truth and history
The detail screen SHALL display lifecycle progress, sale owner, primary developer, estimate, planned start, `demo_at`, PoC link, working conversation, derived attention flags, post-demo outcome, and chronological audit history. It SHALL provide valid context-sensitive actions such as assign, start, mark ready, record demo, revise, cancel, open chat, and update link.

#### Scenario: Developer marks PoC ready
- **WHEN** the primary developer or another active user invokes `Mark ready` from an in-progress PoC
- **THEN** the UI confirms the action, updates the detail, and shows the new history event

#### Scenario: Record revision after demo
- **WHEN** a user selects `Revision required` after demonstration
- **THEN** the UI requires a new future demo time and revised plan before returning the PoC to in-progress

#### Scenario: Open working conversation
- **WHEN** the PoC has a working conversation and the user selects `Open chat`
- **THEN** the app navigates to that conversation using the existing chat route

### Requirement: Stale edits are recoverable
The app SHALL include the last-read PoC version with mutations and SHALL handle backend conflicts without silently discarding either user's work.

#### Scenario: Another user changed the PoC
- **WHEN** an assignment or edit returns a version conflict
- **THEN** the app explains that the PoC changed, displays or reloads the latest values, and asks the user to review before resubmitting

### Requirement: Capacity adapts to viewport size
The app SHALL provide a selected-week capacity view available to authenticated users. Wide layouts SHALL use a developer-by-day timeline with PoC spans; narrow layouts SHALL use developer summaries and expandable PoC schedules. Both SHALL show allocated/capacity hours, overload, overlaps, and contextual approved leave when available.

#### Scenario: Review capacity on desktop
- **WHEN** the capacity view width is at least the app's wide-layout breakpoint
- **THEN** developers appear as stable rows against day columns with non-overlapping labels and visible overload indicators

#### Scenario: Review capacity on mobile
- **WHEN** the capacity view is narrow
- **THEN** the app presents scan-friendly developer summaries without requiring horizontal navigation for primary actions

### Requirement: Weekly PoC report is reviewable in the app
The app SHALL show the selected week's authoritative PoC counts, demo schedule, overdue items, and developer capacity, and SHALL provide a deep-link target for the bot summary.

#### Scenario: Open report from chat
- **WHEN** a user taps the weekly PoC summary deep link
- **THEN** the app opens the matching week in the PoC weekly view

#### Scenario: Refresh weekly figures
- **WHEN** a user refreshes the weekly view
- **THEN** the app reloads figures from structured PoC APIs rather than parsing the chat summary

### Requirement: PoC chat events have structured presentation
The app SHALL render PoC assignment, schedule, reminder, overdue, readiness, and weekly-summary metadata as concise chat cards with a command to open the PoC.

#### Scenario: Render schedule change event
- **WHEN** chat receives a PoC schedule-change system message
- **THEN** the card shows the old and new demo times, actor, primary developer, and an open-detail action

#### Scenario: Unknown PoC metadata version
- **WHEN** a client receives a newer or malformed PoC metadata payload
- **THEN** it falls back to safe system-message text without breaking the chat timeline
