## Why

The monorepo structure (Task 0.1) provides empty `apps/api/` and `apps/mobile/` directories. Before any feature development can begin, the NestJS backend project needs to be scaffolded with the correct framework version, module structure, configuration validation, and all core dependencies installed. This is Task 0.2 in the project roadmap and blocks all backend feature tasks (auth, chat, HR, etc.).

KICKOFF.md specified NestJS 10.x, but as of March 2026, NestJS 11 is the current stable release (v11.1.16) and v10 only receives security patches. The team decided to use NestJS 11 to avoid an early migration.

## What Changes

- Scaffold NestJS 11 project inside `apps/api/` with TypeScript strict mode
- Create modular folder structure: `src/modules/` with empty module directories for auth, chat, call, hr, task, profile, ai, notification, reminder
- Create `src/common/` directory for shared guards, filters, interceptors, pipes
- Create `src/config/` with environment validation using `@nestjs/config` + Joi (validating all env vars from `.env.example`)
- Install all core dependencies: TypeORM + pg, ioredis, BullMQ, JWT + Passport, WebSocket (ws), class-validator, Helmet, Throttler, Swagger
- Configure TypeScript strict mode, ESLint, and Prettier
- Configure `main.ts` with global pipes, CORS, Helmet, Swagger, API versioning prefix `/api/v1/`
- **BREAKING** (vs KICKOFF.md): NestJS 11 instead of 10.x — all `@nestjs/*` packages use v11 line

## Capabilities

### New Capabilities
- `nestjs-project-structure`: NestJS 11 project scaffold with modular architecture, config validation, global middleware, and all core dependencies
- `api-config-validation`: Environment variable validation at startup using Joi schema, ensuring all required config is present before the app starts

### Modified Capabilities
<!-- No existing capabilities to modify -->

## Impact

- **`apps/api/`**: Transforms from empty placeholder to full NestJS project
- **Dependencies**: ~25 npm packages installed (framework + ORM + cache + queue + auth + validation + docs)
- **Node.js**: Requires Node.js >= 20 (NestJS 11 requirement)
- **Docker Compose**: NestJS app connects to PostgreSQL and Redis from docker-compose.yml
- **Subsequent tasks**: Unblocks all backend feature tasks (1.1 auth, 2.1 DB entities, 2.3 WebSocket gateway, etc.)

