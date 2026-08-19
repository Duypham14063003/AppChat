# Backend Prompt: Blind Index Search For Encrypted Chat Messages

Implement backend support for encrypted chat message search using client-generated blind indexes.

## Goal

Messages are end-to-end encrypted, so the backend must not search plaintext. The mobile client will send hashed search tokens (`blind_index_v1`) derived from plaintext on the client side. The server must only store and query these hashed tokens.

## Client Contract

### 1. New message send over websocket

Incoming `send_message` events for encrypted text messages may now include:

```json
{
  "id": "msg_123",
  "conv_id": "conv_123",
  "type": "text",
  "encrypted_content": {
    "version": 1,
    "alg": "AES-256-GCM",
    "key_id": "key_123",
    "nonce": "...",
    "ciphertext": "..."
  },
  "blind_index_v1": {
    "version": 1,
    "algo": "hmac-sha256",
    "tokens": [
      "hexhash1",
      "hexhash2"
    ]
  },
  "metadata": {
    "mentions": [],
    "reply_to": {}
  }
}
```

### 2. Edit encrypted message over REST

`PATCH /conversations/:convId/messages/:messageId`

Payload may now include:

```json
{
  "metadata": {
    "encrypted_content": {
      "version": 1,
      "alg": "AES-256-GCM",
      "key_id": "key_123",
      "nonce": "...",
      "ciphertext": "..."
    }
  },
  "blind_index_v1": {
    "version": 1,
    "algo": "hmac-sha256",
    "tokens": [
      "hexhash1",
      "hexhash2"
    ]
  }
}
```

### 3. Search endpoint

`GET /search/messages`

Support these query shapes:

- Legacy plaintext mode:
  - `q=<plaintext>`
- Blind index mode for encrypted room search:
  - `conv_id=<conversation-id>`
  - `q_hashes[]=hexhash1`
  - `q_hashes[]=hexhash2`

In blind-index mode, `q` may be omitted entirely.

## Required Backend Changes

### 1. Storage

Create a new table for blind index tokens, for example:

```sql
CREATE TABLE message_blind_indexes (
  id BIGSERIAL PRIMARY KEY,
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  conv_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  token_hash VARCHAR(64) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_message_blind_indexes_conv_hash
  ON message_blind_indexes (conv_id, token_hash);

CREATE INDEX idx_message_blind_indexes_message
  ON message_blind_indexes (message_id);
```

Constraints:
- Do not store plaintext tokens.
- Do not attempt to reverse token hashes.
- Delete old blind index rows when a message is edited or deleted.

### 2. On message create

When receiving `blind_index_v1.tokens`:
- validate `version == 1`
- validate `algo == "hmac-sha256"`
- validate every token is a lowercase hex string
- deduplicate tokens before insert
- insert one row per token hash

If the message is plaintext-only and no blind index is sent:
- keep existing legacy search behavior if still needed

### 3. On encrypted message edit

When an encrypted message is edited:
- replace ciphertext as today
- remove old `message_blind_indexes` rows for that `message_id`
- insert the new token hashes from `blind_index_v1.tokens`

### 4. Search behavior

For blind-index search:
- require `conv_id`
- require non-empty `q_hashes`
- search only inside that conversation
- match messages containing all query hashes if possible
- order results by newest first
- paginate exactly like current search

Suggested SQL approach:

```sql
SELECT m.*
FROM messages m
JOIN message_blind_indexes bi
  ON bi.message_id = m.id
WHERE m.conv_id = :conv_id
  AND bi.token_hash = ANY(:q_hashes)
GROUP BY m.id
HAVING COUNT(DISTINCT bi.token_hash) >= :matched_hash_count
ORDER BY m.created_at DESC
LIMIT :limit;
```

If you want stricter semantics, require:
- `COUNT(DISTINCT bi.token_hash) = :query_hash_count`

### 5. Response shape

Return the same search result structure as current `/search/messages`, but do not rely on plaintext snippet generation on the server for encrypted messages.

For encrypted messages:
- return safe metadata only
- `snippet` may be empty or a neutral placeholder
- client will render the final text/snippet after local decrypt

Example encrypted search result:

```json
{
  "id": "msg_123",
  "conv_id": "conv_123",
  "conv_name": "Team A",
  "conv_avatar_url": null,
  "conv_type": "GROUP",
  "sender_id": "user_123",
  "sender_name": "Duy",
  "created_at": "2026-06-15T03:30:00.000Z",
  "type": "text",
  "snippet": ""
}
```

## Important Rules

- Never ask the client for plaintext message content during server search.
- Never persist plaintext search tokens.
- Never derive blind indexes on the server.
- Only trust the client-generated token hashes as opaque searchable terms.
- Keep backward compatibility for old plaintext search if the system still has non-encrypted messages.

## Phase Recommendation

### Phase 1

- Support blind-index search only for room-scoped search with `conv_id + q_hashes[]`
- Keep global cross-conversation encrypted search out of scope for now

### Phase 2

If global encrypted search is required later, define a separate API contract. Do not reuse plaintext `q` semantics. Possible options:
- client fans out per-conversation blind queries
- client sends grouped hashes by conversation
- dedicated encrypted-search aggregation endpoint

For now, only implement the room-scoped blind-index search path cleanly and safely.
