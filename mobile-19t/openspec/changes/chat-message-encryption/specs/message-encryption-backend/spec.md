## ADDED Requirements

### Requirement: Backend SHALL issue and resolve an active conversation encryption key for authorized members
The system SHALL provide an authenticated way for a member of a conversation to retrieve the active symmetric encryption key metadata and material required to encrypt and decrypt text messages for that conversation.

#### Scenario: Authorized member requests active conversation key
- **WHEN** an authenticated user who belongs to a conversation requests its active encryption key
- **THEN** the backend returns the active `key_id`, algorithm/version metadata, and key material needed for the current encryption phase

#### Scenario: Non-member requests conversation key
- **WHEN** an authenticated user who is not a member of the conversation requests its encryption key
- **THEN** the backend rejects the request with an authorization error

### Requirement: Backend SHALL accept encrypted text message envelopes instead of plaintext text bodies
The system SHALL accept a versioned encrypted envelope for new encrypted text messages and SHALL validate that the envelope carries the required cryptographic metadata before persisting the message.

#### Scenario: Valid encrypted text message is submitted
- **WHEN** a client sends a text message with a valid encryption envelope containing `version`, `alg`, `key_id`, `nonce`, and `ciphertext`
- **THEN** the backend persists the encrypted payload without requiring plaintext `content`

#### Scenario: Encrypted envelope is malformed
- **WHEN** a client sends an encrypted text message with missing or invalid envelope fields
- **THEN** the backend rejects the message as invalid and does not persist it

### Requirement: Backend SHALL persist encrypted text content without storing the plaintext body
The system SHALL store encrypted text-message content as ciphertext plus required envelope metadata, and SHALL avoid persisting the plaintext text body for encrypted messages.

#### Scenario: Encrypted text message is persisted
- **WHEN** the backend stores a newly accepted encrypted text message
- **THEN** the durable message record contains the encrypted envelope fields instead of a plaintext text body

#### Scenario: Legacy plaintext message remains readable
- **WHEN** the backend reads an older plaintext message created before encryption rollout
- **THEN** it preserves that message as a legacy plaintext entry without forcing immediate re-encryption

### Requirement: Backend SHALL return a canonical mixed-mode message shape across history and realtime
The system SHALL serialize both legacy plaintext messages and encrypted text messages through one canonical message shape so clients can distinguish which rendering path to use.

#### Scenario: History returns encrypted text message
- **WHEN** a conversation history request reaches a newly encrypted text message
- **THEN** the backend returns the outer message metadata together with the encrypted envelope and without a plaintext body

#### Scenario: History returns legacy plaintext message
- **WHEN** a conversation history request reaches a legacy plaintext message
- **THEN** the backend returns that message using the legacy plaintext content path

#### Scenario: Realtime broadcast sends encrypted message
- **WHEN** the backend broadcasts a newly persisted encrypted text message over WebSocket
- **THEN** the outbound event uses the same canonical encrypted-message shape as history responses

### Requirement: Backend SHALL support encryption key rotation and stale-key detection
The system SHALL preserve enough metadata to detect when a message was encrypted with a different active key and SHALL let clients recover by resolving the appropriate conversation key.

#### Scenario: Message references older key version
- **WHEN** an encrypted message payload references a prior `key_id`
- **THEN** the backend keeps that `key_id` in the serialized message so clients can resolve the correct decryption key

#### Scenario: Conversation active key changes
- **WHEN** the backend rotates the active conversation encryption key
- **THEN** newly accepted encrypted text messages use the new `key_id` without invalidating older encrypted messages
