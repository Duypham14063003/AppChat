## 1. Backend encryption contract

- [ ] 1.1 Add backend conversation-key storage and an authenticated endpoint for resolving the active encryption key for a conversation member.
- [ ] 1.2 Define the versioned encrypted text-message envelope contract and validate it in chat message creation flows.
- [ ] 1.3 Update backend message persistence and serialization so encrypted text messages store ciphertext metadata instead of plaintext while legacy plaintext rows remain readable.
- [ ] 1.4 Update WebSocket and REST history responses to emit the canonical mixed-mode message shape for legacy plaintext and encrypted text messages.

## 2. Flutter crypto and key management

- [x] 2.1 Add Flutter cryptography support for AES-GCM text-message encryption and decryption with authenticated associated data.
- [x] 2.2 Implement a conversation-key repository/cache layer that resolves, stores, refreshes, and looks up conversation keys by `conv_id` and `key_id`.
- [x] 2.3 Add a shared encrypted-message adapter that parses message envelopes and exposes decrypt/encrypt helpers for realtime and history code paths.

## 3. Chat send, receive, and local persistence

- [x] 3.1 Update outbound text-message sending so the client resolves the active conversation key and sends encrypted envelopes over the existing WebSocket chat flow.
- [x] 3.2 Update inbound realtime and history hydration flows to detect mixed-mode messages, decrypt encrypted text bodies, and keep legacy plaintext rendering intact.
- [x] 3.3 Change durable mobile chat storage so encrypted text messages persist encrypted envelope data rather than plaintext body text.
- [x] 3.4 Rework optimistic-send handling so plaintext is only transient UI state and durable records normalize to the encrypted source of truth after acknowledgement or refresh.

## 4. Chat UI compatibility and fallback behavior

- [x] 4.1 Update timeline rendering so encrypted text messages display decrypted content when available and stable placeholders when decryption fails.
- [x] 4.2 Update conversation previews and other dependent chat surfaces so they never display raw ciphertext and degrade gracefully when decrypted text is unavailable.
- [x] 4.3 Audit reply previews, pinned previews, bookmarks, and reconnect flows for mixed-mode compatibility and add placeholder handling where full decryption support is deferred.

## 5. Verification and rollout safety

- [ ] 5.1 Add backend tests for conversation-key authorization, encrypted-envelope validation, mixed-mode history serialization, and key-rotation metadata handling.
- [x] 5.2 Add Flutter tests for outbound encryption, inbound decryption, mixed-mode hydration, durable-cache normalization, and decrypt-failure fallback states.
- [ ] 5.3 Manually verify direct-chat and group-chat flows for encrypted send/receive, reconnect recovery, legacy plaintext coexistence, and preview behavior before rollout.
