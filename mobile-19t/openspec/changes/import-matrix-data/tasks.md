## 1. Script Setup

- [ ] 1.1 Create `apps/api/scripts/import-matrix.ts` with basic structure: import `pg`, `crypto`, `fs`, `path`, `readline`; parse CLI argument for JSON file path; connect to PostgreSQL using env vars (same pattern as `seed-test-conv.mjs`); wrap in `main()` with error handling
- [ ] 1.2 Add `"import:matrix": "tsx scripts/import-matrix.ts"` to `apps/api/package.json` scripts section
- [ ] 1.3 Define TypeScript interfaces for Matrix export structure: `MatrixExport` (room_name, room_creator, messages), `MatrixEvent` (type, sender, content, room_id, origin_server_ts, event_id, state_key, unsigned), `MatrixMessageContent` (msgtype, body, m.relates_to, m.mentions, format, formatted_body)

## 2. JSON Parsing & Validation

- [ ] 2.1 Read and parse the JSON file from CLI argument path; validate top-level structure has `room_name` and `messages` array; exit with error if invalid
- [ ] 2.2 Extract room metadata: `room_name`, `room_creator` from top-level fields
- [ ] 2.3 Scan `messages` array and categorize events by type; log counts: total events, `m.room.member`, `m.room.message` (by msgtype: `m.text`, `m.bad.encrypted`, `m.image`, `m.audio`, other), room state events

## 3. User Extraction & Matching

- [ ] 3.1 Extract unique Matrix users from `m.room.member` events where `content.membership === "join"`: build map of `state_key` (Matrix user ID) → `content.displayname`
- [ ] 3.2 Implement tier 1 matching — email prefix: for each Matrix user ID, extract localpart (`@vupt:server` → `vupt`), query `SELECT id, name, email FROM users WHERE email LIKE $1` with `${localpart}@%`
- [ ] 3.3 Implement tier 2 matching — display name: strip suffix after ` - ` from displayname, query `SELECT id, name, email FROM users WHERE name = $1`
- [ ] 3.4 Implement tier 3 matching — manual mapping: check if `apps/api/scripts/matrix-user-mapping.json` exists, if so read it and apply `{ "@matrix_id": "uuid" }` overrides for any still-unmatched users
- [ ] 3.5 Build final mapping table: `Map<string, { userId: string; name: string; method: string }>` for matched users, `Set<string>` for unmatched
- [ ] 3.6 Print formatted mapping table to console showing: Matrix ID, Matrix displayname, 19T user name, 19T user ID, match method (email/name/manual/UNMATCHED)

## 4. Confirmation Prompt

- [ ] 4.1 After printing mapping table and import preview (room name, member count, estimated importable messages), prompt user with `readline` for "Proceed with import? (y/n)"
- [ ] 4.2 If user enters "n" or anything other than "y", exit gracefully with message "Import cancelled"

## 5. Conversation Creation

- [ ] 5.1 Check if GROUP conversation with same `name` already exists: `SELECT id FROM conversations WHERE type = 'GROUP' AND name = $1`
- [ ] 5.2 If not exists: generate UUID, INSERT into `conversations` (id, type='GROUP', name=room_name, created_by=matched creator UUID, created_at=now())
- [ ] 5.3 If not exists: INSERT into `conversation_members` for each matched user — role='admin' for creator, role='member' for others, `joined_at` from their `m.room.member` event `origin_server_ts`
- [ ] 5.4 If exists: log "Conversation already exists, reusing ID: <id>", skip member insertion, use existing conv_id for message import

## 6. Partition Check

- [ ] 6.1 Scan all importable messages (m.text, decrypted) and find min/max `origin_server_ts`
- [ ] 6.2 Calculate which quarterly partitions are needed (e.g., Q3 2025 = `messages_2025_q3` for range `2025-07-01` to `2025-10-01`)
- [ ] 6.3 For each needed partition, check if it exists: `SELECT 1 FROM pg_class WHERE relname = $1`
- [ ] 6.4 If missing, create partition: `CREATE TABLE "messages_YYYY_qN" PARTITION OF "messages" FOR VALUES FROM ('YYYY-MM-01') TO ('YYYY-MM-01')`

## 7. Message Import

- [ ] 7.1 Implement deterministic UUID generation: `function eventIdToUuid(eventId: string): string` — SHA-256 hash of event_id, format first 32 hex chars as UUID v4 format (8-4-4-4-12)
- [ ] 7.2 First pass: build event_id → UUID lookup table for ALL importable text messages (needed for reply mapping)
- [ ] 7.3 Second pass: for each importable message (m.room.message, msgtype=m.text, body not starting with "** Unable to decrypt"), build INSERT values: id (deterministic UUID), conv_id, sender_id (from mapping), type='text', content (body), reply_to_id (lookup from m.relates_to.m.in_reply_to.event_id → UUID, or NULL), created_at (from origin_server_ts ms → Date)
- [ ] 7.4 Skip messages where sender is unmatched (not in mapping table); increment skip counter
- [ ] 7.5 Batch INSERT messages using `INSERT INTO messages (id, conv_id, sender_id, type, content, reply_to_id, metadata, created_at) VALUES ... ON CONFLICT (id, created_at) DO NOTHING` — batch size 100 rows per query
- [ ] 7.6 After all inserts: UPDATE `conversations.last_message_at` to the max `created_at` of imported messages

## 8. Summary & Cleanup

- [ ] 8.1 Print import summary: total events in file, messages imported (count of rows actually inserted), messages skipped (encrypted count, media count, unmatched sender count), reply chains mapped (count of non-null reply_to_id), conversation ID
- [ ] 8.2 Close PostgreSQL connection and exit with code 0

## 9. Verification

- [ ] 9.1 Run `npm run lint` in `apps/api` — fix any issues
- [ ] 9.2 Run `npm run build` in `apps/api` — fix any TypeScript errors
- [ ] 9.3 Test: run `npm run import:matrix -- ../../requirements/"matrix - Chat Export - 2026-03-17T16-17-39.323Z.json"` against local database with seeded users — verify conversation created, messages imported, reply chains intact
- [ ] 9.4 Test idempotency: run the same command again — verify 0 new messages inserted

