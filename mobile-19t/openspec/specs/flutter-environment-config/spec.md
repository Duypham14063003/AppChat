## Requirements

### Requirement: Environment config is loaded from JSON files
The application SHALL read environment configuration (API_URL, APP_NAME, environment name) from JSON files passed via `--dart-define-from-file`. The config values SHALL be accessible throughout the app via a typed configuration class.

#### Scenario: Dev config provides localhost API URL
- **WHEN** app is launched with `--dart-define-from-file=config/dev.json`
- **THEN** the app's API_URL is `http://localhost:3000`

#### Scenario: Prod config provides production API URL
- **WHEN** app is launched with `--dart-define-from-file=config/prod.json`
- **THEN** the app's API_URL is `https://api.19t.vn`

### Requirement: Environment name is visible in debug mode
The application SHALL display the current environment name (DEV, STAGING, PROD) in a debug banner or indicator when not in production mode.

#### Scenario: Dev environment shows indicator
- **WHEN** app runs in dev environment
- **THEN** a visual indicator shows "DEV" environment name
