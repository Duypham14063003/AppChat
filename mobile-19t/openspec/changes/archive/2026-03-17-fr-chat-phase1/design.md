## Context

The Nineteen Tech Internal App has a working auth system (Odoo SSO, JWT, RBAC, sessions) and scaffolded NestJS + Flutter projects. The chat module is the next major feature — it's the most complex module in the entire app due to real-time requirements, data volume (millions of messages over time), and offline-first UX.

Prerequisites completed: NestJS scaffold with ConfigModule, TypeORM, BullMQ, JWT guards. Flutter scaffold with Riverpod, go_router, Drift, Dio, web_socket_channel. Docker Compose running PostgreSQL 16 + Redis 7. Auth system fully implemented.

Key SRS references: FR-CHAT (35 requirements, 11 P0 for Phase 1), NFR-PERF-001/002/003 (performance targets), NFR-SEC-005 (conversation access control), API spec 7.1.3/7.1.4 (REST + WS contracts), database schema 6.1.2 (conversations, messages, conversation_members, message_reactions), data flow 6.3.1 (chat message flow).

## Goals / Non-Goals

**Goals:**
- Complete Phase 1 P0 coverage: CHAT-FR-001, 002, 003, 018, 021, 024, 029, 030, 031, 035
- End-to-end message flow: Flutter → WebSocket → PostgreSQL → Redis Pub/Sub → recipient Flutter
- Messages table partitioned by quarter from day one (future-proof for millions of messages)
- Offline-first: queue messages locally, sync on reconnect, never lose a message
- Push notifications for offline users via Firebase FCM
- Performance: message send < 100ms, delivery < 500ms, timeline query < 5ms

**Non-Goals:**
- Group chat creation/management UI (CHAT-FR-004/005) — Phase 2, but DB schema supports groups from day one
- Media messages UI: image/file/voice/video sending UI (CHAT-FR-006-009) — Phase 2, but message types defined in schema
- Message interactions: reply, forward, reaction, pin, delete, edit (CHAT-FR-010-015) — Phase 2
- Typing indicator, online/offline status (CHAT-FR-022/023) — Phase 2
- Server-side full-text search (CHAT-FR-019) — Phase 2, but search_vector column + GIN index created now
- Saved messages, folders, bot framework, link preview, mentions (Phase 2-4)
- E2E encryption — explicitly excluded per SRS (TLS only for internal app)

## Decisions

### D1: WebSocket transport — raw `ws` via @nestjs/platform-ws
**Choice**: Use `@nestjs/platform-ws` (already installed) with raw WebSocket protocol. No Socket.io.
**Rationale**: Per KICKOFF decision — ws is lighter, Flutter uses `web_socket_channel` which speaks raw WS natively. Socket.io adds protocol overhead and requires `socket_io_client` on Flutter side.
**Message format**: JSON over WebSocket. Each message has `{ event: string, data: object, id?: string }` envelope.

### D2: WebSocket authentication — JWT in first message after connect
**Choice**: Client connects to `ws://host/ws`, then sends `{ event: "auth", data: { token: "<jwt>" } }` as first message. Server validates JWT, associates connection with userId. If no auth within 5 seconds → disconnect.
**Rationale**: Raw WebSocket doesn't support custom headers in browser. Query param token is visible in logs. First-message auth is the standard pattern for raw WS.
**Alternative rejected**: Token in URL query param — security risk (logged in server access logs, browser history).

### D3: Messages table — partitioned by quarter, raw SQL migration
**Choice**: `CREATE TABLE messages (...) PARTITION BY RANGE (created_at)` with quarterly partitions. Composite PK `(id, created_at)`. Raw SQL in TypeORM migration (TypeORM doesn't support PARTITION natively).
**Rationale**: Per SRS and KICKOFF decisions. Quarterly partitions give clear hot/cold separation. PostgreSQL automatically prunes partitions on queries with created_at filter. Pre-create Q1 2026 + Q2 2026 partitions, add cron reminder for future quarters.
**Indexes**: `(conv_id, created_at DESC) WHERE deleted_at IS NULL` for timeline, `GIN(search_vector)` for FTS, `(reply_to_id) WHERE reply_to_id IS NOT NULL` for reply lookup.

### D4: Redis Pub/Sub — dedicated ioredis client, channel per conversation
**Choice**: Create a separate ioredis client for Pub/Sub (cannot reuse BullMQ connection — Redis Pub/Sub requires dedicated connection in subscribe mode). Channel pattern: `chat:conv:{conv_id}`.
**Rationale**: Per SRS architecture. Fan-out via Redis enables horizontal scaling later (multiple NestJS instances). Channel-per-conversation means each server only subscribes to conversations with active connections.
**Implementation**: `RedisPubSubService` with `publish(channel, message)` and `subscribe(channel, callback)`. Lazy subscribe — only when a user with active WS connection is in that conversation.

### D5: Message delivery guarantee — at-least-once with UUID idempotency
**Choice**: Client generates UUID for each message (idempotency key). Server uses `INSERT ... ON CONFLICT (id, created_at) DO NOTHING`. BullMQ for offline delivery (FCM push). Client retries on no-ACK with same UUID.
**Rationale**: Per NFR-REL-002. UUID prevents duplicates on retry. BullMQ provides persistent job queue — survives server restart. At-least-once is sufficient; client deduplicates by message ID.

### D6: Cursor-based pagination — timestamp cursor
**Choice**: `GET /conversations/:id/messages?cursor=<ISO-timestamp>&limit=30&dir=before`. Query: `WHERE conv_id = $1 AND created_at < $cursor ORDER BY created_at DESC LIMIT 30`.
**Rationale**: Per KICKOFF decision — OFFSET is anti-pattern for chat. Timestamp cursor is O(1) with `(conv_id, created_at DESC)` index. Returns `{ messages, nextCursor, hasMore }`.

### D7: Optimistic UI — client-generated UUID, pending status
**Choice**: Flutter creates message with UUID, displays bubble immediately (status=pending). On WS ACK → status=sent. On delivery confirmation → status=delivered. On read receipt → status=read.
**Rationale**: Per CHAT-FR-001 flow. Instant feedback is critical for chat UX. If send fails, bubble shows retry button.

### D8: Drift local cache — 7-day window, conversation-scoped eviction
**Choice**: Drift (SQLite) stores messages and conversations locally. Keep 7 days of messages. Evict conversations not viewed in 30 days. FTS5 virtual table for local search.
**Rationale**: Per NFR-PERF-004. Local cache enables instant chat screen load (< 1s). FTS5 provides < 300ms local search per CHAT-FR-018. Eviction prevents unbounded storage growth on mobile.

### D9: Push notifications — Firebase FCM via BullMQ job
**Choice**: When recipient is offline (no active WS connection), enqueue BullMQ job → send FCM push via Firebase Admin SDK. FCM token stored in `user_sessions.fcm_token` (already exists from auth migration).
**Rationale**: Per CHAT-FR-001 acceptance criteria. BullMQ provides retry on FCM failure. Token already stored per-device in user_sessions table.
**Stub strategy**: If Firebase credentials not configured, log warning and skip push. Chat still works without push — just no offline notifications.

### D10: Rate limiting — WS gateway level, sliding window in Redis
**Choice**: 30 messages/min/user, 10 file uploads/min/user. Implemented as sliding window counter in Redis (`INCR` + `EXPIRE`). Checked in WS gateway before processing message.
**Rationale**: Per CHAT-FR-035. Redis-based counter survives reconnects. WS-level check prevents DB writes for spam.

### D11: Conversation access control — membership check on every operation
**Choice**: Every message send, message read, and conversation query checks `conversation_members` table. User must be a member to interact. Implemented as a reusable `ConversationGuard` or service method.
**Rationale**: Per NFR-SEC-005. Internal app but still need to prevent users from reading conversations they're not part of.

## Risks / Trade-offs

- **[Firebase not configured]** → Push notifications silently disabled. Chat works without push. Log warning on startup if FIREBASE_PROJECT_ID is empty.
- **[Partition management]** → Must create new quarterly partitions before each quarter starts. If forgotten, INSERTs fail. Mitigation: create 2 quarters ahead + add BullMQ cron job to auto-create next partition.
- **[Redis single point of failure]** → If Redis goes down, real-time delivery stops but REST API still works. Messages still saved to DB. Reconnect sync catches up when Redis recovers.
- **[WS connection limit]** → Single NestJS instance handles 50 concurrent WS connections (per NFR-PERF-003). Sufficient for < 50 employees. Horizontal scaling via Redis Pub/Sub is ready but not needed yet.
- **[Drift storage on desktop]** → sqlite3_flutter_libs works on mobile + desktop. Web uses sql.js (WASM). Need to verify Drift FTS5 works on all platforms.
- **[Message ordering]** → Using server-side `created_at` as ordering key. Clock skew between client and server could cause visual reordering. Mitigation: server always sets `created_at` on INSERT, client timestamp is informational only.

## Open Questions

- None — all decisions align with SRS and KICKOFF. Phase 2 features are explicitly deferred.

