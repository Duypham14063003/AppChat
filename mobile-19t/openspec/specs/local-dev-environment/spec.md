## Requirements

### Requirement: Docker Compose provides PostgreSQL 16 for local development
The system SHALL provide a `docker-compose.yml` at the repository root that runs a PostgreSQL 16 container accessible on `localhost:5432` with database name, user, and password configurable via environment variables.

#### Scenario: Start PostgreSQL via Docker Compose
- **WHEN** developer runs `docker compose up -d` from the repository root
- **THEN** a PostgreSQL 16 container starts and accepts connections on `localhost:5432`

#### Scenario: PostgreSQL data persists across restarts
- **WHEN** developer runs `docker compose down` followed by `docker compose up -d`
- **THEN** all previously created databases and data are preserved via named Docker volume

#### Scenario: PostgreSQL credentials match .env.example defaults
- **WHEN** developer copies `.env.example` to `.env` without modifications
- **THEN** PostgreSQL container uses user `app_19t`, password `local_dev_password`, and database `app_19t_dev`

### Requirement: Docker Compose provides Redis 7 for local development
The system SHALL provide a Redis 7 container accessible on `localhost:6379` via the same `docker-compose.yml`, with data persisted via named Docker volume.

#### Scenario: Start Redis via Docker Compose
- **WHEN** developer runs `docker compose up -d` from the repository root
- **THEN** a Redis 7 container starts and accepts connections on `localhost:6379`

#### Scenario: Redis data persists across restarts
- **WHEN** developer runs `docker compose down` followed by `docker compose up -d`
- **THEN** Redis data (keys, queues) are preserved via named Docker volume

### Requirement: Environment variable template exists
The system SHALL provide a `.env.example` file at the repository root containing all environment variables needed for local development and production, with safe placeholder values for secrets.

#### Scenario: Developer sets up local environment
- **WHEN** developer copies `.env.example` to `.env`
- **THEN** the `.env` file contains working default values for local development (localhost PostgreSQL + Redis) without requiring any edits

#### Scenario: Production variables are documented
- **WHEN** developer inspects `.env.example`
- **THEN** all production environment variables (Odoo, Firebase, Agora, Bunny.net, AI) are listed with empty placeholder values and comments

### Requirement: Monorepo folder structure exists
The system SHALL have a monorepo root with `apps/api/` directory (for NestJS backend) and `apps/mobile/` directory (for Flutter app), each containing a `.gitkeep` placeholder file.

#### Scenario: Folder structure is ready for scaffolding
- **WHEN** developer clones the repository
- **THEN** directories `apps/api/` and `apps/mobile/` exist and are tracked by git

### Requirement: Git ignores sensitive and generated files
The system SHALL provide a `.gitignore` at the repository root that excludes Node.js artifacts, Flutter/Dart artifacts, Docker volumes, IDE configs, environment files, and sensitive credential files.

#### Scenario: Node.js artifacts are ignored
- **WHEN** `node_modules/` or `dist/` directories exist in `apps/api/`
- **THEN** they are not tracked by git

#### Scenario: Flutter artifacts are ignored
- **WHEN** `.dart_tool/`, `build/`, or `.flutter-plugins` exist in `apps/mobile/`
- **THEN** they are not tracked by git

#### Scenario: Environment files are ignored
- **WHEN** `.env` file exists at repository root
- **THEN** it is not tracked by git (but `.env.example` IS tracked)

#### Scenario: Sensitive files are ignored
- **WHEN** `requirements/info.md` exists
- **THEN** future changes to it are not tracked by git

### Requirement: Project README provides setup instructions
The system SHALL provide a `README.md` at the repository root with project overview, tech stack summary, prerequisites, and step-by-step local development setup instructions.

#### Scenario: New developer onboarding
- **WHEN** a new developer reads `README.md`
- **THEN** they find instructions to: install prerequisites, clone repo, copy `.env.example`, run `docker compose up -d`, and verify services are running
