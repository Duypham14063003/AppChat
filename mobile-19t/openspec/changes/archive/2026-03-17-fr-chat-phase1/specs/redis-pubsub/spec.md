## ADDED Requirements

### Requirement: Redis Pub/Sub service with dedicated connection
The system SHALL create a dedicated ioredis client for Pub/Sub operations, separate from the BullMQ connection. The Pub/Sub client SHALL connect to the same Redis instance configured via REDIS_HOST and REDIS_PORT environment variables.

#### Scenario: Pub/Sub client connects on module init
- **WHEN** ChatModule initializes
- **THEN** a dedicated ioredis subscriber client is created and connected to Redis

#### Scenario: Pub/Sub client disconnects on module destroy
- **WHEN** NestJS application shuts down
- **THEN** the Pub/Sub ioredis clients are gracefully disconnected

### Requirement: Publish messages to conversation channels
The system SHALL publish messages to Redis channel `chat:conv:{conv_id}` when a new message is saved to the database. The published payload SHALL be the full message object serialized as JSON.

#### Scenario: Message published after DB insert
- **WHEN** a message is successfully inserted into PostgreSQL
- **THEN** the message is published to `chat:conv:{conv_id}` via Redis PUBLISH

### Requirement: Subscribe to conversation channels for active connections
The system SHALL subscribe to Redis channels for conversations that have at least one member with an active WebSocket connection on this server instance. When a user connects and authenticates, the system SHALL subscribe to all their conversation channels. When the last connection for a conversation is removed, the system SHALL unsubscribe.

#### Scenario: User connects and channels are subscribed
- **WHEN** user authenticates via WebSocket and is a member of conversations [A, B, C]
- **THEN** server subscribes to `chat:conv:A`, `chat:conv:B`, `chat:conv:C` (if not already subscribed)

#### Scenario: Last user disconnects and channel is unsubscribed
- **WHEN** the last WebSocket connection for a user who is the only connected member of conversation X disconnects
- **THEN** server unsubscribes from `chat:conv:X`

### Requirement: Fan-out received messages to WebSocket connections
When a message is received from a Redis subscription, the system SHALL forward it to all active WebSocket connections of users who are members of that conversation (on this server instance).

#### Scenario: Message fan-out to online recipients
- **WHEN** a message is received on `chat:conv:{conv_id}` from Redis
- **THEN** the message is sent via WebSocket to all connected members of that conversation, excluding the original sender's connection that sent the message

### Requirement: Redis connection resilience
The Pub/Sub service SHALL handle Redis disconnections gracefully — log the error, attempt reconnection with exponential backoff, and re-subscribe to all active channels on reconnect.

#### Scenario: Redis temporarily unavailable
- **WHEN** Redis connection drops
- **THEN** the service logs a warning, attempts reconnection, and re-subscribes to all active channels once reconnected

