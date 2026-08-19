## ADDED Requirements

### Requirement: Config validation fails fast on missing variables
The application SHALL validate all required environment variables at startup using a Joi schema. If any required variable is missing or invalid, the application SHALL refuse to start and log a clear error message indicating which variables are missing.

#### Scenario: Missing required DB_HOST variable
- **WHEN** the application starts without `DB_HOST` defined in the environment
- **THEN** the application exits with a non-zero code and logs an error message containing "DB_HOST"

#### Scenario: All required variables present
- **WHEN** the application starts with all required environment variables defined
- **THEN** the ConfigService provides typed access to all configuration values

### Requirement: Config schema covers all environment variables
The Joi validation schema SHALL require the following variables: DB_HOST, DB_PORT, DB_USER, DB_NAME, DB_PASSWORD, REDIS_HOST, REDIS_PORT, PORT, JWT_ACCESS_SECRET, JWT_REFRESH_SECRET, JWT_ACCESS_TTL, JWT_REFRESH_TTL. Optional variables (ODOO_*, FIREBASE_*, AGORA_*, BUNNY_*, AI_*) SHALL have sensible defaults or be allowed to be empty.

#### Scenario: Dev environment starts with minimal config
- **WHEN** developer copies `.env.example` to `.env` without modifications
- **THEN** the application starts successfully using the default development values

#### Scenario: Production variables are optional at dev time
- **WHEN** ODOO_URL, FIREBASE_PROJECT_ID, AGORA_APP_ID are not set
- **THEN** the application starts successfully (these are only required when their respective modules are activated)

