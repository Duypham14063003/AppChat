## ADDED Requirements

### Requirement: Intercept paste event in MessageInputBar
The system SHALL intercept Ctrl+V (Windows/Linux/Web) and Cmd+V (macOS) keyboard shortcuts in the `MessageInputBar` TextField. When intercepted, the system SHALL check the clipboard for image data before allowing the default text paste behavior.

#### Scenario: Paste shortcut detected
- **WHEN** the user presses Ctrl+V while the MessageInputBar TextField is focused
- **THEN** the system checks the clipboard for image content before processing

### Requirement: Detect image in clipboard
The system SHALL use `super_clipboard` to read the clipboard contents and detect if image data is present. Supported image formats SHALL include PNG, JPEG, GIF, BMP, and WebP. If the clipboard contains image data, the system SHALL consume the paste event and trigger the image send flow. If the clipboard contains only text (no image), the system SHALL allow the default text paste behavior.

#### Scenario: Clipboard has image
- **WHEN** the user pastes and the clipboard contains a PNG screenshot
- **THEN** the system reads the image bytes and triggers the image send flow

#### Scenario: Clipboard has only text
- **WHEN** the user pastes and the clipboard contains only text "Hello world"
- **THEN** the text is pasted into the TextField normally (default behavior)

#### Scenario: Clipboard has both text and image
- **WHEN** the user pastes and the clipboard contains both text and image data
- **THEN** the system prioritizes the image and triggers the image send flow

#### Scenario: Clipboard is empty
- **WHEN** the user pastes and the clipboard is empty
- **THEN** nothing happens (default behavior)

### Requirement: Convert clipboard image to XFile
The system SHALL convert clipboard image bytes to an `XFile` instance. On native platforms (Windows, macOS, Android, iOS), the system SHALL write the bytes to a temporary file and create `XFile` from the file path. On web, the system SHALL use `XFile.fromData()` with the image bytes. The filename SHALL be generated as `clipboard_paste_{timestamp}.png`.

#### Scenario: Native platform conversion
- **WHEN** clipboard image bytes are read on Windows
- **THEN** bytes are written to a temp file and an XFile is created from the temp path

#### Scenario: Web platform conversion
- **WHEN** clipboard image bytes are read on Web
- **THEN** an XFile is created from bytes using XFile.fromData()

### Requirement: Feed clipboard image into existing send flow
The system SHALL pass the clipboard image `XFile` to the existing `onAttachImages` callback as a single-element list `[xFile]`. This triggers the existing flow: `ImagePreviewScreen` → confirm → `sendImageMessage()` → upload → WS send. No changes to the downstream pipeline.

#### Scenario: Full paste-to-send flow
- **WHEN** the user pastes a screenshot from clipboard
- **THEN** the ImagePreviewScreen opens with the pasted image, the user can add a caption and confirm, and the image is uploaded and sent as a chat message

#### Scenario: User cancels after paste
- **WHEN** the user pastes an image and the ImagePreviewScreen opens, but the user presses back
- **THEN** no image is sent and the user returns to the chat screen

### Requirement: Cross-platform support
The system SHALL support clipboard image paste on Web, Windows, macOS, Android, and iOS. The primary target platforms are Web and desktop (Windows/macOS) where paste is most commonly used. Mobile platforms (Android/iOS) SHALL be supported but are secondary use cases.

#### Scenario: Paste works on Web
- **WHEN** the user pastes an image in the web app (Chrome)
- **THEN** the image is detected and the send flow is triggered

#### Scenario: Paste works on Windows
- **WHEN** the user pastes a screenshot on Windows desktop
- **THEN** the image is detected and the send flow is triggered

#### Scenario: Paste works on macOS
- **WHEN** the user pastes an image on macOS
- **THEN** the image is detected and the send flow is triggered

