## ADDED Requirements

### Requirement: Odoo service can fetch all active employees
The `OdooService` SHALL provide a `fetchEmployees()` method that authenticates as the service account (using `ODOO_SERVICE_USERNAME` and `ODOO_API_KEY` env vars) and calls Odoo JSON-RPC `execute_kw` on model `hr.employee` with `search_read` method. The query SHALL filter `[["active", "=", true]]` and request fields: `name`, `work_email`, `department_id`, `job_title`, `image_128`. The method SHALL return a typed array of employee records.

#### Scenario: Fetch employees from Odoo
- **WHEN** `fetchEmployees()` is called
- **THEN** it authenticates via `POST {ODOO_URL}/web/session/authenticate` with service account credentials, then calls `POST {ODOO_URL}/jsonrpc` with `hr.employee` `search_read`, and returns all active employees

#### Scenario: Odoo unreachable
- **WHEN** Odoo is unreachable or times out (10s)
- **THEN** the method throws a ServiceUnavailableException with a descriptive message

#### Scenario: Odoo credentials not configured
- **WHEN** `ODOO_SERVICE_USERNAME` or `ODOO_API_KEY` is empty
- **THEN** the method logs a warning and returns an empty array (graceful skip)

### Requirement: Auth service can sync users from Odoo employee data
The `AuthService` SHALL provide a `syncUsersFromOdoo()` method that calls `OdooService.fetchEmployees()`, then for each employee: upsert into the `users` table matching on `odoo_uid` (from Odoo's employee `user_id` or record `id`). Fields mapped: `name`, `email` (from `work_email`), `department` (from `department_id[1]`), `job_title`. Users in the database whose `odoo_uid` is NOT in the Odoo response SHALL be marked `is_active = false` (soft deactivation).

#### Scenario: New employee synced
- **WHEN** Odoo returns an employee not yet in the users table
- **THEN** a new user record is created with odoo_uid, name, email, department, job_title, is_active=true, and default Employee role

#### Scenario: Existing employee updated
- **WHEN** Odoo returns an employee whose odoo_uid matches an existing user
- **THEN** the user's name, email, department, and job_title are updated from Odoo data

#### Scenario: Employee removed from Odoo
- **WHEN** a user exists in the database but their odoo_uid is not in the Odoo response
- **THEN** the user's is_active is set to false

### Requirement: Seeder script for one-time user sync
The project SHALL provide a seeder script runnable via `npm run seed:users` (in apps/api) that calls `AuthService.syncUsersFromOdoo()` and logs the number of users created, updated, and deactivated.

#### Scenario: Run seeder
- **WHEN** developer runs `npm run seed:users`
- **THEN** all active Odoo employees are synced to the users table and a summary is printed

### Requirement: BullMQ cron job for recurring user sync
The project SHALL register a BullMQ repeatable job that runs `AuthService.syncUsersFromOdoo()` every 1 hour. The job SHALL be registered in the auth module with a named queue.

#### Scenario: Hourly sync runs
- **WHEN** 1 hour has elapsed since the last sync
- **THEN** BullMQ triggers the sync job, which upserts users from Odoo

#### Scenario: Sync job fails
- **WHEN** the sync job throws an error (e.g., Odoo unreachable)
- **THEN** BullMQ retries 3 times with exponential backoff (2s, 4s, 8s)

