## ADDED Requirements

### Requirement: Users table exists with Odoo integration fields
The system SHALL have a `users` table with columns: id (uuid PK), odoo_uid (integer UNIQUE NOT NULL), email (varchar UNIQUE NOT NULL), name (varchar NOT NULL), avatar_url (text), department (varchar), job_title (varchar), is_active (boolean DEFAULT true), last_seen_at (timestamptz), created_at (timestamptz), updated_at (timestamptz).

#### Scenario: Users table created by migration
- **WHEN** TypeORM migrations are run
- **THEN** the `users` table exists with all specified columns, constraints, and defaults

### Requirement: User sessions table exists for multi-device auth
The system SHALL have a `user_sessions` table with columns: id (uuid PK), user_id (uuid FK → users), device_id (varchar), device_name (varchar), refresh_token_hash (varchar NOT NULL), fcm_token (text), last_used_at (timestamptz), last_ip (varchar(45)), expires_at (timestamptz NOT NULL), created_at (timestamptz).

#### Scenario: User sessions table created by migration
- **WHEN** TypeORM migrations are run
- **THEN** the `user_sessions` table exists with FK to users and all specified columns

### Requirement: Roles table exists with three default roles
The system SHALL have a `roles` table with columns: id (uuid PK), name (varchar UNIQUE NOT NULL), description (text), created_at (timestamptz). The migration SHALL seed three roles: admin, manager, employee.

#### Scenario: Roles seeded by migration
- **WHEN** TypeORM migrations are run
- **THEN** the `roles` table contains exactly three rows: admin, manager, employee

### Requirement: User roles junction table exists
The system SHALL have a `user_roles` table with columns: user_id (uuid FK → users), role_id (uuid FK → roles), assigned_at (timestamptz). The composite primary key SHALL be (user_id, role_id).

#### Scenario: User roles table created by migration
- **WHEN** TypeORM migrations are run
- **THEN** the `user_roles` table exists with composite PK and FKs to users and roles

### Requirement: Indexes exist for auth query performance
The system SHALL create indexes on: `users.email`, `users.odoo_uid`, `user_sessions.user_id`, `user_sessions.expires_at`.

#### Scenario: Auth indexes created by migration
- **WHEN** TypeORM migrations are run
- **THEN** indexes exist on users.email, users.odoo_uid, user_sessions.user_id, and user_sessions.expires_at

