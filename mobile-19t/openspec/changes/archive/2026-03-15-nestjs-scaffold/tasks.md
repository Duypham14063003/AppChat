## 1. Project Scaffold

- [x] 1.1 Run `nest new` inside `apps/api/` with NestJS 11, TypeScript strict mode, npm package manager
- [x] 1.2 Restructure generated project to match KICKOFF folder layout: create `src/modules/`, `src/common/`, `src/config/` directories
- [x] 1.3 Create 9 empty module files in `src/modules/` (auth, chat, call, hr, task, profile, ai, notification, reminder) and register all in AppModule

## 2. Dependencies

- [x] 2.1 Install core dependencies: @nestjs/config, joi, typeorm, @nestjs/typeorm, pg, ioredis, bullmq, @nestjs/bullmq
- [x] 2.2 Install auth dependencies: @nestjs/jwt, @nestjs/passport, passport, passport-jwt, @types/passport-jwt
- [x] 2.3 Install WebSocket dependencies: @nestjs/websockets, @nestjs/platform-ws, ws, @types/ws
- [x] 2.4 Install utility dependencies: class-validator, class-transformer, helmet, @nestjs/throttler, @nestjs/swagger, swagger-ui-express

## 3. Configuration

- [x] 3.1 Create `src/config/configuration.ts` with Joi validation schema for all env vars (DB_*, REDIS_*, PORT, JWT_*)
- [x] 3.2 Create `src/config/config.module.ts` that registers ConfigModule.forRoot with the Joi schema
- [x] 3.3 Import ConfigModule in AppModule as global module

## 4. Global Setup

- [x] 4.1 Configure `main.ts`: global prefix `/api/v1`, ValidationPipe, Helmet, CORS, Swagger at `/api/docs`
- [x] 4.2 Create `src/common/` subdirectories: guards/, filters/, interceptors/, pipes/ with .gitkeep files
- [x] 4.3 Add a health check endpoint at `GET /health` (simple controller returning { status: 'ok' })

## 5. Verification

- [x] 5.1 Verify `npm run lint` passes with no errors
- [x] 5.2 Verify `npm run build` compiles successfully
- [x] 5.3 Verify `npm run start:dev` starts and responds at `http://localhost:3000/api/v1/health`
