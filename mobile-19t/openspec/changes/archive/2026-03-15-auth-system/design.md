## Context

The Nineteen Tech Internal App needs authentication before any feature works. Users have existing Odoo ERP accounts at erp.19t.vn — the app delegates password verification to Odoo and manages its own JWT sessions. This is a cross-cutting change: it touches database schema, NestJS auth module, external Odoo API, and Flutter client.

Prerequisite: NestJS scaffold (Task 0.2) with ConfigModule, TypeORM, and core dependencies installed. Docker Compose running PostgreSQL 16 + Redis 7.

Key SRS references: FR-AUTH (12 requirements), NFR-SEC-002 (JWT security), NFR-SEC-005 (RBAC), NFR-SEC-006 (audit logging), API spec section 7.1.2, Odoo integration section 7.2, database schema (users, user_sessions).

## Goals / Non-Goals

**Goals:**
- Complete FR-AUTH coverage: all 12 requirements (AUTH-FR-001 through AUTH-FR-012)
- End-to-end auth flow: Odoo SSO → JWT → secure storage → auto-refresh → auto-login
- RBAC system usable by all future feature modules
- Multi-device session management with theft detection
- Login rate limiting and audit logging

**Non-Goals:**
- WebSocket authentication (AUTH-FR-010) — covered by Task 2.3 (WS Gateway)
- E2E encryption — explicitly excluded per SRS (TLS only)
- OAuth2/OpenID Connect — Odoo uses session-based auth, not OAuth
- User registration — all users come from Odoo, no self-registration
- Password reset — delegated to Odoo admin

## Decisions

### D1: Odoo auth flow — proxy, not federation
**Choice**: NestJS receives email+password, calls Odoo `/web/session/authenticate`, then issues its own JWT. App never stores passwords.
**Rationale**: Odoo doesn't support OAuth2/OIDC. Session-based auth is the only option. Our JWT layer decouples the app from Odoo session management.
**Alternatives**: Store Odoo session_id directly — rejected, Odoo sessions expire unpredictably and can't be refreshed without password.

### D2: Refresh token storage — bcrypt hash in user_sessions table
**Choice**: Store bcrypt hash of refresh token in `user_sessions.refresh_token_hash`. One row per device.
**Rationale**: If DB is compromised, attacker can't use hashed tokens. Per-device rows enable multi-device management and selective logout.
**Alternatives**: Store in Redis — faster but loses data on restart, harder to query for session listing. Store plaintext — security risk.

### D3: Token rotation with theft detection
**Choice**: On refresh, issue new refresh token, invalidate old one. If invalidated token is reused → logout ALL sessions for that user.
**Rationale**: Per NFR-SEC-002. Detects token theft: if attacker uses stolen token after legitimate user already refreshed, the reuse triggers a full logout, protecting the user.
**Flow**: Refresh token A used → issue B, mark A as used → if A reused → delete all sessions for user.

### D4: RBAC via roles table + decorator + guard
**Choice**: Separate `roles` and `user_roles` tables. Custom `@Roles('admin', 'manager')` decorator + `RolesGuard` that reads user roles from JWT payload.
**Rationale**: Flexible — roles can be assigned/revoked without reissuing JWT (guard checks DB on sensitive operations). JWT contains roles for fast path.
**Alternatives**: Roles as enum column on users table — simpler but less flexible for future role additions.

### D5: Rate limiting — @nestjs/throttler on login endpoint
**Choice**: Use `@nestjs/throttler` with custom storage (Redis) to limit login to 5 attempts per 15 minutes per IP. Block for 30 minutes after exceeding.
**Rationale**: Per AUTH-FR-012. Redis-backed throttler survives server restarts. IP-based is sufficient for internal app.
**Alternatives**: Custom middleware — unnecessary when throttler package exists.

### D6: Audit logging — structured JSON via winston
**Choice**: Log auth events (login success/fail, logout, role change, account deactivation) as structured JSON via winston logger. Stored in application logs, 90-day retention.
**Rationale**: Per NFR-SEC-006. Structured JSON enables log aggregation later. No separate audit table needed for MVP.
**Alternatives**: Audit table in PostgreSQL — more queryable but adds DB complexity. Can add later if needed.

### D7: Flutter login — simple form, no biometrics
**Choice**: Email + password form with loading state and error display. Tokens stored via `flutter_secure_storage`. No biometric auth for MVP.
**Rationale**: Internal app, biometrics is nice-to-have. Secure storage uses platform Keychain/Keystore automatically.

### D8: Dio interceptor — queue requests during refresh
**Choice**: Dio interceptor catches 401, queues pending requests, refreshes token, retries all queued requests. If refresh fails → navigate to login.
**Rationale**: Per AUTH-FR-002. Prevents multiple simultaneous refresh calls. Standard pattern for mobile apps.

## Risks / Trade-offs

- **[Odoo down → login fails]** → Existing sessions continue working (JWT is self-contained). Only new logins are blocked. Graceful error message per AUTH-FR-001.
- **[Odoo auth API may change]** → Wrap Odoo calls in a service with interface. Easy to swap implementation.
- **[bcrypt hashing adds latency to refresh]** → ~100ms per hash. Acceptable for auth operations. Not on hot path.
- **[JWT payload contains roles — stale if role changes]** → Access token TTL is 15 min, so staleness is bounded. For immediate role revocation, RolesGuard can check DB on sensitive endpoints.
- **[Rate limiting by IP — shared office IP]** → All employees share office IP. 5 attempts per 15 min might be too aggressive. Consider per-email+IP combination instead. Flag as open question.

## Open Questions

- Rate limiting key: IP only, or email+IP combination? (affects shared office scenario)

