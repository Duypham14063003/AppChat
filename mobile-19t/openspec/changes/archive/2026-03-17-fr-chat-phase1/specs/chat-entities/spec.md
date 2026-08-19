## ADDED Requirements

### Requirement: Conversations table exists with type support
The system SHALL have a `conversations` table with columns: id (uuid PK), type (varchar NOT NULL — DIRECT/GROUP/SAVED), name (varchar nullable — null for DIRECT), avatar_url (text nullable), created_by (uuid FK → users), last_message_at (timestamptz nullable), created_at (timestamptz DEFAULT now()).

#### Scenario: Conversations table created by migration
- **WHEN** TypeORM migrations are run
- **THEN** the `conversations` table exists with all specified columns, constraints, and defaults

### Requirement: Conversation members junction table exists
The system SHALL have a `conversation_members` table with columns: conv_id (uuid FK → conversations), user_id (uuid FK → users), role (varchar DEFAULT 'member' — admin/member), last_read_message_id (uuid nullable), last_read_at (timestamptz nullable), is_muted (boolean DEFAULT false), joined_at (timestamptz DEFAULT now()). Composite PK on (conv_id, user_id).

#### Scenario: Conversation members table created by migration
- **WHEN** TypeORM migrations are run
- **THEN** the `conversation_members` table exists with composite PK, FKs, and all specified columns

#### Scenario: Indexes exist for efficient queries
- **WHEN** developer inspects indexes on conversation_members
- **THEN** indexes exist on (user_id) for listing user's conversations and (conv_id) for listing conversation members

### Requirement: Messages table exists with quarterly partitioning
The system SHALL have a `messages` table partitioned by RANGE on `created_at` with columns: id (uuid), conv_id (uuid NOT NULL FK → conversations), sender_id (uuid NOT NULL FK → users), type (varchar DEFAULT 'text'), content (text nullable), reply_to_id (uuid nullable), forwarded_from_id (uuid nullable), forwarded_from_sender (varchar nullable), metadata (jsonb nullable), search_vector (tsvector GENERATED), created_at (timestamptz NOT NULL DEFAULT now()), edited_at (timestamptz nullable), deleted_at (timestamptz nullable). Composite PK on (id, created_at).

#### Scenario: Messages table is partitioned
- **WHEN** developer queries `pg_partitioned_table` for messages
- **THEN** the table is partitioned by RANGE on created_at with at least Q1 2026 and Q2 2026 partitions

#### Scenario: Timeline index exists
- **WHEN** developer inspects indexes on messages partitions
- **THEN** index `(conv_id, created_at DESC) WHERE deleted_at IS NULL` exists for efficient timeline scroll

#### Scenario: Full-text search index exists
- **WHEN** developer inspects indexes on messages partitions
- **THEN** GIN index on `search_vector` column exists for full-text search

#### Scenario: search_vector is auto-generated
- **WHEN** a message is inserted with content "Hello world"
- **THEN** the search_vector column is automatically populated using `to_tsvector('simple', coalesce(content, ''))`

### Requirement: Message reactions table exists
The system SHALL have a `message_reactions` table with columns: message_id (uuid), user_id (uuid FK → users), emoji (varchar(10) NOT NULL), created_at (timestamptz DEFAULT now()). Composite PK on (message_id, user_id). One reaction per user per message.

#### Scenario: Message reactions table created by migration
- **WHEN** TypeORM migrations are run
- **THEN** the `message_reactions` table exists with composite PK and all specified columns

### Requirement: PostgreSQL extensions enabled
The migration SHALL enable `unaccent` and `pg_trgm` extensions via `CREATE EXTENSION IF NOT EXISTS` for Vietnamese text search support.

#### Scenario: Extensions are available
- **WHEN** developer runs `SELECT * FROM pg_extension`
- **THEN** both `unaccent` and `pg_trgm` extensions are listed

### Requirement: TypeORM entities match database schema
The system SHALL have TypeORM entity classes for Conversation, ConversationMember, Message, and MessageReaction that map to their respective database tables with correct column types, relations, and decorators.

#### Scenario: Entities are registered in ChatModule
- **WHEN** developer inspects ChatModule imports
- **THEN** all 4 entities are registered via `TypeOrmModule.forFeature([...])`

#### Scenario: Entity relations are correctly defined
- **WHEN** developer inspects entity decorators
- **THEN** Conversation has OneToMany to ConversationMember and Message; Message has ManyToOne to Conversation and User

