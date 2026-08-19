## ADDED Requirements

### Requirement: Script reads Matrix Chat Export JSON
The script SHALL accept a file path argument pointing to a Matrix Chat Export JSON file. The script SHALL parse the JSON and extract `room_name`, `room_creator`, and the `messages` array. The script SHALL validate that the file exists and contains the expected structure before proceeding.

#### Scenario: Valid Matrix export file
- **WHEN** the script is run with a valid Matrix export JSON path
- **THEN** it parses the file and extracts room metadata and messages array

#### Scenario: Missing or invalid file
- **WHEN** the script is run with a non-existent path or malformed JSON
- **THEN** it prints an error message and exits with code 1

### Requirement: Extract unique Matrix users from member events
The script SHALL scan all events with `type: "m.room.member"` and `content.membership: "join"` to build a map of Matrix user IDs to display names. The script SHALL use the `state_key` field as the Matrix user ID and `content.displayname` as the display name.

#### Scenario: Extract members from room
- **WHEN** the export contains 5 `m.room.member` join events with unique `state_key` values
- **THEN** the script builds a map of 5 Matrix user IDs to their display names

### Requirement: 3-tier user matching
The script SHALL match Matrix users to 19T users using a 3-tier cascade strategy:

**Tier 1 — Email prefix**: Extract the localpart from the Matrix user ID (`@vupt:server-chat.19t.vn` → `vupt`), query `users` table for `email LIKE '<localpart>@%'`.

**Tier 2 — Display name**: Strip the suffix after ` - ` from the Matrix display name (`"Phạm Thanh Vũ - DEV"` → `"Phạm Thanh Vũ"`), query `users` table for exact `name` match.

**Tier 3 — Manual mapping**: Read optional `apps/api/scripts/matrix-user-mapping.json` file containing `{ "@matrix_id:server": "19t-user-uuid" }` entries.

The script SHALL try tiers in order and use the first match found.

#### Scenario: User matched by email prefix
- **WHEN** Matrix user `@vupt:server-chat.19t.vn` exists and 19T user with email `vupt@19t.vn` exists
- **THEN** the script maps the Matrix user to the 19T user's UUID via tier 1

#### Scenario: User matched by display name
- **WHEN** email prefix match fails but Matrix displayname "Phạm Thanh Vũ - DEV" stripped to "Phạm Thanh Vũ" matches a 19T user name
- **THEN** the script maps via tier 2

#### Scenario: User matched by manual mapping
- **WHEN** tiers 1 and 2 fail but `matrix-user-mapping.json` contains `{ "@admin:server-chat.19t.vn": "abc-123" }`
- **THEN** the script maps via tier 3

#### Scenario: Unmatched user
- **WHEN** all 3 tiers fail for a Matrix user
- **THEN** the script logs a warning and skips messages from that user

### Requirement: Print mapping table for review
The script SHALL print a table showing all Matrix users, their matched 19T users, and the matching method (email/name/manual/unmatched) before proceeding with import. The script SHALL prompt for confirmation (y/n) before inserting any data.

#### Scenario: Mapping table displayed
- **WHEN** user matching is complete
- **THEN** the script prints a formatted table and waits for user confirmation

#### Scenario: User declines
- **WHEN** the user enters "n" at the confirmation prompt
- **THEN** the script exits without modifying the database

### Requirement: Create GROUP conversation
The script SHALL create a conversation with `type: 'GROUP'`, `name` from the Matrix room name, and `created_by` set to the matched room creator's 19T user ID. The script SHALL check for existing conversations with the same name and type to avoid duplicates.

#### Scenario: New conversation created
- **WHEN** no GROUP conversation with the room name exists
- **THEN** the script creates a new conversation and inserts all matched members into `conversation_members`

#### Scenario: Conversation already exists
- **WHEN** a GROUP conversation with the same name already exists
- **THEN** the script reuses the existing conversation ID and skips member insertion

### Requirement: Insert conversation members
The script SHALL insert one `conversation_members` row per matched Matrix user with `role: 'admin'` for the room creator and `role: 'member'` for all others. The `joined_at` timestamp SHALL be derived from the user's `m.room.member` join event `origin_server_ts`.

#### Scenario: Members inserted with correct roles
- **WHEN** the room has 1 creator and 3 other members
- **THEN** 4 rows are inserted: 1 with role "admin" and 3 with role "member"

### Requirement: Import only decrypted text messages
The script SHALL only import events where `type: "m.room.message"` AND `content.msgtype: "m.text"` AND `content.body` does not start with `"** Unable to decrypt"`. The script SHALL skip all other event types including `m.bad.encrypted`, `m.image`, `m.audio`, `m.video`, `m.file`, and room state events.

#### Scenario: Text message imported
- **WHEN** an event has `msgtype: "m.text"` and body `"Done plan tuần này chưa team"`
- **THEN** the script inserts a message with `type: 'text'` and `content` set to the body

#### Scenario: Encrypted message skipped
- **WHEN** an event has `msgtype: "m.bad.encrypted"`
- **THEN** the script skips it without inserting

#### Scenario: Image message skipped
- **WHEN** an event has `msgtype: "m.image"`
- **THEN** the script skips it without inserting

### Requirement: Deterministic message UUIDs from event_id
The script SHALL generate message UUIDs deterministically from the Matrix `event_id` using SHA-256 hash sliced to UUID v4 format. This ensures idempotency — re-running the script produces the same UUIDs and hits `ON CONFLICT DO NOTHING`.

#### Scenario: Same event_id produces same UUID
- **WHEN** the script processes event_id `$kH1FZAgr-KD4KuXLnL0QvolPiVwXWCv042w1ARBj908` twice
- **THEN** both runs produce the identical UUID

### Requirement: Map reply chains
The script SHALL map Matrix reply references (`content.m.relates_to.m.in_reply_to.event_id`) to `messages.reply_to_id` using an in-memory event_id→UUID lookup table built during import. If the referenced event was skipped (encrypted/media), `reply_to_id` SHALL be NULL.

#### Scenario: Reply to imported message
- **WHEN** message B replies to message A, and both are imported text messages
- **THEN** message B's `reply_to_id` is set to message A's generated UUID

#### Scenario: Reply to skipped message
- **WHEN** message B replies to an encrypted message A that was skipped
- **THEN** message B's `reply_to_id` is NULL

### Requirement: Preserve original timestamps
The script SHALL convert Matrix `origin_server_ts` (epoch milliseconds) to PostgreSQL `timestamptz` for the `created_at` column. The script SHALL verify that the target partition exists for each message's timestamp and create missing quarterly partitions if needed.

#### Scenario: Timestamp conversion
- **WHEN** a message has `origin_server_ts: 1773455078022`
- **THEN** `created_at` is set to the corresponding UTC timestamp

#### Scenario: Missing partition auto-created
- **WHEN** a message timestamp falls in Q3 2025 and no `messages_2025_q3` partition exists
- **THEN** the script creates the partition before inserting

### Requirement: Idempotent execution
The script SHALL use `INSERT ... ON CONFLICT DO NOTHING` for all message inserts (matching the existing `ON CONFLICT (id, created_at) DO NOTHING` pattern). Re-running the script with the same input SHALL not create duplicate data.

#### Scenario: Re-run produces no duplicates
- **WHEN** the script is run twice with the same Matrix export file
- **THEN** the second run inserts 0 new messages and logs "No new messages to import"

### Requirement: Import summary
The script SHALL print a summary after completion: total events in file, messages imported, messages skipped (with breakdown by reason: encrypted, media, unmatched sender), reply chains mapped, and the conversation ID created.

#### Scenario: Summary printed
- **WHEN** import completes successfully
- **THEN** the script prints counts for imported, skipped (encrypted/media/unmatched), and reply chains mapped

