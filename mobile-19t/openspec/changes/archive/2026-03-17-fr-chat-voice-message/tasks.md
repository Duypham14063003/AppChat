## 1. API: Extend Upload MIME Whitelist

- [x] 1.1 In `apps/api/src/modules/chat/upload.controller.ts`, add audio MIME types to `ALLOWED_MIME_TYPES` array:
  - `audio/aac`, `audio/mp4`, `audio/mpeg`, `audio/x-m4a`, `audio/m4a`
- [x] 1.2 Update `@ApiOperation` summary to "Upload media files for chat messages" (was "Upload images")
- [ ] 1.3 Verify: upload a `.m4a` file via `POST /chat/upload` → succeeds, returns URL
- [ ] 1.4 Verify: upload a `.txt` file → rejected with 400

## 2. Flutter: Add Audio Packages

- [x] 2.1 Add `record: ^5.1.3` to `pubspec.yaml`
- [x] 2.2 Add `just_audio: ^0.9.42` to `pubspec.yaml`
- [x] 2.3 Run `flutter pub get` to verify all packages resolve
- [x] 2.4 Add microphone permission to Android `AndroidManifest.xml`: `<uses-permission android:name="android.permission.RECORD_AUDIO"/>`
- [x] 2.5 Add microphone permission to iOS `Info.plist`: `NSMicrophoneUsageDescription` key with value "Cần quyền microphone để ghi tin nhắn thoại"

## 3. Flutter: Audio Player Provider

- [x] 3.1 Create audio player providers in `lib/features/chat/providers/chat_providers.dart`:
  - `audioPlayerProvider` — `Provider<AudioPlayer>` singleton instance from `just_audio`
  - `currentlyPlayingMessageProvider` — `StateProvider<String?>` tracking currently playing message ID
- [x] 3.2 Add dispose logic: when provider is disposed, call `audioPlayer.dispose()`

## 4. Flutter: VoiceBubble Widget

- [x] 4.1 Create `VoiceBubble` widget at `lib/features/chat/widgets/voice_bubble.dart`:
  - Accept `LocalMessage message`, `bool isMine`
  - Parse metadata JSON for `waveform` (List<double>), `duration` (double), `url` (String), `localPath` (String?)
  - Layout as horizontal Row:
    - Left: play/pause `IconButton` (40x40 circle) — play icon when idle, pause when playing, loading when buffering
    - Center: waveform bars — `CustomPainter` rendering vertical bars (2px wide, 2px gap)
      - Played portion in primary color, unplayed in grey
      - Progress from `audioPlayer.positionStream` / total duration
    - Right: duration label (MM:SS) — total when idle, current position when playing
  - Watch `currentlyPlayingMessageProvider` to determine if this message is playing
  - On play tap: set URL (from metadata `url` or `localPath`), play, update `currentlyPlayingMessageProvider`
  - On pause tap: pause audio
  - On playback complete: reset position, clear `currentlyPlayingMessageProvider`
- [x] 4.2 Handle pending state: if message status is `pending`, show waveform from metadata but disable play button (file not yet uploaded)

## 5. Flutter: MessageBubble — Voice Type Routing

- [x] 5.1 In `MessageBubble._buildBubble()` (`lib/features/chat/widgets/message_bubble.dart`):
  - Add case for `message.type == 'voice'`: render `VoiceBubble(message: message, isMine: isMine)`
  - Import `voice_bubble.dart`
- [x] 5.2 Note: `VoiceBubble` needs `ProviderScope` access — ensure it's a `ConsumerWidget` or uses `Consumer` internally

## 6. Flutter: MessageInputBar — Mic Button & Recording

- [x] 6.1 Add `onVoiceRecorded` callback to `MessageInputBar`:
  - `void Function(String path, double duration, List<double> waveform)?`
- [x] 6.2 Add recording state variables to `_MessageInputBarState`:
  - `bool _isRecording = false`
  - `Duration _recordingDuration = Duration.zero`
  - `List<double> _waveformSamples = []`
  - `double _cancelDragOffset = 0`
  - `bool _isCancelZone = false`
  - `Timer? _durationTimer`
  - `AudioRecorder? _recorder`
- [x] 6.3 Implement mic/send button toggle:
  - When `_hasText == false` and `_isRecording == false`: show mic icon button
  - When `_hasText == true`: show send button (existing)
  - When `_isRecording == true`: show recording UI (see 6.5)
  - Animated transition (AnimatedSwitcher)
- [x] 6.4 Implement hold-to-record gesture on mic button:
  - `GestureDetector` with `onLongPressStart`:
    - Check permission: `AudioRecorder().hasPermission()`
    - If denied: show snackbar "Cần quyền truy cập microphone để ghi âm", return
    - Start recording: `recorder.start(RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100, numChannels: 1), path: tempPath)`
    - Subscribe to `recorder.onAmplitudeChanged(Duration(milliseconds: 100))` → normalize and add to `_waveformSamples`
    - Start duration timer (increment every second)
    - Set `_isRecording = true`
  - `onLongPressMoveUpdate`:
    - Track `details.localOffsetFromOrigin.dx`
    - If dx < -100: set `_isCancelZone = true`
    - Else: set `_isCancelZone = false`
  - `onLongPressEnd`:
    - Stop recording: `recorder.stop()`
    - If `_isCancelZone`: delete temp file, reset state
    - If not cancelled and duration > 0.5s: call `widget.onVoiceRecorded(path, duration, downsampledWaveform)`
    - If duration < 0.5s: delete temp file (too short), show snackbar "Giữ lâu hơn để ghi âm"
    - Reset all recording state
  - Max duration: 5 minutes → auto-stop and send
- [x] 6.5 Recording UI overlay (replaces input area when `_isRecording`):
  - Left: pulsing red dot + duration timer (MM:SS)
  - Center: live waveform bars (last ~30 samples, animated)
  - Right: "< Trượt để hủy" text (changes to red "Thả để hủy" when in cancel zone)
- [x] 6.6 Waveform downsampling helper:
  - Take `_waveformSamples` list, downsample to max 100 points (evenly spaced)
  - Normalize dBFS: `(amplitude + 160) / 160`, clamped 0.0-1.0

## 7. Flutter: ChatRepository — Upload Voice

- [x] 7.1 Add `uploadVoice(String filePath)` method to `ChatRepository` (`lib/features/chat/data/chat_repository.dart`):
  - Create `FormData` with single `MultipartFile.fromFile(filePath, field: 'files')`
  - POST to `/chat/upload`
  - Return `{url, originalName, size, mimeType}` from response
  - Same error handling pattern as `uploadImages`

## 8. Flutter: ChatNotifier — Send Voice Message

- [x] 8.1 Add `sendVoiceMessage(String convId, String filePath, double duration, List<double> waveform)` to `ChatMessagesNotifier`:
  - Generate message UUID
  - Build metadata: `{localPath: filePath, duration, waveform, size, mimeType: 'audio/aac'}`
  - Insert optimistic message to Drift: `type: 'voice'`, `status: 'pending'`
  - If online: upload via `chatRepository.uploadVoice()` → build final metadata with `url` (remove `localPath`) → send WS `send_message` → update local message
  - If offline: copy file to app cache, insert `PendingUploads` record
  - On failure: update message status to `failed`
- [x] 8.2 Wire in `ChatScreen`: add `onVoiceRecorded` handler to `MessageInputBar` → call `chatNotifier.sendVoiceMessage()`

## 9. Flutter: ConversationTile — Voice Preview

- [x] 9.1 In `ConversationTile` (`lib/features/chat/widgets/conversation_tile.dart`):
  - If last message type is `voice`: show "🎤 Tin nhắn thoại" instead of text content

## 10. Integration & Verification

- [ ] 10.1 Verify: hold mic → recording starts, live waveform shown, timer counting
- [ ] 10.2 Verify: release mic → voice message sent, bubble shows waveform + play button
- [ ] 10.3 Verify: tap play → audio plays, waveform progress animates
- [ ] 10.4 Verify: swipe left while recording → recording cancelled
- [ ] 10.5 Verify: send voice while offline → optimistic bubble, upload on reconnect
- [ ] 10.6 Verify: recipient receives voice message in real-time
- [ ] 10.7 Verify: conversation list shows "🎤 Tin nhắn thoại"
- [ ] 10.8 Run `flutter analyze` in apps/mobile — no errors
- [ ] 10.9 Run `npm run lint && npm run build` in apps/api — no errors
