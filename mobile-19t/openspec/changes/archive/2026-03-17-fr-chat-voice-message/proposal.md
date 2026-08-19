## Why

Image messaging (CHAT-FR-006) is complete — upload endpoint, album bubbles, offline queue all working. The next media type is voice messaging (CHAT-FR-008, P1 SHOULD). Users need to send quick audio messages in conversations — faster than typing for mobile users, essential for field workers who can't type easily.

The upload infrastructure (`POST /chat/upload`, `PendingUploads` table, `OfflineQueueService`) already exists from the image upload change. `MessageType.VOICE` is already declared in the API enum but not handled anywhere. No audio recording or playback packages exist in the Flutter app.

## What Changes

Frontend (Flutter):
- Add `record` package for audio recording (AAC/M4A output)
- Add `just_audio` package for audio playback
- Implement hold-to-record mic button in `MessageInputBar` — hold to record, release to send, swipe left to cancel
- Show live waveform visualization during recording using `record`'s amplitude stream
- Create `VoiceBubble` widget: waveform bars, play/pause button, duration, progress indicator
- Send voice message flow: record → upload → WS send with type "voice" and metadata `{url, duration, waveform, size, mimeType}`
- Offline support: reuse existing `PendingUploads` table and `OfflineQueueService`

Backend (NestJS):
- Extend upload controller MIME whitelist to accept `audio/aac`, `audio/mp4`, `audio/mpeg`, `audio/m4a`

## Capabilities

### New Capabilities
- `voice-recording`: Hold-to-record mic button, live waveform, cancel gesture, AAC recording via `record` package
- `voice-playback`: VoiceBubble widget with waveform visualization, play/pause, duration, progress via `just_audio`
- `voice-upload`: Extend upload endpoint for audio MIME types, voice message send flow, offline queue reuse

### Modified Capabilities
- `chat-messaging`: Extend `sendMessage` to handle `voice` message type with metadata
- `flutter-chat-ui`: Update `MessageInputBar` with mic button, update `MessageBubble` for voice rendering

## Impact

- **Database**: No schema changes — existing `type` and `metadata` columns sufficient. `PendingUploads` table reused as-is.
- **API endpoints**: No new endpoints — extend existing `POST /chat/upload` MIME whitelist
- **Packages (Flutter)**: `record` (audio recording), `just_audio` (audio playback)
- **Packages (API)**: None
- **Storage**: Voice files stored on local disk alongside images in `uploads/chat/`
- **Performance**: Waveform generated client-side from amplitude samples during recording — no server processing needed
