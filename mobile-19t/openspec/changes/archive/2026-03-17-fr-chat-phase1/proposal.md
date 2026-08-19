## Why

The Nineteen Tech Internal App has authentication completed but no messaging capability yet. Chat is the core feature — the "killer app" that drives daily usage. This change implements FR-CHAT Phase 1: the foundational real-time messaging infrastructure and core 1-on-1 chat experience. It covers KICKOFF tasks 2.x (infrastructure), 3.x (core messaging), and 4.x (push notifications) — everything needed for two employees to exchange text messages in real-time with offline support, delivery guarantees, and push notifications.

Phase 1 scope covers 10 P0 MUST requirements: CHAT-FR-001 (DM text), CHAT-FR-002 (Group text fan-out), CHAT-FR-003 (Create Direct conversation), CHAT-FR-018 (Local search), CHAT-FR-021 (Message status), CHAT-FR-024 (Unread badge), CHAT-FR-029 (Offline queue), CHAT-FR-030 (Reconnect sync), CHAT-FR-031 (Infinite scroll), CHAT-FR-035 (Rate limiting). Note: CHAT-FR-006 (Send image) is deferred to Phase 2 — the message schema supports image type from day one but upload infrastructure and UI are not in scope.

## What Changes

Backend (NestJS):
- Create chat database entities and migration: `conversations`, `conversation_members`, `messages` (partitioned by quarter), `message_reactions` tables with all indexes
- Implement WebSocket Gateway with JWT handshake authentication (AUTH-FR-010)
- Implement Redis Pub/Sub service for real-time message fan-out across server instances
- Implement send message flow: WS event → validate → INSERT PostgreSQL → Redis PUBLISH → ACK sender
- Implement conversation CRUD: create direct conversation, list conversations (sorted by last_message_at), get conversation details
- Implement cursor-based message pagination (timestamp cursor, 30 per page)
- Implement message status tracking: pending → sent → delivered → read
- Implement BullMQ job for offline push notifications via Firebase FCM
- Implement FCM token management (store/update per device session)
- Implement message rate limiting: 30 messages/min/user via WebSocket gateway
- Implement reconnect sync: client sends last_synced_at, server returns missed messages

Frontend (Flutter):
- Create WebSocket manager: connect with JWT, auto-reconnect with exponential backoff, heartbeat
- Create Drift local database schema for conversations and messages (7-day cache)
- Create chat list screen: conversation list with last message preview, unread badge, sorted by recency
- Create chat screen: message bubbles with optimistic UI, scroll-to-bottom, infinite scroll up for history
- Create offline message queue: pending messages in Drift, auto-send on reconnect, retry with backoff
- Create reconnect sync: send last_synced_at on reconnect, merge missed messages
- Implement local search via Drift FTS (7-day window, < 300ms)
- Implement unread count tracking and app badge
- Setup Firebase Messaging for push notifications, tap-to-navigate

## Capabilities

### New Capabilities
- `chat-entities`: Database entities and migrations for conversations, conversation_members, messages (partitioned), message_reactions
- `websocket-gateway`: NestJS WebSocket Gateway with JWT auth, connection management, heartbeat, rate limiting
- `redis-pubsub`: Redis Pub/Sub service for real-time message fan-out and presence tracking
- `chat-messaging`: Core send/receive message flow — WS → DB → Redis → deliver, with optimistic UI on client
- `conversation-management`: Conversation CRUD (create direct, list, get details), cursor-based message pagination
- `message-status`: Message lifecycle tracking (pending → sent → delivered → read) with read receipts
- `offline-sync`: Offline message queue, reconnect missed-message sync, retry logic
- `flutter-chat-ui`: Chat list screen, chat screen with bubbles, infinite scroll, local search, unread badges
- `push-notification`: Firebase FCM integration — token management, offline push delivery, tap-to-navigate

### Modified Capabilities
- `flutter-project-structure`: Add chat feature directory structure under `lib/features/chat/`
- `nestjs-project-structure`: Populate chat module with gateway, controllers, services, entities

## Impact

- **Database**: 4 new tables (conversations, conversation_members, messages, message_reactions) with partitioning and 6+ indexes
- **API endpoints**: 7 new REST endpoints under `/conversations/*` plus `/search/messages`
- **WebSocket events**: 5 client→server events, 6 server→client events
- **External dependencies**: Redis (Pub/Sub — already running), Firebase FCM (new — requires project setup)
- **Infrastructure**: Messages table partitioned by quarter — requires cron/manual partition creation for future quarters
- **Flutter**: New chat feature module, Drift schema, WebSocket manager in core/network, FCM setup
- **Performance targets**: Message send < 100ms (WS), end-to-end delivery < 500ms, local search < 300ms, timeline query < 5ms

