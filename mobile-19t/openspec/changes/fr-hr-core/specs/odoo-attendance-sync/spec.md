## ADDED Requirements

### Requirement: Batch sync attendance to Odoo every 15 minutes
The system SHALL run a BullMQ repeatable job every 15 minutes that queries all attendance records where `odoo_synced = false` and `checkout_at IS NOT NULL` (only sync completed records). For each record, the system SHALL call Odoo JSON-RPC `hr.attendance.create` with the employee's `odoo_uid`, `check_in` timestamp, and `check_out` timestamp. On success, update `odoo_synced = true` and `odoo_synced_at = now()`.

#### Scenario: Successful sync
- **WHEN** the sync job runs and finds 3 unsynced attendance records
- **THEN** all 3 are pushed to Odoo and marked as synced

#### Scenario: Odoo unreachable
- **WHEN** the sync job runs but Odoo is unreachable
- **THEN** the job fails and BullMQ retries with exponential backoff (2s, 4s, 8s, max 3 attempts). Records remain unsynced for next cycle.

#### Scenario: Partial sync failure
- **WHEN** the sync job processes 3 records but the 2nd fails
- **THEN** the 1st is marked synced, the 2nd and 3rd remain unsynced for next cycle

### Requirement: Extend OdooService with attendance write method
The system SHALL add a `writeAttendance(odooEmployeeId, checkinAt, checkoutAt)` method to `OdooService` that calls Odoo JSON-RPC `hr.attendance.create` with `{ employee_id, check_in, check_out }`. The method SHALL use the existing service account authentication.

#### Scenario: Write attendance to Odoo
- **WHEN** writeAttendance is called with employee_id 42, checkin "2026-03-15 08:00:00", checkout "2026-03-15 17:30:00"
- **THEN** a new hr.attendance record is created in Odoo

### Requirement: Map user to Odoo employee ID for sync
The system SHALL use the `users.odoo_uid` field to map 19T users to Odoo employee IDs when syncing attendance. If a user has no `odoo_uid`, the attendance record SHALL be skipped with a warning log.

#### Scenario: User has odoo_uid
- **WHEN** syncing attendance for a user with odoo_uid=42
- **THEN** the Odoo API call uses employee_id=42

#### Scenario: User missing odoo_uid
- **WHEN** syncing attendance for a user with null odoo_uid
- **THEN** the record is skipped and a warning is logged

