## ADDED Requirements

### Requirement: Attendance history SHALL only show approved leave-derived records
The system SHALL include leave-derived attendance history records only when the leave request status is `approved`.

#### Scenario: Pending leave overlaps the selected month
- **WHEN** a leave or OT request overlaps the selected attendance-history month but its status is not `approved`
- **THEN** the system SHALL exclude it from the attendance history leave dataset

#### Scenario: Approved leave overlaps the selected month
- **WHEN** a leave or OT request overlaps the selected attendance-history month and its status is `approved`
- **THEN** the system SHALL include it in the attendance history leave dataset

### Requirement: Attendance history calendar SHALL only mark approved leave-derived days
The system SHALL render leave-derived calendar markers only for days covered by approved leave or approved OT requests.

#### Scenario: Rejected leave covers a day in the calendar month
- **WHEN** a rejected or non-approved leave request covers a day in the selected month
- **THEN** the attendance-history calendar SHALL NOT render a leave marker for that request

#### Scenario: Approved OT request covers a day in the calendar month
- **WHEN** an approved OT request covers a day in the selected month
- **THEN** the attendance-history calendar SHALL render the leave-derived marker for that request

### Requirement: Attendance history day list SHALL only show approved leave-derived entries
The system SHALL show leave-derived rows in the attendance-history detail list only for approved leave and approved OT requests.

#### Scenario: User selects a day covered by a submitted leave request
- **WHEN** the selected day is covered only by a leave or OT request whose status is not `approved`
- **THEN** the attendance-history detail list SHALL NOT show a leave-derived entry for that request

#### Scenario: User selects a day covered by an approved leave request
- **WHEN** the selected day is covered by an approved leave or approved OT request
- **THEN** the attendance-history detail list SHALL show the corresponding leave-derived entry
