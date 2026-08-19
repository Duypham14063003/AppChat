## Context

Image messaging is complete — `POST /chat/upload` endpoint, album bubbles, offline media queue all working. `MessageType.VOICE = 'voice'` is declared in the API enum but not handled. No audio packages exist in Flutter. The upload controller only accepts `image/*` MIME types.

This change implements CHAT-FR-008 (Voice Message, P1 SHOULD). It reuses the upload infrastructure from the image change and adds recording + playback capabilities on the Flutter side.

Key constraints: AAC format (.m4a), hold-to-record UX, client-side waveform, local disk storage (no Bunny.net yet).

## Goals / Non-Goals

**Goals:**
- Hold-to-record mic button with live waveform visualization
- AAC (.m4a) recording via `record` package
- Voice bubble with waveform bars, play/pause, duration, progress
- Audio playback via `just_audio` package
- Upload voice file via existing `POST /chat/upload` endpoint
- Offline support via existing `PendingUploads` table
- Client-side waveform generation from amplitude samples

**Non-Goals:**
- Bunny.net CDN integration (later phase)
- Server-side waveform extraction (ffmpeg)
- Voice-to-text transcription
- Audio compression/format conversion
- Background audio recording
- Voice message editing/trimming before send

## Decisions

### D1: Recording package — `record`
**Choice**: Use `record` package for audio recording.
**Rationale**: Lightweight, simple API, supports AAC output natively on both iOS and Android. Provides `onAmplitudeChanged` stream for real-time waveform data. No native code complexity like `flutter_sound`. `audio_waveforms` was considered but is heavier and bundles its own recording + playback — we prefer separate packages for each concern.

### D2: Playback package — `just_audio`
**Choice**: Use `just_audio` for audio playback.
**Rationale**: Well-maintained, supports streaming from URL, provides position/duration streams for progress tracking. Lighter than `audioplayers`. Works on iOS, Android, web, macOS, Windows.

### D3: Audio format — AAC (.m4a)
**Choice**: Record in AAC format, output as `.m4a` file.
**Rationale**: Native hardware encoder support on both iOS and Android — no transcoding needed. Good quality at reasonable bitrate (128kbps). Universal playback support across all platforms. Opus would offer better compression but has inconsistent iOS support.
**Encoding config**: AAC-LC, 128kbps, 44.1kHz, mono.

### D4: UX pattern — hold-to-record (Telegram-style)
**Choice**: User holds mic button to record, releases to send. Swipe left to cancel.
**Rationale**: Matches SRS requirement. Fastest UX for short voice messages. Telegram users (common in Vietnam) are familiar with this pattern. Recording starts immediately on press — no extra tap to begin.
**States**:
- Idle: mic icon visible (replaces send button when text field is empty)
- Recording: waveform bars + duration timer + "slide to cancel" hint
- Cancelling: swipe left past threshold → red cancel indicator → release to discard
- Sending: release finger → stop recording → upload → send

### D5: Waveform data — client-side amplitude sampling
**Choice**: Collect amplitude samples from `record`'s `onAmplitudeChanged` stream during recording. Normalize to `List<double>` (0.0-1.0). Store in message metadata as `waveform` array. Render as vertical bars in voice bubble.
**Rationale**: No server processing needed. Waveform is available immediately for optimistic UI. Consistent across platforms since it's generated during recording. Sample rate: ~100ms intervals, yielding ~10 samples/second. A 60-second recording = ~600 doubles — negligible metadata size.
**Normalization**: `record` returns amplitude in dBFS (negative values, -160 to 0). Normalize: `normalized = (amplitude + 160) / 160`, clamped to 0.0-1.0.

### D6: Voice bubble layout
**Choice**: Custom `VoiceBubble` widget with:
- Play/pause circle button (left)
- Waveform bars (center) — colored bars showing waveform shape, progress overlay
- Duration label (right) — shows total duration, switches to current position during playback
**Rationale**: Standard voice message UX (Telegram/WhatsApp). Waveform bars give visual identity to each message. Progress shown by coloring played portion of waveform differently.

### D7: Mic button placement — replace send button when empty
**Choice**: When text field is empty, show mic button instead of send button. When text is entered, show send button. Same position, animated transition.
**Rationale**: Telegram pattern. Saves horizontal space. Clear affordance — empty field = voice, text = send. No need for a separate mic button competing for space.

### D8: Offline voice queue — reuse PendingUploads
**Choice**: Reuse existing `PendingUploads` table from image upload change. Voice file cached to app cache directory, path stored in `localPaths` JSON array (single element). Same retry logic (max 5 retries).
**Rationale**: Infrastructure already exists and works. No schema changes needed. `OfflineQueueService` already processes pending uploads on reconnect — voice files are just another file type.

### D9: Audio playback management — single player instance
**Choice**: Use a single `AudioPlayer` instance managed by a Riverpod provider. When user taps play on a different voice message, the current one stops and the new one starts.
**Rationale**: Prevents multiple audio streams playing simultaneously. Saves memory. Standard behavior in all messaging apps. Provider makes it easy to track "currently playing message ID" for UI state.

## Risks / Trade-offs

- **[No waveform on received messages before playback]** → Waveform data is stored in metadata, so it's available immediately. No risk here.
- **[Large voice files on mobile data]** → AAC at 128kbps = ~1MB/minute. Acceptable for messages up to 5 minutes. No compression optimization needed for <50 users.
- **[Microphone permission]** → First recording attempt will trigger OS permission dialog. If denied, show snackbar explaining why permission is needed. No pre-emptive permission request.
- **[Background noise]** → No noise cancellation. Acceptable for internal app. Can add later if needed.
- **[Platform differences]** → `record` package handles platform-specific recording APIs. AAC is natively supported on both iOS and Android. Web support may need testing.

## Open Questions

- None — all decisions made during exploration phase.
