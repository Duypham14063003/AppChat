## MODIFIED Requirements

### Requirement: Message bubbles render valid mention spans inline
The system SHALL render mentions in chat message bubbles according to the persisted `metadata.mentions` ranges, even when a message contains additional normal text before or after the mention. Rendering MUST preserve the original sentence order, style valid mention ranges distinctly, and leave all non-mention text unchanged.

#### Scenario: Mention at the start of a sentence with trailing text
- **WHEN** a message begins with a valid mention span and normal text follows it
- **THEN** the mention MUST render with mention styling
- **THEN** the trailing text MUST render as normal text immediately after the mention

#### Scenario: Mention in the middle of a sentence
- **WHEN** a message contains normal text, then a valid mention span, then more normal text
- **THEN** the text before the mention MUST remain visible
- **THEN** the mention MUST render with mention styling
- **THEN** the text after the mention MUST remain visible

#### Scenario: Mention at the end of a sentence
- **WHEN** a message ends with a valid mention span
- **THEN** the preceding normal text MUST render unchanged
- **THEN** the final mention MUST render with mention styling

#### Scenario: Multiple valid mentions render in order
- **WHEN** a message contains multiple valid, non-overlapping mention spans
- **THEN** each mention MUST render with mention styling in ascending offset order
- **THEN** all normal text between mentions MUST remain visible

### Requirement: Invalid mention ranges fail safely without corrupting the sentence
The system SHALL ignore malformed or overlapping mention ranges that cannot be rendered safely, while preserving all remaining valid text output. Bubble rendering MUST NOT drop surrounding normal text just because one mention range is invalid.

#### Scenario: Out-of-bounds mention is skipped safely
- **WHEN** a mention range points outside the message content bounds
- **THEN** the renderer MUST skip that invalid mention range
- **THEN** all normal text that can be rendered safely MUST still appear in the bubble

#### Scenario: Overlapping mentions do not break surrounding text
- **WHEN** the metadata contains overlapping mention ranges
- **THEN** the renderer MUST avoid duplicating or reordering text
- **THEN** valid text outside the overlap MUST continue to render in reading order
