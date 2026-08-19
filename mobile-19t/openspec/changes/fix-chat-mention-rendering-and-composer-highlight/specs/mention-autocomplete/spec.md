## MODIFIED Requirements

### Requirement: Mention entities stay synchronized with draft text
The system SHALL keep each tracked mention entity aligned with the visible draft text while the user edits around it in the group-chat composer. Edits that occur fully before a mention MUST shift that mention's offset. Edits that occur fully after a mention MUST leave that mention unchanged. Edits that intersect a mention's protected span MUST invalidate that mention entity so the draft no longer treats the affected text as a tracked mention.

#### Scenario: Typing after a mention preserves the entity
- **WHEN** a user selects a mention and continues typing normal text after the inserted mention
- **THEN** the mention entity MUST remain present with a valid offset and length
- **THEN** the trailing text MUST be stored outside the mention span

#### Scenario: Inserting text before a mention shifts its offset
- **WHEN** a draft already contains a tracked mention and the user inserts text before that mention
- **THEN** the mention entity MUST be retained
- **THEN** its offset MUST be updated to match the mention's new position in the draft

#### Scenario: Editing inside a mention removes entity tracking
- **WHEN** the user types, pastes, or deletes characters inside the tracked span of an existing mention
- **THEN** that mention entity MUST be removed from the tracked mention list
- **THEN** the edited text MUST remain in the draft as normal text

#### Scenario: Multiple mentions remain independent
- **WHEN** a draft contains multiple tracked mentions separated by normal text
- **THEN** an edit that affects one mention span MUST NOT invalidate unrelated mentions
- **THEN** unaffected mentions MUST keep correct offsets after any required shifting

### Requirement: The composer highlights tracked mentions while drafting
The group-chat composer SHALL render tracked mentions with inline rich text styling while the user is typing. Highlighting MUST be driven by the tracked mention entities rather than by string pattern matching alone. Each highlighted mention MUST use bold styling and a stable accent color derived deterministically from the mentioned user identifier.

#### Scenario: Mention is highlighted immediately after selection
- **WHEN** the user picks a member from the mention autocomplete list
- **THEN** the inserted `@Name` text MUST appear highlighted in the composer without waiting for send
- **THEN** the trailing space after the mention MUST remain unhighlighted

#### Scenario: Same mention keeps the same color across rebuilds
- **WHEN** the composer rebuilds because the user keeps typing, changes focus, or toggles related UI state
- **THEN** a tracked mention for the same `user_id` MUST keep the same highlight color

#### Scenario: Broken mention loses highlight
- **WHEN** a tracked mention entity is invalidated by an intersecting edit
- **THEN** the affected text MUST render as normal composer text
- **THEN** the composer MUST NOT continue showing highlight styling for that removed entity
