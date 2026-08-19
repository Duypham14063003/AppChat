## ADDED Requirements

### Requirement: Payroll config database table
The system SHALL create a `payroll_config` table with columns: `id` (integer PK DEFAULT 1), `payroll_start_day` (integer DEFAULT 1, range 1-28), `standard_hours_per_day` (decimal(4,2) DEFAULT 8.0), `standard_days_per_month` (integer DEFAULT 22), `work_start_time` (time DEFAULT '08:00'), `checkin_reminder_time` (time nullable, e.g., '09:15'), `checkout_reminder_time` (time nullable, e.g., '18:30'), `auto_checkout_enabled` (boolean DEFAULT false), `auto_checkout_time` (time DEFAULT '23:59'), `updated_at` (timestamptz DEFAULT now()). CHECK constraint: `id = 1` (singleton).

#### Scenario: Singleton config row
- **WHEN** the system starts and no config exists
- **THEN** a default config row with id=1 is created with all default values

### Requirement: Get payroll config via REST API
The system SHALL expose `GET /hr/config` returning the current payroll configuration. Any authenticated user can read the config.

#### Scenario: Read config
- **WHEN** any user sends GET /hr/config
- **THEN** the system returns the payroll config with all fields

### Requirement: Update payroll config via REST API
The system SHALL expose `PATCH /hr/config` (admin only) accepting partial updates to any config field. The endpoint SHALL validate: payroll_start_day between 1-28, standard_hours_per_day between 1-24, time fields in HH:mm format.

#### Scenario: Admin updates standard hours
- **WHEN** an admin sends PATCH /hr/config with { standard_hours_per_day: 7.5 }
- **THEN** the config is updated and future OT calculations use 7.5h as standard

#### Scenario: Admin configures reminder times
- **WHEN** an admin sends PATCH /hr/config with { checkin_reminder_time: "09:30", checkout_reminder_time: "18:00" }
- **THEN** the reminder cron jobs use the new times

#### Scenario: Non-admin attempts to update
- **WHEN** a regular employee sends PATCH /hr/config
- **THEN** the system returns 403 Forbidden

### Requirement: Flutter payroll config screen
The system SHALL provide a PayrollConfigScreen (admin only, accessible from HR settings) with form fields for all configurable values. Changes are saved via PATCH /hr/config.

#### Scenario: Admin edits config
- **WHEN** an admin opens the config screen and changes payroll_start_day to 20
- **THEN** the change is saved to the server and takes effect immediately

