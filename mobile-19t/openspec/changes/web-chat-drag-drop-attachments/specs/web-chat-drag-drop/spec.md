## ADDED Requirements

### Requirement: Web chat composer accepts supported drag-and-drop attachments
The system SHALL provide a web-only drag-and-drop target for the chat composer area so users can drop supported attachments directly into an open conversation. Dropped payloads MUST be classified into the same high-level attachment routes already used by the composer: image batch, single video, or single validated document.

#### Scenario: Dropping multiple images opens the existing image flow
- **WHEN** a web user drops one or more supported image files onto the chat drop target
- **THEN** the composer MUST route those files through the existing image attachment flow
- **THEN** the user MUST see the normal image preview/send experience before upload

#### Scenario: Dropping a single video opens the existing video flow
- **WHEN** a web user drops one supported video file onto the chat drop target
- **THEN** the composer MUST route that file through the existing video preview flow

#### Scenario: Dropping a validated document uses the existing file flow
- **WHEN** a web user drops one supported document file onto the chat drop target
- **THEN** the composer MUST route that file through the existing document attachment flow

### Requirement: Web drag state provides clear acceptance and rejection feedback
The system SHALL show explicit drag-state feedback while supported files are being dragged over the web chat composer. The drop target MUST visually distinguish idle, active, and rejected states so users know whether the drop will be accepted.

#### Scenario: Supported files highlight the drop target
- **WHEN** a supported drag payload enters the web chat composer drop zone
- **THEN** the composer MUST display a visible drop-target highlight and ready-to-drop message

#### Scenario: Unsupported files show rejection feedback
- **WHEN** an unsupported drag payload enters the web chat composer drop zone
- **THEN** the composer MUST display rejection feedback instead of the normal ready state

#### Scenario: Drag state clears after exit or completed drop
- **WHEN** the user drags away from the drop target or completes a drop
- **THEN** the temporary drag-state UI MUST clear and the composer MUST return to its normal state

### Requirement: Mixed dropped payloads fail safely
The system SHALL reject dropped payloads that combine incompatible attachment classes in a single action. The composer MUST NOT partially attach a mixed payload set.

#### Scenario: Image and document dropped together are rejected
- **WHEN** a user drops a payload containing both image files and document files
- **THEN** the composer MUST reject the drop as a mixed payload
- **THEN** no attachment preview or upload flow MUST start automatically

#### Scenario: Multiple dissimilar non-image files are rejected
- **WHEN** a user drops multiple non-image files that do not map to a single supported attachment flow
- **THEN** the composer MUST reject the drop instead of guessing how to send them
