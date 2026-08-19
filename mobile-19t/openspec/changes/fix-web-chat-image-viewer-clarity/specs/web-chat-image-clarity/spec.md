## ADDED Requirements

### Requirement: Web fullscreen chat image viewing SHALL preserve screenshot readability
The web chat client SHALL display fullscreen chat images with sufficient clarity that text-heavy screenshots and document captures remain readable when the source image itself is reasonably legible.

#### Scenario: User opens a text-heavy screenshot on web
- **WHEN** the user opens a screenshot or document-like image from chat in the web image viewer
- **THEN** the client SHALL use a web rendering path that prioritizes clarity of the image content
- **AND** the viewer SHALL avoid unnecessary degradation that makes previously readable text become blurry or broken-looking

#### Scenario: User views a non-text-heavy image on web
- **WHEN** the user opens a regular photo or illustration in the web image viewer
- **THEN** the viewer SHALL continue to display the image correctly
- **AND** the web-specific clarity fix SHALL NOT break normal image viewing behavior

### Requirement: Web image clarity fixes SHALL apply without requiring upload changes
The web chat client SHALL improve rendering clarity for chat images using the existing uploaded asset URLs and SHALL NOT require a new upload contract to make viewed screenshots sharper.

#### Scenario: Existing uploaded image is reopened on web
- **WHEN** a previously uploaded chat image is opened on web after the clarity change
- **THEN** the client SHALL attempt to render that same asset more clearly
- **AND** the fix SHALL work without re-uploading the image

### Requirement: Web preview rendering SHALL remain stable while fullscreen fidelity is improved
The web chat client SHALL preserve stable chat preview behavior while allowing targeted web-specific tuning for previews if needed.

#### Scenario: User browses image messages in chat list
- **WHEN** the chat UI renders image thumbnails or album previews on web
- **THEN** preview rendering SHALL remain functional and visually stable
- **AND** the primary readability fix SHALL remain centered on the fullscreen viewing experience
