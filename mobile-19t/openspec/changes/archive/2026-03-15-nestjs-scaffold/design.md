## Context

Greenfield NestJS backend project for Nineteen Tech Internal App. The monorepo root with Docker Compose (PostgreSQL 16 + Redis 7) is being set up in Task 0.1. This task scaffolds the NestJS application inside `apps/api/`.

Key constraints from SRS:
- Modular Monolith architecture (SRS 3.1) — one NestJS app with domain modules
- 9 feature modules: auth, chat, call, hr, task, profile, ai, notification, reminder
- TypeORM for PostgreSQL (partition support, raw SQL capability)
- ws (not Socket.io) for WebSocket — lighter, Flutter uses `web_socket_channel`
- API versioning: `/api/v1/` prefix (NFR-MAINT-003)
- TypeScript strict mode (NFR-MAINT-001)
- ESLint for linting (NFR-MAINT-001)

## Goals / Non-Goals

**Goals:**
- Runnable NestJS 11 project that starts and connects to PostgreSQL + Redis
- Modular folder structure matching KICKOFF.md section 5
- Config validation that fails fast on missing env vars
- Global middleware: CORS, Helmet, validation pipe, Swagger
- All core dependencies installed and configured

**Non-Goals:**
- Implementing any feature module logic (auth, chat, etc.) — those are separate tasks
- Database schema or migrations — Task 2.1
- WebSocket gateway implementation — Task 2.3
- BullMQ queue processors — individual feature tasks
- Production Dockerfile — deferred

## Decisions

### D1: NestJS 11 instead of 10
**Choice**: NestJS 11.1.x
**Rationale**: v10 only receives security patches since late 2025. All `@nestjs/*` ecosystem packages have v11 releases. Starting with v10 means an immediate migration burden.
**Alternatives**: NestJS 10.x (KICKOFF original spec) — rejected due to EOL proximity.

### D2: Scaffold via @nestjs/cli then restructure
**Choice**: Use `nest new` to generate base project, then restructure to match KICKOFF folder layout
**Rationale**: CLI generates correct tsconfig, jest config, eslint config. Restructuring is faster than manual setup.
**Alternatives**: Manual setup from scratch — more error-prone, no benefit.

### D3: Config validation with Joi
**Choice**: `@nestjs/config` + Joi schema validation
**Rationale**: Fails at startup if required env vars are missing. Joi is the recommended approach in NestJS docs. Type-safe config access via ConfigService.
**Alternatives**: class-validator for config — works but Joi is more natural for env validation.

### D4: Empty module directories with barrel files
**Choice**: Create all 9 module directories with minimal `*.module.ts` files (empty modules registered in AppModule)
**Rationale**: Establishes the architecture pattern. Feature tasks can immediately start adding services/controllers without creating module boilerplate.
**Alternatives**: Only create directories without module files — loses the pattern demonstration.

### D5: Swagger enabled in all environments
**Choice**: Enable Swagger UI at `/api/docs` in all environments
**Rationale**: Internal app with < 50 users. API documentation is always useful. No security concern for internal tool.
**Alternatives**: Swagger only in dev — unnecessary restriction for internal app.

## Risks / Trade-offs

- **[NestJS 11 vs KICKOFF spec]** → Document the version change in KICKOFF.md. No functional impact — API is backward compatible.
- **[Many dependencies upfront]** → All dependencies are needed per SRS. Installing now avoids repeated `npm install` during feature tasks. Pin versions with `package-lock.json`.
- **[Empty modules may confuse]** → Each module has a comment explaining its purpose and which KICKOFF task fills it in.
- **[TypeORM 0.3.x no 1.0 release]** → Stable enough for production. Active maintenance. Raw SQL escape hatch available for partition queries.

