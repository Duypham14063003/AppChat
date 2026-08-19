## 1. Auth Database Entities & Migrations

- [x] 1.1 Create TypeORM entity: `User` (id, odoo_uid, email, name, avatar_url, department, job_title, is_active, last_seen_at, created_at, updated_at)
- [x] 1.2 Create TypeORM entity: `Role` (id, name, description, created_at)
- [x] 1.3 Create TypeORM entity: `UserRole` (user_id, role_id, assigned_at) with composite PK
- [x] 1.4 Create TypeORM entity: `UserSession` (id, user_id, device_id, device_name, refresh_token_hash, fcm_token, last_used_at, last_ip, expires_at, created_at)
- [x] 1.5 Generate and run migration for all 4 tables with indexes (users.email, users.odoo_uid, user_sessions.user_id, user_sessions.expires_at)
- [x] 1.6 Create seed migration for 3 default roles: admin, manager, employee

## 2. Odoo SSO Login Endpoint

- [x] 2.1 Create `OdooService` in auth module: method `authenticate(email, password)` that calls Odoo `/web/session/authenticate` with 10s timeout and returns uid + user info
- [x] 2.2 Create `AuthService.login()`: call OdooService → create/update user in DB → assign default Employee role on first login → create session → issue JWT tokens
- [x] 2.3 Create `AuthController` with `POST /auth/login` endpoint (LoginDto: email, password, device_id?, device_name?)
- [x] 2.4 Apply rate limiting on login endpoint: 5 attempts / 15 min / IP using @nestjs/throttler with Redis storage
- [x] 2.5 Add audit logging for login success/failure events via winston structured JSON

## 3. JWT Token Management

- [x] 3.1 Create `TokenService`: method `generateAccessToken(user)` → JWT with userId, email, roles (15 min TTL)
- [x] 3.2 Create `TokenService.generateRefreshToken()` → cryptographically random string (30 day TTL)
- [x] 3.3 Create `TokenService.hashRefreshToken()` and `verifyRefreshToken()` using bcrypt
- [x] 3.4 Create `AuthService.refreshTokens()`: validate refresh token → rotate (issue new, invalidate old) → update session
- [x] 3.5 Implement token theft detection: if invalidated refresh token is reused → delete ALL sessions for that user
- [x] 3.6 Create `AuthController` endpoint `POST /auth/refresh` (RefreshDto: refreshToken)

## 4. Auth Guards & RBAC

- [x] 4.1 Create `JwtStrategy` (passport-jwt) that extracts and validates access token from Authorization header
- [x] 4.2 Register `JwtAuthGuard` as global guard with `@Public()` decorator for excluded endpoints
- [x] 4.3 Create `@Roles()` decorator and `RolesGuard` that checks user roles from JWT payload
- [x] 4.4 Create `@CurrentUser()` parameter decorator to extract user from request

## 5. Session Management

- [x] 5.1 Create `SessionService` with CRUD: createSession, findSessionsByUser, deleteSession, deleteAllSessions
- [x] 5.2 Create `AuthController` endpoint `GET /auth/sessions` — list current user's active sessions
- [x] 5.3 Create `AuthController` endpoint `POST /auth/logout` — delete current device session + audit log
- [x] 5.4 Create `AuthController` endpoint `POST /auth/logout-all` — delete all sessions for user + audit log
- [x] 5.5 Create `AuthController` endpoint `DELETE /auth/sessions/:id` — delete specific session (own only)
- [x] 5.6 Create `AuthController` endpoint `PATCH /users/:id/deactivate` — Admin only: set is_active=false, delete all sessions, audit log
- [x] 5.7 Create BullMQ cron job to clean up expired sessions (runs daily)

## 6. Flutter: Login Screen & Secure Storage

- [x] 6.1 Create `AuthRepository` in Flutter: methods for login, refresh, logout, getSessions (calls API via Dio)
- [x] 6.2 Create `SecureTokenStorage` service: store/retrieve/delete access token and refresh token via flutter_secure_storage
- [x] 6.3 Create `LoginScreen` widget: email + password form, Nineteen Tech branding, loading state, error display, form validation
- [x] 6.4 Create `AuthNotifier` (Riverpod) managing auth state: unauthenticated → authenticating → authenticated → error

## 7. Flutter: Dio Interceptor & Auto-login

- [x] 7.1 Create `AuthInterceptor` for Dio: intercept 401 → refresh token → retry request → queue concurrent requests during refresh
- [x] 7.2 Handle refresh failure in interceptor: clear tokens → navigate to login screen
- [x] 7.3 Create `SplashScreen` with auto-login logic: check stored refresh token → attempt silent refresh → navigate to home or login
- [x] 7.4 Update go_router configuration: add login route, splash route, auth redirect guard

## 8. Integration Testing

- [x] 8.1 Write NestJS e2e tests: login success, login failure, login rate limiting
- [x] 8.2 Write NestJS e2e tests: token refresh, token rotation, theft detection
- [x] 8.3 Write NestJS e2e tests: session listing, logout, logout-all, delete session
- [x] 8.4 Write NestJS e2e tests: RBAC guard (admin-only endpoint, employee rejected)
- [x] 8.5 Write NestJS e2e tests: account deactivation, deactivated user login blocked

