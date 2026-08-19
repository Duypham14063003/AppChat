## Context

The company uses Matrix (Element) for internal chat with ~50 employees. The 19T app is replacing Matrix. Users are already synced from Odoo to the 19T `users` table via `npm run seed:users`. One Matrix room export JSON file exists at `requirements/matrix - Chat Export - 2026-03-17T16-17-39.323Z.json` (45K lines, ~2128 messages, room "Tiếng Trung Thanh Hằng").

The export contains mixed event types: `m.room.member` (joins/invites), `m.room.message` (actual messages), and room state events. Most messages are `m.bad.encrypted` (undecryptable due to E2E encryption key loss). Only recent messages with `msgtype: "m.text"` have readable content. Media messages (`m.image`, `m.audio`) have encrypted file references that cannot be downloaded without keys.

Existing script patterns: `seed-users.ts` (NestJS bootstrap), `seed-test-conv.mjs` (raw `pg` client). The `messages` table is range-partitioned by `created_at` with Q1 2026 (Jan-Mar) and Q2 2026 (Apr-Jun) partitions.

## Goals / Non-Goals

**Goals:**
- Import readable text messages from one Matrix room into 19T database
- Match Matrix users to existing 19T users automatically with manual fallback
- Preserve reply chains and original timestamps
- Idempotent — safe to re-run without duplicating data

**Non-Goals:**
- Import encrypted/undecryptable messages
- Import media files (images, audio, video)
- Import reactions (no `m.reaction` events found in export)
- Import multiple rooms in one run
- Real-time sync or ongoing Matrix bridge
- Import into Flutter local database (Drift) — only server-side PostgreSQL

## Decisions

### D1: Raw `pg` client vs NestJS bootstrap

**Decision**: Raw `pg` client (like `seed-test-conv.mjs`).

**Why**: The import script only needs SQL INSERTs into existing tables. No NestJS services, guards, or business logic needed. Raw `pg` is faster to start (~100ms vs ~3s for NestJS bootstrap), simpler to debug, and has no dependency on app module configuration. The `pg` package is already available as a transitive dependency of TypeORM.

**Alternative**: NestJS bootstrap like `seed-users.ts`. Rejected — overkill for direct SQL inserts.

### D2: TypeScript (.ts) vs JavaScript (.mjs)

**Decision**: TypeScript `.ts` run via `tsx`.

**Why**: Consistent with `seed-users.ts` pattern. Type safety for parsing the complex Matrix JSON structure. `tsx` is already a dev dependency.

### D3: User matching strategy — 3-tier cascade

**Decision**: Try in order: (1) email prefix match, (2) display name match, (3) manual mapping file.

**Tier 1 — Email prefix**: Extract username from Matrix ID (`@vupt:server-chat.19t.vn` → `vupt`), query `SELECT id FROM users WHERE email LIKE 'vupt@%'`. Most reliable since Matrix usernames often mirror email prefixes.

**Tier 2 — Display name**: Strip suffix after ` - ` from Matrix displayname (`"Phạm Thanh Vũ - DEV"` → `"Phạm Thanh Vũ"`), query `SELECT id FROM users WHERE name = $1`. Handles cases where email prefix doesn't match.

**Tier 3 — Manual mapping**: Read optional `matrix-user-mapping.json` file with `{ "@matrix_id": "19t-user-uuid" }` overrides. Fallback for edge cases (e.g., `@admin:server-chat.19t.vn` → CEO's uuid).

Unmatched users are logged and their messages are skipped.

### D4: Idempotency — conversation dedup

**Decision**: Check if a conversation with the same name and type GROUP already exists before creating. If it exists, skip conversation + member creation but still import new messages (using `ON CONFLICT DO NOTHING` on message insert).

**Why**: Safe to re-run if script fails mid-import. Messages use `ON CONFLICT (id, created_at) DO NOTHING` which is already the pattern in `ChatService.sendMessage()`.

### D5: Message ID generation

**Decision**: Generate deterministic UUIDs from Matrix event_id using `crypto.createHash('sha256').update(event_id).digest('hex')` sliced to UUID format.

**Why**: Deterministic IDs make the script idempotent — re-running produces the same UUIDs, hitting `ON CONFLICT DO NOTHING`. Random UUIDs would create duplicates on re-run.

### D6: Partition handling for old timestamps

**Decision**: The script checks the date range of messages to import. If any fall outside existing partitions (Q1-Q2 2026), it creates the needed partition(s) before inserting.

**Why**: Matrix messages may have timestamps from 2025 or earlier. Inserting into a non-existent partition causes a PostgreSQL error. Auto-creating partitions is safer than requiring manual setup.

## Risks / Trade-offs

- **[Risk] Matrix timestamps outside partition range** → Script auto-creates quarterly partitions for any date range found in the data. Partitions follow existing naming: `messages_YYYY_qN`.

- **[Risk] User matching false positives** → Email prefix match could theoretically match wrong user if two users share a prefix. Mitigated by the small team size (<50) and the script printing a full mapping table for manual review before proceeding.

- **[Risk] Reply chain broken for encrypted messages** → If message A replies to encrypted message B (which was skipped), `reply_to_id` will be NULL. Acceptable — the text content is still imported, just without the reply link.

- **[Trade-off] No media import** → Images and voice messages are lost. Acceptable per scope decision — encrypted files can't be downloaded anyway.

- **[Trade-off] `search_vector` column** → The `messages` table has a `GENERATED ALWAYS` tsvector column. Direct INSERT will auto-populate it from `content`. No special handling needed.

## Migration Plan

1. Run `npm run seed:users` to ensure users table is populated from Odoo
2. (Optional) Create `apps/api/scripts/matrix-user-mapping.json` for manual overrides
3. Run `npm run import:matrix -- <path-to-json>` — script prints mapping table, asks for confirmation, then imports
4. Verify: check conversation exists, message count matches, reply chains intact
5. Rollback: `DELETE FROM conversations WHERE id = '<imported-conv-id>'` (CASCADE deletes members + messages)

