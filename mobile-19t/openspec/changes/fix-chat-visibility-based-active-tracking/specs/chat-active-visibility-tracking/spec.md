## ADDED Requirements

### Requirement: Chat auto-read SHALL depend on visible foreground activity
The mobile chat client SHALL treat a conversation as actively viewed only while that conversation's chat route is visibly foregrounded and the app is in an interactive foreground lifecycle state. The client SHALL NOT send automatic read receipts for a conversation that remains mounted but is no longer visibly active.

#### Scenario: Visible chat route receives new messages
- **WHEN** the user is actively viewing a conversation in the foreground chat route and new messages arrive for that same conversation
- **THEN** the client SHALL allow automatic read handling for that conversation
- **AND** the client SHALL continue sending websocket `mark_read` updates according to existing read behavior

#### Scenario: Mounted chat route is hidden by branch or route change
- **WHEN** a conversation screen remains mounted because navigation preserves branch state but the user has switched away from that visible chat route
- **THEN** the client SHALL stop treating that conversation as actively viewed
- **AND** the client SHALL NOT auto-send `mark_read` for subsequent messages until the conversation becomes visibly foregrounded again

#### Scenario: App moves to background while chat remains on top
- **WHEN** the app transitions out of the interactive foreground while a conversation route is otherwise still selected
- **THEN** the client SHALL suspend automatic read handling for that conversation

### Requirement: Active chat visibility SHALL be updated immediately on route visibility changes
The mobile chat client SHALL update its active conversation tracking immediately when chat route visibility changes, without waiting for widget disposal.

#### Scenario: User leaves chat but widget is not disposed
- **WHEN** the user navigates away from a chat screen and the router keeps that screen mounted
- **THEN** the client SHALL clear or demote that conversation from active-view state as part of the visibility transition
- **AND** the client SHALL NOT wait for `dispose()` before suppressing auto-read behavior

#### Scenario: User returns to the same chat route
- **WHEN** the user navigates back to a previously preserved chat route and it becomes visibly foregrounded again
- **THEN** the client SHALL restore active-view tracking for that conversation
- **AND** the client SHALL allow subsequent automatic read handling again

### Requirement: All automatic read paths SHALL use the same active-view gate
The mobile chat client SHALL evaluate the same visibility-based active conversation gate before sending automatic read receipts from any automatic read path.

#### Scenario: API refresh reconciliation runs after route is hidden
- **WHEN** a background refresh, synchronization pass, or inbound message handler attempts to auto-mark a conversation as read after that conversation has lost visible active status
- **THEN** the client SHALL block the automatic `mark_read` send for that conversation

#### Scenario: Active conversation differs from incoming conversation
- **WHEN** automatic read logic is invoked for a conversation that is not the currently visible active conversation
- **THEN** the client SHALL leave that conversation unread from the mobile side until the user visibly re-enters it
