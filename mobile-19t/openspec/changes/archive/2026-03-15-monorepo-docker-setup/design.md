## Context

Greenfield project — Nineteen Tech Internal App. No code exists yet, only documentation (SRS, requirements, mockups). The team needs a working local development environment before any feature work can begin.

Current state:
- Repository contains only documentation: `KICKOFF.md`, `requirements/`, `srs/`
- No code, no configs, no Docker files
- Tech stack decided: NestJS (backend), Flutter (frontend), PostgreSQL 16, Redis 7
- Monorepo approach chosen (no monorepo tool — team < 50, only 2 apps)

Constraints from SRS:
- PostgreSQL 16 with partition support, `unaccent` + `pg_trgm` extensions (handled by migrations later)
- Redis 7 serving 3 roles: Pub/Sub, BullMQ job queue, API cache
- Connection pool: min 5, max 20 (NFR-PERF-002)
- Dev environment must match production topology (SRS 3.3)

## Goals / Non-Goals

**Goals:**
- Developers can `docker compose up -d` and have PostgreSQL + Redis running locally
- Monorepo folder structure ready for NestJS scaffold (Task 0.2) and Flutter scaffold (Task 0.3)
- Environment variables documented and templated
- `.gitignore` prevents secrets and build artifacts from being committed

**Non-Goals:**
- Production Docker Compose (`docker-compose.prod.yml`) — deferred to deployment task
- NestJS or Flutter project scaffolding — separate tasks (0.2, 0.3)
- Database schema, migrations, or extensions — handled by Task 2.1
- CI/CD configuration — decision D2 not yet made
- Nginx reverse proxy — production only

## Decisions

### D1: No monorepo tool (Nx/Turborepo)
**Choice**: Plain folder structure, no tooling
**Rationale**: Flutter (Dart) cannot integrate with JS-based monorepo tools. Only 2 apps exist (`api` + `mobile`). Team is small. The overhead of Nx/Turborepo provides no benefit here.
**Alternatives considered**: Nx (too heavy, Flutter incompatible), Turborepo (lighter but still JS-only), Melos (Dart-only, doesn't help NestJS)

### D2: Named Docker volumes over host bind mounts
**Choice**: Docker named volumes for PostgreSQL and Redis data
**Rationale**: Better I/O performance on Windows/macOS (no filesystem translation overhead). Cleaner project directory — no `data/` folder. For local dev, data loss is acceptable (re-run migrations).
**Alternatives considered**: Host bind mount (`./data/postgres`) — easier manual backup but slower on Windows, adds folder to project

### D3: Single docker-compose.yml for local dev only
**Choice**: One compose file targeting local development
**Rationale**: Production compose requires decisions not yet made (D3 hosting, D4 domain). Local dev is the immediate need. Production compose can be added when deployment decisions are finalized.

### D4: PostgreSQL extensions deferred to migrations
**Choice**: Do NOT create Docker init scripts for `unaccent`/`pg_trgm`
**Rationale**: TypeORM migrations (Task 2.1) will handle `CREATE EXTENSION IF NOT EXISTS`. The default `postgres:16` image includes both extensions. Keeping extension management in migrations ensures consistency between environments.

## Risks / Trade-offs

- **[Named volumes harder to inspect]** → Acceptable for dev. Use `docker volume inspect` or `docker cp` if needed. Production will use proper backup strategy.
- **[No health checks in compose]** → For local dev with 2 services, not critical. NestJS will retry connections on startup. Can add later if needed.
- **[`requirements/info.md` contains real credentials in git history]** → `.gitignore` prevents future changes from being committed, but existing history is not cleaned. Recommend `git filter-branch` or BFG Repo-Cleaner separately.
- **[No production compose yet]** → Blocks deployment but not development. Acceptable trade-off for now.

