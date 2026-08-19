## 1. Chat Database Entities & Migrations

- [x] 1.1 Create TypeORM entity: `Conversation` (id, type, name, avatar_url, created_by, last_message_at, created_at) with relation to User (created_by)
- [x] 1.2 Create TypeORM entity: `ConversationMember` (conv_id, user_id, role, last_read_message_id, last_read_at, is_muted, joined_at) with composite PK and relations to Conversation and User
- [x] 1.3 Create TypeORM entity: `Message` (id, conv_id, sender_id, type, content, reply_to_id, forwarded_from_id, forwarded_from_sender, metadata, search_vector, created_at, edited_at, deleted_at) with relations to Conversation and User
- [x] 1.4 Create TypeORM entity: `MessageReaction` (message_id, user_id, emoji, created_at) with composite PK
- [x] 1.5 Create raw SQL migration: enable `unaccent` and `pg_trgm` extensions
- [x] 1.6 Create raw SQL migration: `conversations` table with indexes
- [x] 1.7 Create raw SQL migration: `conversation_members` table with composite PK, FKs, indexes on (user_id) and (conv_id)
- [x] 1.8 Create raw SQL migration: `messages` table with `PARTITION BY RANGE (created_at)`, composite PK (id, created_at), FKs, generated `search_vector` column
- [x] 1.9 Create raw SQL migration: messages partitions for Q1 2026 (Jan-Mar) and Q2 2026 (Apr-Jun)
- [x] 1.10 Create raw SQL migration: messages indexes — `(conv_id, created_at DESC) WHERE deleted_at IS NULL`, `GIN(search_vector)`, `(reply_to_id) WHERE reply_to_id IS NOT NULL`
- [x] 1.11 Create raw SQL migration: `message_reactions` table with composite PK
- [x] 1.12 Register all 4 entities in ChatModule via `TypeOrmModule.forFeature([Conversation, ConversationMember, Message, MessageReaction])`
- [x] 1.13 Wire ChatModule imports: `AuthModule` (for TokenService, SessionService) and `NotificationModule` (for FirebaseService). Add `imports: [AuthModule]` to ChatModule

## 2. WebSocket Gateway & Authentication

- [x] 2.0 Configure `WsAdapter` in `main.ts`: `import { WsAdapter } from '@nestjs/platform-ws'; app.useWebSocketAdapter(new WsAdapter(app));` — required for @nestjs/platform-ws to work
- [x] 2.1 Create `ChatGateway` class with `@WebSocketGateway({ path: '/ws' })` using @nestjs/platform-ws
- [x] 2.2 Implement connection handling: `handleConnection()` — start 5-second auth timeout, store raw socket reference
- [x] 2.3 Implement auth message handler: validate JWT via TokenService (imported from AuthModule), extract userId from payload.sub, associate connection with user in ConnectionManager. Note: `@CurrentUser()` decorator is HTTP-only — WS handlers get userId from ConnectionManager
- [x] 2.4 Create `ConnectionManager` service: in-memory Map<userId, Set<WebSocket>>, methods: addConnection, removeConnection, getConnections, isOnline
- [x] 2.5 Implement `handleDisconnect()` — remove connection from ConnectionManager, trigger Redis unsubscribe if last connection for conversation
- [x] 2.6 Implement WebSocket heartbeat: ping every 30s, close connection if no pong within 10s
- [x] 2.7 Implement JSON message envelope parsing: `{ event, data, id? }` format with validation
- [x] 2.8 Implement rate limiting at gateway level: Redis sliding window counter (INCR + EXPIRE), 30 msg/min/user, reject with error event if exceeded

## 3. Redis Pub/Sub Service

- [x] 3.1 Create `RedisPubSubService` with dedicated ioredis publisher and subscriber clients (separate from BullMQ)
- [x] 3.2 Implement `publish(channel, message)` method — serialize to JSON, publish to `chat:conv:{conv_id}`
- [x] 3.3 Implement `subscribe(channel, callback)` and `unsubscribe(channel)` methods with reference counting
- [x] 3.4 Implement subscription management: on user auth → subscribe to all user's conversation channels; on last disconnect → unsubscribe
- [x] 3.5 Implement message handler: on Redis message received → parse JSON → fan-out to local WebSocket connections of conversation members
- [x] 3.6 Implement Redis reconnection with exponential backoff and re-subscribe on reconnect
- [x] 3.7 Implement `onModuleDestroy()` — gracefully disconnect both ioredis clients

## 4. Core Messaging (Send/Receive)

- [x] 4.1 Create `ChatService` with method `sendMessage(senderId, dto)`: validate membership → INSERT message → update conversation.last_message_at → publish to Redis → return message
- [x] 4.2 Create `SendMessageDto` with class-validator: id (UUID), conv_id (UUID), type (enum), content (string, optional), reply_to_id (UUID, optional), metadata (object, optional)
- [x] 4.3 Wire `send_message` WS event in ChatGateway → ChatService.sendMessage() → ACK back with message_ack event
- [x] 4.4 Implement idempotency: `INSERT ... ON CONFLICT (id, created_at) DO NOTHING` — return existing message if duplicate
- [x] 4.5 Implement fan-out logic: on Redis message received, send `new_message` event to all local WS connections of conversation members (exclude sender's originating connection)
- [x] 4.6 Create `NotificationJobService`: when recipient is offline (not in ConnectionManager), enqueue BullMQ job `chat:push-notification` with message data and recipient userId

## 5. Conversation Management (REST API)

- [x] 5.1 Create `ConversationController` with `@Controller('conversations')`
- [x] 5.2 Implement `POST /conversations` — create DIRECT conversation: check existing, create conversation + 2 members, return conversation. Validate member_id exists and is active
- [x] 5.3 Implement `GET /conversations` — list user's conversations: join conversation_members, include last message preview (subquery), include unread count, cursor-based pagination by last_message_at
- [x] 5.4 Implement `GET /conversations/:id` — get conversation details with members list. Verify membership
- [x] 5.5 Implement `GET /conversations/:id/messages` — cursor-based message pagination: cursor=timestamp, limit=30, dir=before|after. Verify membership
- [x] 5.6 Create `ConversationMemberGuard` or service method to verify user is member of conversation — reuse across all conversation endpoints
- [x] 5.7 Implement `GET /search/messages` — placeholder for server FTS (Phase 2), return 501 Not Implemented for now

## 6. Message Status & Read Receipts

- [x] 6.1 Wire `mark_read` WS event in ChatGateway: update conversation_members.last_read_message_id and last_read_at
- [x] 6.2 Implement read receipt notification: after mark_read, send `message_read` event to sender(s) of unread messages via WS
- [x] 6.3 Wire `mark_delivered` WS event: when client receives new_message, client sends mark_delivered, server notifies sender with `message_status` event
- [x] 6.4 Add unread count to conversation list query: COUNT messages WHERE created_at > last_read_at AND sender_id != current_user

## 7. Push Notifications (Firebase FCM)

- [x] 7.0 Install `firebase-admin` npm package in apps/api: `cd apps/api && npm install firebase-admin`
- [x] 7.1 Create `FirebaseService` in notification module: initialize Firebase Admin SDK from env vars, method `sendPush(token, title, body, data)`. Skip initialization if FIREBASE_PROJECT_ID is empty. Export from NotificationModule
- [x] 7.2 Create `PushNotificationProcessor` (BullMQ): process `chat:push-notification` jobs — query recipient's active sessions for FCM tokens, send push via FirebaseService
- [x] 7.3 Handle invalid FCM tokens: on "registration-token-not-registered" error, remove fcm_token from user_sessions
- [x] 7.4 Create `PATCH /auth/sessions/fcm-token` endpoint in AuthController: update fcm_token for current session
- [x] 7.5 Implement mute check: before sending push, check conversation_members.is_muted — skip push if muted

## 8. Flutter: WebSocket Manager

- [x] 8.1 Create `WebSocketManager` in `lib/core/network/`: connect to `ws://host/ws`, send auth message with JWT, handle auth_success/auth_error
- [x] 8.2 Implement auto-reconnect with exponential backoff: 1s, 2s, 4s, 8s, 16s, max 30s. Re-auth + sync on reconnect
- [x] 8.3 Implement heartbeat handling: respond to server pings with pongs
- [x] 8.4 Implement event routing: parse JSON envelope, dispatch to registered event handlers (send_message, new_message, message_ack, message_read, etc.)
- [x] 8.5 Create `WebSocketProvider` (Riverpod): expose connection state (connecting, connected, disconnected), provide send method

## 9. Flutter: Drift Local Database

- [x] 9.1 Create Drift table definitions: `LocalConversations` and `LocalMessages` mirroring server schema
- [x] 9.2 Create Drift DAO: `ChatDao` with methods — insertConversation, insertMessage, getConversations (sorted by last_message_at), getMessages (by conv_id, ordered by created_at DESC, with limit)
- [x] 9.3 Implement FTS5 virtual table for message content search: `CREATE VIRTUAL TABLE messages_fts USING fts5(content, content=local_messages)`
- [x] 9.4 Implement search method in ChatDao: query FTS5 table, return matching messages with snippet highlight
- [x] 9.5 Implement eviction: delete messages older than 7 days, remove conversations not viewed in 30 days (run on app start)
- [x] 9.6 Create `AppDatabase` class extending `_$AppDatabase`, register in Riverpod provider

## 10. Flutter: Chat List Screen

- [x] 10.1 Create `ChatListScreen` widget: ListView of conversation items, pull-to-refresh, FAB for new conversation
- [x] 10.2 Create `ConversationTile` widget: avatar, name, last message preview, timestamp, unread badge
- [x] 10.3 Create `ChatListNotifier` (Riverpod): load conversations from Drift cache first, then fetch from API, merge and update
- [x] 10.4 Implement real-time updates: listen to WebSocket new_message events, update conversation order and preview
- [x] 10.5 Implement search bar: on text input, query Drift FTS5, show search results overlay

## 11. Flutter: Chat Screen

- [x] 11.1 Create `ChatScreen` widget: message list (reversed ListView), message input bar, conversation header
- [x] 11.2 Create `MessageBubble` widget: sent (right, gold) / received (left, dark surface), content, timestamp, status indicator
- [x] 11.3 Create `MessageInputBar` widget: text field, send button, clear on send
- [x] 11.4 Create `ChatNotifier` (Riverpod): load messages from Drift, listen to WS events, handle optimistic send
- [x] 11.5 Implement optimistic send: generate UUID, insert to Drift with status=pending, display bubble, send via WS, update status on ACK
- [x] 11.6 Implement infinite scroll: detect scroll to top, load older messages via REST API, prepend to list, show shimmer loading
- [x] 11.7 Implement auto-scroll: scroll to bottom on new message if user is at bottom, show "New message" FAB if scrolled up
- [x] 11.8 Implement mark_read: send mark_read WS event when chat screen is open and new messages are visible

## 12. Flutter: Offline Queue & Reconnect Sync

- [x] 12.1 Create `OfflineQueueService`: store pending messages in Drift, send all on reconnect in order
- [x] 12.2 Implement retry logic: exponential backoff (1s→16s), max 5 retries, mark as failed after max
- [x] 12.3 Implement reconnect sync: on WS reconnect, send sync event with last_synced_at, process sync_response, merge into Drift
- [x] 12.4 Create offline banner widget: show "Không có kết nối" when WS disconnected, hide on reconnect

## 13. Flutter: Push Notifications

- [x] 13.1 Add `firebase_messaging` and `firebase_core` dependencies to pubspec.yaml
- [x] 13.2 Initialize Firebase in main entry points (main_dev.dart, main_staging.dart, main_prod.dart)
- [x] 13.3 Request notification permissions on first launch after login
- [x] 13.4 Implement FCM token retrieval and send to server via `PATCH /auth/sessions/fcm-token`
- [x] 13.5 Implement FCM token refresh listener: on new token, update server
- [x] 13.6 Implement foreground message handler: show local notification banner if not in target conversation
- [x] 13.7 Implement notification tap handler: extract conv_id from data, navigate to `/chat/{conv_id}` via go_router

## 14. Flutter: Navigation Updates

- [x] 14.1 Add `/chat` route to go_router config → ChatListScreen
- [x] 14.2 Add `/chat/:id` route to go_router config → ChatScreen with conversation ID param
- [x] 14.3 Create `MainShell` widget with `BottomNavigationBar` (Chat, HR, Tasks, Profile tabs) using go_router `ShellRoute`. Replace current `PlaceholderHomeScreen` with shell layout. Chat tab is the default/first tab
- [x] 14.4 Implement deep link handling for push notification taps

## 15. Integration & Verification

- [ ] 15.1 Verify: TypeORM migration runs successfully — all tables, partitions, indexes created
- [ ] 15.2 Verify: WebSocket connects, authenticates, and receives heartbeat
- [ ] 15.3 Verify: Send message end-to-end — Flutter → WS → DB → Redis → recipient Flutter
- [ ] 15.4 Verify: Offline queue — send while offline, messages delivered on reconnect
- [ ] 15.5 Verify: Push notification — offline user receives FCM push (or graceful skip if Firebase not configured)
- [ ] 15.6 Verify: Cursor pagination — infinite scroll loads older messages correctly
- [ ] 15.7 Verify: Unread count — badge updates on new message, resets on read
- [ ] 15.8 Run `npm run lint` and `npm run build` in apps/api — no errors
- [ ] 15.9 Run `flutter analyze` in apps/mobile — no errors

