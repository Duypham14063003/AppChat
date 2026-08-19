## Why

The Nineteen Tech Internal App project has a complete SRS, architecture design, and tech stack decisions documented — but zero code infrastructure exists. Before any feature development (auth, chat, HR, etc.) can begin, the team needs a working monorepo structure with local development services (PostgreSQL 16 + Redis 7) running via Docker Compose. This is Task 0.1 in the project roadmap and blocks all subsequent tasks (0.2 NestJS scaffold, 0.3 Flutter scaffold, and beyond).

## What Changes

- Create monorepo root folder structure: `apps/api/` (NestJS placeholder) and `apps/mobile/` (Flutter placeholder)
- Create `docker-compose.yml` for local development with PostgreSQL 16 and Redis 7 containers using named Docker volumes
- Create `.env.example` with all environment variables documented in KICKOFF.md section 4 (dev + production templates)
- Create `.gitignore` covering Node.js, Flutter/Dart, Docker, IDE files, and sensitive files (`requirements/info.md`)
- Create root `README.md` with project overview, setup instructions, and tech stack summary

## Capabilities

### New Capabilities
- `local-dev-environment`: Docker Compose configuration for PostgreSQL 16 and Redis 7 local development services, environment variable management, and monorepo folder structure

### Modified Capabilities
<!-- No existing capabilities to modify — this is the first change in a greenfield project -->

## Impact

- **Repository structure**: Establishes the root monorepo layout that all future code lives in
- **Developer onboarding**: New devs can `docker compose up` to get PostgreSQL + Redis running immediately
- **Dependencies**: Requires Docker and Docker Compose installed on dev machines
- **Subsequent tasks**: Unblocks Task 0.2 (NestJS scaffold into `apps/api/`) and Task 0.3 (Flutter scaffold into `apps/mobile/`)
- **Git**: `.gitignore` prevents accidental commit of secrets, build artifacts, and IDE configs

