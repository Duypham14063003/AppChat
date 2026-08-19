# 5. Non-Functional Requirements

## 5.1 Performance Requirements

### NFR-PERF-001 — API Response Time

| Endpoint type                      | Target p95 | Max acceptable |
| ---------------------------------- | ---------- | -------------- |
| Auth (login)                       | < 1000ms   | 3000ms         |
| REST API (CRUD)                    | < 200ms    | 500ms          |
| Chat message send (WS)             | < 100ms    | 300ms          |
| Chat message delivery (end-to-end) | < 500ms    | 1000ms         |
| Search (local FTS)                 | < 300ms    | 500ms          |
| Search (server FTS)                | < 100ms    | 300ms          |
| File upload (10MB)                 | < 5s       | 10s            |

### NFR-PERF-002 — Database Performance

- Messages table: query timeline (30 rows) < 5ms với index `(conv_id, created_at DESC)`
- Full-text search trên 30M messages: < 100ms với GIN index
- Partition strategy: by quarter (3 tháng/partition)
- Connection pool: min 5, max 20 connections

### NFR-PERF-003 — Concurrent Users

- The system shall hỗ trợ 50 concurrent WebSocket connections trên single server instance
- The system shall handle 100 messages/second throughput
- Redis Pub/Sub fan-out: < 10ms per message per recipient

### NFR-PERF-004 — Flutter App Performance

- App cold start: < 3 giây (hiện splash → main screen)
- Chat screen load: < 1 giây (từ Drift local cache)
- Scroll performance: 60fps liên tục, không jank
- Memory usage: < 200MB trên mobile
- Local cache (Drift): giữ 7 ngày, evict conversations không xem > 30 ngày

### NFR-PERF-005 — Call Quality

- Audio latency: < 200ms (Agora SFU handles)
- Video resolution: adaptive 360p-720p based on network
- Call setup time: < 3 giây từ bấm gọi đến ring

## 5.2 Security Requirements

### NFR-SEC-001 — Transport Security

- Tất cả communication qua HTTPS/TLS 1.3 (REST) và WSS (WebSocket)
- Certificate pinning cho mobile apps (optional, P2)
- HSTS header enabled

### NFR-SEC-002 — Authentication Security

- JWT access token TTL: 15 phút
- JWT refresh token TTL: 30 ngày
- Refresh token rotation: mỗi lần dùng → issue mới, invalidate cũ
- Token theft detection: reuse token cũ → logout all sessions
- Password: không lưu trong app, delegate cho Odoo
- Login rate limit: 5 attempts / 15 phút / IP

### NFR-SEC-003 — Data Encryption

- Transport: TLS 1.3 (in-transit)
- Database: encrypted at rest (PostgreSQL TDE hoặc disk encryption)
- Token storage: platform-specific secure storage (Keychain/Keystore)
- Không implement E2E encryption (overkill cho internal app)

### NFR-SEC-004 — API Security

- Helmet middleware (HTTP security headers)
- CORS: chỉ allow origins từ app domains
- Rate limiting: @nestjs/throttler
- Input validation: class-validator trên tất cả DTOs
- SQL injection prevention: parameterized queries (TypeORM)
- XSS prevention: sanitize user input trước khi lưu

### NFR-SEC-005 — Authorization

- RBAC: Admin / Manager / Employee
- API endpoint guards: mỗi endpoint check role
- Conversation access: user chỉ query messages của conversations mình là member
- HR data: Employee chỉ xem data cá nhân, Manager xem team, Admin xem tất cả

### NFR-SEC-006 — Audit Logging

- Log tất cả: login/logout, role changes, data access nhạy cảm (HR)
- Log format: structured JSON (winston)
- Retention: 90 ngày

## 5.3 Usability Requirements

### NFR-USE-001 — Cross-platform Consistency

- UI/UX nhất quán trên tất cả platforms (iOS, Android, Windows, macOS, Web)
- Tuân thủ platform conventions khi cần (back gesture iOS, system tray Windows)
- Brand identity: dark theme, gold accent (#C9A84C), font Roboto

### NFR-USE-002 — Responsive Layout

- Mobile: single column, bottom navigation
- Tablet: optional split view (conversation list + chat)
- Desktop: 3-column layout (sidebar + list + content + optional right panel)
- Web: responsive, min width 360px

### NFR-USE-003 — Accessibility

- Font size adjustable (small/medium/large)
- Contrast ratio: WCAG AA minimum (4.5:1 cho text)
- Screen reader support cho core flows (login, chat, checkin)

### NFR-USE-004 — Localization

- Primary: Tiếng Việt
- Secondary: English
- Tất cả strings externalized (intl package)
- Date/time format theo locale

### NFR-USE-005 — Offline UX

- App mở được khi offline (hiện cached data)
- Rõ ràng indicator khi offline (banner "Không có kết nối")
- Pending messages hiện trạng thái rõ ràng (⏳ icon)

## 5.4 Reliability Requirements

### NFR-REL-001 — Uptime

- Target: 99.5% uptime (cho phép ~3.6 giờ downtime/tháng)
- Monitoring: health check endpoint `/health` ping mỗi 1 phút
- Alert: Telegram bot hoặc email khi server down

### NFR-REL-002 — Data Durability

- Message delivery guarantee: at-least-once (BullMQ retry)
- Duplicate prevention: UUID idempotency key
- PostgreSQL: WAL archiving enabled
- Backup: pg_dump tự động mỗi đêm, giữ 30 ngày
- RTO: < 2 giờ, RPO: < 24 giờ

### NFR-REL-003 — Graceful Degradation

- Odoo down → auth mới fail, nhưng existing sessions vẫn hoạt động, chat vẫn chạy
- Agora down → call không hoạt động, nhưng chat và HR vẫn chạy
- Bunny.net down → upload fail, nhưng text chat vẫn chạy
- Redis down → real-time bị ảnh hưởng, REST API vẫn hoạt động (không cache)

## 5.5 Scalability Requirements

### NFR-SCALE-001 — Horizontal Scaling Path

- NestJS: stateless design, scale bằng thêm instances + load balancer
- WebSocket: sticky sessions hoặc Redis adapter cho multi-instance
- PostgreSQL: partition by time, read replicas khi cần
- Current design: single server cho < 50 users
- Scale path: ready cho 200+ users với minimal changes

## 5.6 Maintainability Requirements

### NFR-MAINT-001 — Code Quality

- TypeScript strict mode (backend)
- Dart analysis options strict (frontend)
- Linting: ESLint (NestJS), flutter_lints (Flutter)
- Code review required trước khi merge

### NFR-MAINT-002 — Database Migrations

- TypeORM migrations cho tất cả schema changes
- Không bao giờ sửa DB tay trên production
- Migration rollback support

### NFR-MAINT-003 — API Versioning

- URL prefix: `/api/v1/`
- Breaking changes → `/api/v2/` chạy song song 2 tuần
- Deprecation notice trước 1 sprint
