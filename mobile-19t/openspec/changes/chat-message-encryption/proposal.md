## Why

Chat messages are currently sent, stored, synchronized, and rendered as plaintext across the mobile client, WebSocket transport, REST history APIs, and local caches. The product now needs a first concrete encryption phase so message content is no longer persisted or broadcast as plaintext while preserving the existing chat experience, offline behavior, and realtime synchronization model.

## What Changes

- Add a conversation-scoped message encryption model for text chat using versioned AES-GCM envelopes instead of plaintext `content` in transport and storage.
- Add backend support for issuing or resolving conversation encryption keys, accepting encrypted text payloads, storing ciphertext, and returning the same encrypted envelope through history and realtime events.
- Add Flutter-side encrypt/decrypt flows for outbound text messages, inbound WebSocket events, and REST history hydration while keeping optimistic UI behavior intact.
- Add mixed-mode support so existing plaintext history continues to render while new encrypted messages can coexist during migration.
- Add fallback and failure handling for missing keys, decrypt failures, reconnects, and local-cache refreshes without breaking current chat delivery.
- Keep media, reply metadata hardening, search indexing, notification preview decryption, and true end-to-end public-key cryptography out of scope for this first change.

## Capabilities

### New Capabilities
- `message-encryption-backend`: Server-side conversation-key management, encrypted message acceptance, ciphertext persistence, and encrypted chat serialization over REST and WebSocket.
- `message-encryption-ui`: Flutter-side text message encryption, decryption, optimistic rendering, local cache handling, and mixed-mode chat timeline support.

### Modified Capabilities
<!-- No existing capability requirements are being modified. -->

## Impact

- **Backend chat APIs**: WebSocket `send_message`, chat history retrieval, message serialization, and any edit flows that currently assume plaintext message content.
- **Backend services/data model**: chat service, persistence schema, conversation membership/key resolution, and migration handling for old plaintext rows.
- **Realtime contract**: `new_message` and related chat payloads must carry versioned encrypted envelopes for encrypted text messages.
- **Mobile data layer**: `chat_providers.dart`, `chat_repository.dart`, local Drift storage, and message mapping helpers that currently read and write plaintext `content`.
- **Mobile UI**: timeline rendering, optimistic send state, reply previews, conversation previews, and decrypt-failure placeholders where message text may be unavailable.
- **Dependencies**: Flutter cryptography package(s) and backend crypto utilities for AES-GCM envelope generation/validation.
