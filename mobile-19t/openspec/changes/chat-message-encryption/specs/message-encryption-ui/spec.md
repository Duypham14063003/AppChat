## ADDED Requirements

### Requirement: Flutter SHALL encrypt new text messages before sending them over chat WebSocket transport
The system SHALL encrypt new text-message bodies on the client with the active conversation key before dispatching the message through the shared chat WebSocket connection.

#### Scenario: User sends encrypted text message
- **WHEN** a user sends a text message in a conversation with an active encryption key
- **THEN** the app sends an encrypted envelope instead of plaintext message content

#### Scenario: Conversation key is missing before send
- **WHEN** the user sends a text message and the active conversation key is not locally available
- **THEN** the app resolves the conversation key before dispatching the encrypted message or surfaces a recoverable send failure

### Requirement: Flutter SHALL decrypt encrypted text messages from realtime and history sources
The system SHALL decrypt encrypted text-message envelopes received from WebSocket events and REST history APIs before rendering them in chat UI.

#### Scenario: Realtime encrypted message arrives
- **WHEN** a `new_message` event arrives with an encrypted text-message envelope
- **THEN** the app resolves the referenced conversation key, decrypts the message body, and renders the plaintext in the timeline

#### Scenario: History includes encrypted text message
- **WHEN** conversation history includes an encrypted text-message envelope
- **THEN** the app decrypts that message body during hydration before exposing it to the timeline renderer

### Requirement: Flutter SHALL support mixed-mode rendering for legacy plaintext and new encrypted messages
The system SHALL render both legacy plaintext messages and new encrypted messages in the same conversation without forcing a full migration first.

#### Scenario: Conversation contains mixed history
- **WHEN** the app loads a conversation that includes both legacy plaintext rows and newer encrypted text messages
- **THEN** both message types render correctly in their original order

#### Scenario: Legacy plaintext message is received after encryption rollout
- **WHEN** the app receives a legacy plaintext message shape during the mixed-mode period
- **THEN** it renders that message without attempting encrypted-envelope decryption

### Requirement: Flutter SHALL avoid using durable plaintext as the source of truth for encrypted text messages
The system SHALL persist encrypted text messages in durable local storage using the encrypted envelope contract, while limiting decrypted plaintext to transient in-memory UI state.

#### Scenario: Encrypted text message is cached locally
- **WHEN** the app writes an encrypted text message to durable local storage
- **THEN** the durable record stores encrypted payload data rather than plaintext body text

#### Scenario: Optimistic send shows message immediately
- **WHEN** the user sends a text message and the app enters optimistic state before acknowledgment
- **THEN** the UI may render transient plaintext immediately, but the durable source of truth is normalized to the encrypted envelope after send confirmation or refresh

### Requirement: Flutter SHALL fail gracefully when decryption cannot complete
The system SHALL not crash if an encrypted message cannot be decrypted because of missing keys, stale keys, or malformed payloads, and SHALL provide a stable recovery path.

#### Scenario: Decrypt fails due to missing key
- **WHEN** the app receives an encrypted text message whose referenced key is not locally available
- **THEN** the app attempts a conversation-key refresh and shows a recoverable placeholder state if decryption still cannot complete

#### Scenario: Encrypted payload is malformed
- **WHEN** the app attempts to decrypt an invalid encrypted message payload
- **THEN** the app keeps the timeline stable and renders a non-crashing fallback placeholder instead of raw ciphertext

### Requirement: Flutter SHALL keep conversation previews and dependent chat surfaces ciphertext-safe
The system SHALL ensure that conversation previews and related chat UI surfaces never display raw ciphertext when decrypted plaintext is unavailable.

#### Scenario: Preview can use decrypted text
- **WHEN** the app has successfully decrypted the latest message in a conversation
- **THEN** the conversation preview may display the decrypted plaintext summary

#### Scenario: Preview cannot decrypt latest message
- **WHEN** the latest message in a conversation cannot yet be decrypted
- **THEN** the conversation preview shows a stable placeholder label instead of raw ciphertext
