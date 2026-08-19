## ADDED Requirements

### Requirement: Capacity is calculated from planned PoC effort
The system SHALL calculate planned capacity from active PoCs using `planned_start_at`, `demo_at`, and `estimated_hours`. MVP calculations SHALL exclude Odoo tasks, actual timesheets, attendance hours, and completed or cancelled future work.

#### Scenario: Aggregate developer weekly load
- **WHEN** a capacity query covers a week intersecting an active PoC work range
- **THEN** the system allocates the intersecting portion of estimated hours to the primary developer for that week

#### Scenario: Exclude terminal work
- **WHEN** a PoC is cancelled, completed, or marked not proceeding before a queried future period
- **THEN** the system excludes its remaining estimate from future planned capacity

#### Scenario: Revision consumes capacity
- **WHEN** a PoC returns to `in_progress` with outcome `revision_required`
- **THEN** its revised work plan contributes to capacity until the new `demo_at`

### Requirement: Capacity uses a deterministic MVP work calendar
The system SHALL use `Asia/Ho_Chi_Minh`, Monday through Friday, eight hours per workday, and forty hours per ISO week for MVP allocation and overload thresholds. Estimated hours spanning multiple working periods SHALL be allocated proportionally across the working-day portions within the plan range.

#### Scenario: Allocate a PoC across two weeks
- **WHEN** a PoC work range intersects working periods in two ISO weeks
- **THEN** each week receives only its proportional share of the PoC estimate

#### Scenario: Ignore non-working days in allocation
- **WHEN** a PoC range includes Saturday or Sunday
- **THEN** weekend time does not receive estimated-hour allocation

### Requirement: Capacity queries expose workload and schedule conflicts
The system SHALL return developer-level capacity hours, allocated hours, remaining or excess hours, daily load, weekly load, contributing PoCs, overlapping PoC ranges, and derived overload flags.

#### Scenario: Developer exceeds weekly capacity
- **WHEN** a developer's allocated PoC hours exceed forty hours in an ISO week
- **THEN** the response marks the developer over capacity and reports the excess hours

#### Scenario: Developer has overlapping PoCs
- **WHEN** two active PoCs assigned to one developer have intersecting planned ranges
- **THEN** the response identifies both PoCs and the overlap interval even if total weekly hours remain below forty

#### Scenario: Developer has available capacity
- **WHEN** allocated hours are below capacity and no plans overlap
- **THEN** the response reports remaining hours without an overload or overlap warning

### Requirement: Assignment preview uses current capacity data
The system SHALL provide capacity information for candidate active developers over a proposed PoC range before assignment and SHALL recompute it when the developer, planned start, estimate, or demo time changes.

#### Scenario: Preview candidate developer load
- **WHEN** a user opens assignment for a proposed plan
- **THEN** the system returns each candidate's existing load, projected load, remaining capacity, and conflicts for that range

#### Scenario: Assignment can proceed despite warning
- **WHEN** a candidate is projected to overlap or exceed capacity and the PoC data is otherwise valid
- **THEN** the system shows the warning but permits the user to confirm assignment

### Requirement: Approved leave is contextual rather than workload input
The capacity experience SHALL be able to display approved leave or other existing HR calendar context when available, but MVP workload totals SHALL remain based on the fixed work calendar and PoC estimates.

#### Scenario: Display leave beside PoC plans
- **WHEN** existing HR APIs report approved leave for a developer in the selected period
- **THEN** the UI displays that leave on the schedule without silently changing the backend PoC-hour total
