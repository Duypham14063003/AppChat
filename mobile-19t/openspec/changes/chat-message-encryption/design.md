## Context

The current chat stack sends plaintext text content through `send_message` over the shared `/ws` connection, stores plaintext message content on the server, returns plaintext through REST history APIs, and persists plaintext into the mobile Drift cache. Incoming WebSocket payloads are mapped directly into `LocalMessage.content`, optimistic sends also insert plaintext locally, and multiple UI surfaces such as reply previews, pinned previews, bookmarks, and conversation previews assume message text is directly readable.

The requested encryption phase must fit this existing architecture without breaking chat delivery, offline queue behavior, or the user-scoped WebSocket connection already shared by chat and rewards. The system also has a large existing message corpus, so migration must support mixed-mode rendering where older plaintext messages and newer encrypted messages coexist.

This is not a true end-to-end public-key encryption rollout. The immediate goal is a first secure transport-and-storage phase using conversation-scoped symmetric encryption, versioned payload envelopes, and authenticated key retrieval for conversation members.

## Goals / Non-Goals

**Goals:**
- Encrypt new text-message content with AES-GCM before it leaves the Flutter client.
- Replace plaintext message transport/storage with a versioned encrypted envelope for WebSocket sends, realtime events, REST history, and durable mobile cache.
- Introduce a conversation-scoped key model that authenticated conversation members can resolve and reuse across sends and receives.
- Preserve optimistic sending, reconnect recovery, and mixed-mode history rendering during migration.
- Keep failure states survivable by showing placeholders and allowing refetch or key refresh rather than crashing the chat UI.

**Non-Goals:**
- Deliver full public-key E2EE or hide message content from a trusted server in this phase.
- Encrypt media binaries, upload payloads, file names, voice payloads, or video metadata in this phase.
- Encrypt every metadata field immediately, such as reply snapshots, pinned-message previews, bookmark previews, and notification previews.
- Redesign the WebSocket transport shape beyond what is required to carry encrypted message envelopes.
- Re-encrypt legacy plaintext rows in one blocking migration.

## Decisions

### D1: Use a server-managed conversation key, not `userId + salt`

**Decision:** Each conversation will have a server-managed symmetric message key identified by `key_id`. The Flutter client fetches the active key for a conversation through an authenticated backend endpoint and uses that key to encrypt/decrypt text-message content.

**Why:** A `userId + fixed salt` scheme does not work well for multi-member conversations, does not support key rotation, and does not create a stable shared secret for all conversation members. A conversation-scoped key aligns with direct and group chats, supports future rotation, and fits the existing conversation-centric chat architecture.

**Alternatives considered:**
- Derive a deterministic key from `userId + fixed salt`. Rejected because it is weak for groups, rotation, and member changes, and is not meaningfully safer if the server can derive the same value.
- Jump directly to public-key E2EE. Rejected for this phase because it adds substantially more protocol, device-key, and membership-management complexity than the current codebase can absorb in one change.

### D2: Use a versioned AES-256-GCM envelope for encrypted text content

**Decision:** Encrypted text messages will be represented by a versioned envelope that carries `alg`, `version`, `key_id`, `nonce`, and `ciphertext`, with authenticated associated data bound to stable message context such as `message_id`, `conv_id`, and `type`.

**Why:** AES-GCM provides authenticated encryption, is widely available on Flutter and Node.js, and makes payload validation straightforward. A versioned envelope gives the project a clear migration path for later key rotation or algorithm changes without changing the surrounding message contract again.

**Alternatives considered:**
- Store raw ciphertext only. Rejected because the client and server still need nonce and version metadata to decrypt safely.
- Use CBC or unauthenticated AES modes. Rejected because integrity protection is required for message payloads.

### D3: Encrypt only the text body in phase 1 and keep metadata mostly plaintext

**Decision:** For phase 1, only text-message body content moves into the encrypted envelope. Message routing fields such as `id`, `conv_id`, `sender_id`, `type`, timestamps, and existing non-sensitive metadata remain available in the outer message structure.

**Why:** The chat pipeline already depends on outer routing fields for optimistic reconciliation, unread counts, list previews, and timeline ordering. Encrypting those fields immediately would widen the scope into message indexing and transport semantics. Encrypting the text body first captures the sensitive core while keeping integration changes manageable.

**Alternatives considered:**
- Encrypt the entire message object. Rejected because the existing server and mobile state machines need plaintext routing metadata.
- Keep all metadata plaintext forever. Rejected because some metadata such as reply snapshots should be revisited in later phases.

### D4: Durable mobile storage must stop persisting plaintext for encrypted text messages

**Decision:** Once an encrypted text message is accepted into the durable pipeline, the mobile cache must persist the encrypted envelope rather than plaintext body text. Decrypted plaintext may exist transiently in memory for composition, optimistic rendering, and the active conversation state, but it must not be the durable source of truth for encrypted messages.

**Why:** Persisting plaintext into Drift would leave the current local-exposure problem unsolved even if network transport is encrypted. The durable layer should reflect the same ciphertext contract used by the backend.

**Alternatives considered:**
- Keep Drift plaintext while encrypting only over the network. Rejected because it only moves the exposure point.
- Remove optimistic local rendering entirely. Rejected because it would visibly regress chat UX.

### D5: Mixed-mode message handling is mandatory

**Decision:** The client and server must support both plaintext legacy messages and encrypted phase-1 messages at the same time. The message serializer and mobile mapper will detect whether a message carries plaintext `content` or an encrypted envelope and render appropriately.

**Why:** The application already has existing conversations and caches. A big-bang migration would be risky and operationally heavy. Mixed-mode support keeps rollout incremental and rollback-friendly.

**Alternatives considered:**
- Migrate all historical rows before releasing the feature. Rejected because it is operationally expensive and blocks delivery.
- Fail closed on plaintext history after rollout. Rejected because it would break old conversations.

### D6: Key resolution and refresh must be explicit and cacheable

**Decision:** Flutter will maintain a conversation-key cache keyed by `conv_id` and `key_id`, with explicit fetch and refresh behavior. Decrypt failures caused by missing or stale keys will trigger key refresh and then a message refetch or retry path.

**Why:** Re-fetching a key on every message would add unnecessary latency and server load. A cache also supports history hydration and reconnect processing. Explicit refresh behavior is needed for future rotation and recovery from stale local state.

**Alternatives considered:**
- Embed the raw conversation key in every message payload. Rejected because it multiplies exposure and payload size.
- Resolve keys once per app session only. Rejected because reconnects and rotations need recovery paths.

### D7: Conversation previews and dependent UI must degrade gracefully

**Decision:** UI surfaces that depend on message text but are not fully encryption-aware in phase 1 will use degraded placeholders when decrypted text is unavailable. Conversation preview generation may use decrypted plaintext in-memory when available, but when not available it must fall back to stable placeholder labels rather than exposing ciphertext.

**Why:** The existing chat UI has many text-derived surfaces. Requiring perfect decrypted availability everywhere in phase 1 would delay the rollout substantially. A graceful placeholder strategy lets encrypted content land without crashing or leaking ciphertext blobs into the UI.

**Alternatives considered:**
- Block rollout until every dependent surface is fully encryption-aware. Rejected as too large for the first phase.
- Show raw ciphertext when decryption fails. Rejected because it is unusable and confusing.

## Risks / Trade-offs

- [Risk] Server-managed conversation keys do not provide true E2EE. → Mitigation: document the trust model clearly and keep the envelope versioned so a future public-key phase can build on it.
- [Risk] Moving durable storage from plaintext to ciphertext complicates optimistic sends and local hydration. → Mitigation: keep plaintext only in transient in-memory state and normalize durable rows after send acknowledgement or fetch.
- [Risk] Existing chat features such as search, bookmarks, pin previews, and reply snapshots currently assume plaintext content. → Mitigation: phase the rollout to text-body protection first and define placeholder behavior for dependent surfaces not yet fully upgraded.
- [Risk] Key rotation or membership changes could invalidate cached conversation keys unexpectedly. → Mitigation: include `key_id` in envelopes and add explicit cache refresh behavior on decrypt failure or backend rotation signals.
- [Risk] Reconnect, history refresh, and offline retries can duplicate decrypt work or race against key fetches. → Mitigation: centralize envelope parsing and key lookup in one crypto adapter layer used by both realtime and REST hydration.

## Migration Plan

1. Add backend conversation-key storage and an authenticated key-resolution endpoint for conversation members.
2. Introduce the encrypted text-message envelope contract and update backend serializers to emit either plaintext legacy content or encrypted payloads in mixed mode.
3. Update WebSocket text-message sending to accept encrypted envelopes while keeping outer routing fields stable.
4. Add Flutter crypto utilities and a conversation-key cache used by outbound send, inbound realtime, and history hydration.
5. Update the mobile durable cache to store encrypted envelopes for encrypted text messages and only decrypt into transient UI state.
6. Add fallback placeholders and decrypt-failure recovery paths for timeline items and conversation previews.
7. Roll out behind capability checks or safe mixed-mode handling, then verify direct chat, group chat, reconnect, offline resend, and legacy-history scenarios.

**Rollback:** Keep mixed-mode support in place. If encrypted sending causes regressions, stop issuing conversation keys for new sends and continue rendering existing plaintext messages. Encrypted messages already stored can still be displayed on clients with working keys; backend can temporarily disable new encrypted message creation without losing historical readability.

## Open Questions

- Should the backend expose the active conversation key through a dedicated `/conversations/:id/encryption-key` endpoint, or should it piggyback on an existing conversation-detail payload?
- Should phase 1 edit-message support be blocked for encrypted messages until edit flows are updated, or should encrypted-text edit be included in the initial rollout scope?
