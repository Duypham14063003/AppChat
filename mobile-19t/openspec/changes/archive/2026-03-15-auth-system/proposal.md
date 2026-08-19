## Why

The Nineteen Tech Internal App requires a complete authentication and authorization system before any feature (chat, HR, tasks) can be used. Users authenticate via their existing Odoo ERP accounts — the app does not manage passwords. This change implements the full FR-AUTH specification (AUTH-FR-001 through AUTH-FR-012) covering Odoo SSO login, JWT token management with rotation and theft detection, RBAC, multi-device sessions, login rate limiting, account deactivation, audit logging, and the Flutter login flow with auto-refresh and auto-login.

## What Changes

Backend (NestJS):
- Create auth database entities and migrations: `users`, `user_sessions`, `roles`, `user_roles` tables
- Implement Odoo SSO login endpoint (`POST /auth/login`) with rate limiting (5 attempts / 15 min / IP)
- Implement JWT access token (15 min TTL) + refresh token (30 day TTL) with rotation and theft detection
- Implement auth guards (JWT strategy) and RBAC decorator/guard (Admin / Manager / Employee)
- Implement multi-device session management: list sessions, logout current device, logout all devices, delete specific session
- Implement account deactivation (Admin action — kill all sessions, block login)
- Add audit logging for login/logout/role change events
- Add health check for Odoo connectivity

Frontend (Flutter):
- Implement login screen with email/password form, error handling, loading states
- Store JWT tokens securely via `flutter_secure_storage` (Keychain/Keystore per platform)
- Implement Dio interceptor for automatic token refresh on 401 responses
- Implement auto-login on app start (check stored refresh token → refresh → navigate to home)

## Capabilities

### New Capabilities
- `odoo-sso-login`: Odoo SSO authentication endpoint, user provisioning, login rate limiting, and audit logging
- `jwt-token-management`: JWT access/refresh token issuance, refresh with rotation, theft detection, and token revocation
- `rbac-authorization`: Role-based access control with Admin/Manager/Employee roles, guards, and decorators
- `session-management`: Multi-device session tracking, per-device logout, logout-all, session listing, and account deactivation
- `auth-entities`: Database entities and migrations for users, user_sessions, roles, user_roles
- `flutter-auth-flow`: Flutter login screen, secure token storage, Dio auto-refresh interceptor, and auto-login on app start

### Modified Capabilities
<!-- No existing capabilities to modify — first auth implementation -->

## Impact

- **Database**: 4 new tables (users, user_sessions, roles, user_roles) with indexes and foreign keys
- **API endpoints**: 6 new endpoints under `/auth/*` plus session management
- **External dependency**: Odoo ERP API (erp.19t.vn) — login flow depends on Odoo availability
- **Security**: JWT secrets required in env vars, rate limiting via @nestjs/throttler, bcrypt for refresh token hashing
- **Flutter**: New login screen, Dio interceptor modifies all HTTP requests, secure storage integration
- **All subsequent features**: Every API endpoint and WebSocket connection will depend on this auth system

