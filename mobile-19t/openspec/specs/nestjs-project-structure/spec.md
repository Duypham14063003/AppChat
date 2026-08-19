## Requirements

### Requirement: NestJS project runs and connects to infrastructure
The NestJS application SHALL start successfully on the configured PORT and establish connections to PostgreSQL and Redis as defined in environment variables.

#### Scenario: Successful startup with valid config
- **WHEN** developer runs `npm run start:dev` inside `apps/api/` with valid `.env` values
- **THEN** the application starts on the configured PORT and logs successful connections to PostgreSQL and Redis

#### Scenario: Health check endpoint responds
- **WHEN** a GET request is sent to `/api/v1/health`
- **THEN** the server responds with HTTP 200 and a JSON body indicating service status

### Requirement: Modular folder structure matches architecture
The project SHALL contain a `src/modules/` directory with subdirectories for each domain module: auth, chat, call, hr, task, profile, ai, notification, reminder. Each module SHALL have a NestJS module file registered in the root AppModule.

#### Scenario: All 9 modules exist and are registered
- **WHEN** developer inspects `src/modules/`
- **THEN** 9 directories exist (auth, chat, call, hr, task, profile, ai, notification, reminder), each containing a `*.module.ts` file, and all are imported in `app.module.ts`

### Requirement: Common directory for shared infrastructure
The project SHALL contain a `src/common/` directory for shared guards, filters, interceptors, and pipes used across modules.

#### Scenario: Common directory structure exists
- **WHEN** developer inspects `src/common/`
- **THEN** subdirectories for guards, filters, interceptors, and pipes exist

### Requirement: Global middleware is configured
The application SHALL configure Helmet for security headers, CORS for cross-origin requests, a global ValidationPipe for DTO validation, and Swagger UI at `/api/docs`.

#### Scenario: Swagger UI is accessible
- **WHEN** developer navigates to `http://localhost:3000/api/docs` in a browser
- **THEN** Swagger UI loads showing the API documentation

#### Scenario: CORS allows Flutter app origins
- **WHEN** a request is sent with an Origin header
- **THEN** the server responds with appropriate CORS headers allowing the configured origins

### Requirement: API versioning prefix is applied
All API routes SHALL be prefixed with `/api/v1/` as the global route prefix.

#### Scenario: Routes use versioned prefix
- **WHEN** developer creates a controller with `@Controller('health')`
- **THEN** the endpoint is accessible at `/api/v1/health`
