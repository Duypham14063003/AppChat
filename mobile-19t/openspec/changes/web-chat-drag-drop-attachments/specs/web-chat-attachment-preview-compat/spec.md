## ADDED Requirements

### Requirement: Web attachment previews work for data-backed chat files
The system SHALL support previewing web chat attachments even when the underlying attachment source is backed by in-memory browser data rather than a directly reusable file path. Image and video preview flows MUST work consistently for files originating from picker selection, clipboard paste, and drag-and-drop.

#### Scenario: Data-backed image opens preview successfully
- **WHEN** a web image attachment is created from browser data and routed into the image preview flow
- **THEN** the image preview screen MUST render the image successfully before send

#### Scenario: Data-backed video opens preview successfully
- **WHEN** a web video attachment is created from browser data and routed into the video preview flow
- **THEN** the video preview screen MUST initialize and render the video successfully before send

### Requirement: Web attachment normalization is transparent to existing flows
The system SHALL normalize web attachment sources without changing the user-facing send flow for supported attachments. Existing picker- and clipboard-based attachment behavior MUST continue to work after drag-and-drop support is introduced.

#### Scenario: Existing picker-based image preview still works
- **WHEN** a user selects images through the existing web picker flow
- **THEN** the image preview and send flow MUST behave the same after attachment normalization is introduced

#### Scenario: Existing clipboard image paste still works
- **WHEN** a user pastes an image from the system clipboard into the focused web composer
- **THEN** the composer MUST continue to route that image through a working image preview/send flow

### Requirement: Rejected web attachments do not start broken preview flows
The system SHALL validate dropped files before launching preview screens. Attachments that fail validation MUST stop before preview routing begins.

#### Scenario: Unsupported document extension is rejected before preview
- **WHEN** a web user drops a file with an unsupported document extension
- **THEN** the composer MUST reject the file before any preview or upload flow starts

#### Scenario: Invalid drag payload leaves current draft intact
- **WHEN** a web user drops an invalid or unsupported payload onto the composer
- **THEN** the current draft text, mention state, and reply/edit composer state MUST remain unchanged
