## ADDED Requirements

### Requirement: LocalMessageReactions Drift table
The system SHALL define a `LocalMessageReactions` Drift table with columns: `messageId` (TEXT), `userId` (TEXT), `emoji` (TEXT), `userName` (TEXT), `createdAt` (DATETIME). The composite primary key SHALL be `(messageId, userId, emoji)`.

#### Scenario: Table created after codegen
- **WHEN** `build_runner` runs
- **THEN** the `local_message_reactions` table is generated in the SQLite database with the correct schema

### Requirement: ChatDao reaction queries
The `ChatDao` SHALL provide methods to:
1. `upsertReaction(messageId, userId, emoji, userName)` — insert or replace a reaction
2. `deleteReaction(messageId, userId, emoji)` — remove a specific reaction
3. `getReactionsForMessage(messageId)` — return all reactions for a message
4. `replaceReactionsForMessage(messageId, reactions)` — replace all reactions for a message (used during sync)

#### Scenario: Upsert a reaction
- **WHEN** `upsertReaction` is called with a new tuple
- **THEN** a row is inserted into `local_message_reactions`

#### Scenario: Delete a reaction
- **WHEN** `deleteReaction` is called for an existing tuple
- **THEN** the row is removed from `local_message_reactions`

#### Scenario: Get reactions for message
- **WHEN** `getReactionsForMessage` is called
- **THEN** all reactions for that message are returned, grouped by emoji with count and user list

### Requirement: Reaction Riverpod provider
The system SHALL provide a `messageReactionsProvider(messageId)` Riverpod provider that watches the local SQLite reactions for a given message and returns aggregated reaction data: `List<ReactionGroup>` where each group has `emoji`, `count`, `users` (list of `{id, name}`), and `isMine` (whether current user reacted with this emoji).

#### Scenario: Provider emits reaction data
- **WHEN** a message has reactions in local DB
- **THEN** `messageReactionsProvider` emits the aggregated list with correct counts and `isMine` flags

#### Scenario: Provider updates on local change
- **WHEN** a reaction is added or removed locally
- **THEN** the provider re-emits updated data

### Requirement: WebSocket reaction_update listener
The `ChatNotifier` (or a dedicated reaction notifier) SHALL listen for `reaction_update` WebSocket events and update the local SQLite database accordingly. It SHALL replace all reactions for the affected message with the full snapshot from the event payload.

#### Scenario: Receive reaction_update from server
- **WHEN** a `reaction_update` event arrives via WebSocket
- **THEN** the local `local_message_reactions` table is updated for that message with the full reaction snapshot

### Requirement: Optimistic reaction toggle
When the user toggles a reaction, the system SHALL immediately update the local SQLite database (optimistic update) before sending the `toggle_reaction` WebSocket event. If the server responds with an error, the system SHALL revert the local change.

#### Scenario: Optimistic add
- **WHEN** user taps to add a reaction
- **THEN** the reaction appears in the UI immediately (local insert), then `toggle_reaction` is sent to server

#### Scenario: Server rejects — revert
- **WHEN** server responds with `REACTION_LIMIT` error after optimistic add
- **THEN** the optimistic reaction is removed from local DB and UI updates accordingly

### Requirement: Reactions synced with messages
When messages are fetched or synced (via `getMessages` or `syncMessages`), the system SHALL parse the `reactions` field from each message response and store them in `local_message_reactions`. This ensures reactions are available offline.

#### Scenario: Initial message load includes reactions
- **WHEN** messages are fetched for a conversation
- **THEN** each message's `reactions` array is parsed and stored in `local_message_reactions`

#### Scenario: Sync updates reactions
- **WHEN** a sync response includes messages with reactions
- **THEN** local reaction data is updated to match the server state

### Requirement: Reaction data model
The system SHALL define a `ReactionGroup` model class with fields: `emoji` (String), `count` (int), `users` (List of `{id, name}`), `isMine` (bool). This model is used by both the provider and UI widgets.

#### Scenario: Model construction
- **WHEN** `ReactionGroup` is constructed with emoji "👍", count 3, users list, isMine true
- **THEN** all fields are accessible and correctly typed
