## Why

The company is migrating from Matrix (Element) to the 19T internal app for team communication. Existing chat history in Matrix rooms needs to be preserved so employees don't lose context from past conversations. A one-time import script is needed to migrate data from Matrix JSON exports into the 19T PostgreSQL database. The Matrix export file is available at `requirements/matrix - Chat Export - 2026-03-17T16-17-39.323Z.json`.

## What Changes

- New standalone script `apps/api/scripts/import-matrix.ts` that:
  - Reads a Matrix Chat Export JSON file (Element's export format)
  - Extracts room metadata (name, creator) and member list from `m.room.member` events
  - Matches Matrix users to existing 19T users (seeded from Odoo) using 3-tier strategy: email prefix match → display name match (stripped suffix) → manual mapping file
  - Creates a GROUP conversation with matched members
  - Imports only decrypted text messages (`m.room.message` with `msgtype: "m.text"`) — skips `m.bad.encrypted` and media types (`m.image`, `m.audio`, `m.video`, `m.file`)
  - Maps reply chains (`m.relates_to.m.in_reply_to`) to `reply_to_id` using event_id→message_uuid lookup
  - Preserves original timestamps (`origin_server_ts` → `created_at`)
- New npm script `import:matrix` in `apps/api/package.json`
- Optional manual user mapping file `apps/api/scripts/matrix-user-mapping.json` for unmatched users

## Capabilities

### New Capabilities
- `matrix-data-import`: One-time script to import Matrix chat export JSON into 19T database — user matching, conversation creation, text message import with reply mapping

### Modified Capabilities
<!-- No existing spec-level requirements are changing. This is a standalone migration script. -->

## Impact

- **Database**: INSERTs into existing tables: `conversations`, `conversation_members`, `messages`. No schema changes.
- **Scripts**: New file `apps/api/scripts/import-matrix.ts`, optional `apps/api/scripts/matrix-user-mapping.json`
- **Package.json**: New script entry `import:matrix`
- **Dependencies**: Uses `pg` (already available via TypeORM) — no new dependencies needed
- **Partitions**: Messages will be inserted with original Matrix timestamps. Must ensure partition exists for the date range (Q1-Q2 2026 partitions already exist; older messages may need additional partitions).

