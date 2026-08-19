## voice-recording

Hold-to-record mic button in MessageInputBar with live waveform visualization, cancel gesture, and AAC recording via `record` package.

### Requirements

1. **Packages**
   - Add `record: ^5.x` to `pubspec.yaml`
   - Run `flutter pub get`

2. **Mic button in MessageInputBar**
   - When text field is empty: show mic icon button (replacing send button)
   - When text field has content: show send button (existing behavior)
   - Animated transition between mic and send icons (scale/fade)

3. **Hold-to-record gesture**
   - `GestureDetector` wrapping mic button with `onLongPressStart`, `onLongPressMoveUpdate`, `onLongPressEnd`
   - On long press start:
     - Check microphone permission via `record` package (`hasPermission()`)
     - If no permission: request permission. If denied, show snackbar "Cần quyền truy cập microphone để ghi âm"
     - If granted: start recording to temp file in app cache dir (`getTemporaryDirectory()/voice_{uuid}.m4a`)
     - Recording config: `AudioEncoder.aacLc`, `bitRate: 128000`, `sampleRate: 44100`, `numChannels: 1`
     - Subscribe to `onAmplitudeChanged(const Duration(milliseconds: 100))` for waveform data
     - Show recording UI overlay
   - On long press move update:
     - Track horizontal drag distance
     - If dragged left > 100px: show cancel indicator (red, "Thả để hủy")
   - On long press end:
     - If in cancel zone: discard recording, delete temp file
     - If not cancelled: stop recording, trigger send flow

4. **Recording UI state**
   - Replace message input area with recording overlay:
     - Left: red recording dot (pulsing animation) + duration timer (MM:SS)
     - Center: live waveform bars (animated, based on amplitude stream)
     - Right: "< Trượt để hủy" hint text
   - Duration timer: starts at 0:00, increments every second
   - Max recording duration: 5 minutes. Auto-stop and send at 5:00.

5. **Live waveform during recording**
   - Collect amplitude values from `onAmplitudeChanged` stream
   - Normalize dBFS to 0.0-1.0: `(amplitude.current + 160) / 160`, clamped
   - Display as animated vertical bars (last ~30 bars visible, scrolling left)
   - Bar height proportional to normalized amplitude
   - Bar color: theme primary color (gold)

6. **Waveform data for metadata**
   - Collect all normalized amplitude samples during recording into `List<double>`
   - Downsample to max 100 points for storage (evenly spaced selection)
   - Pass waveform data to send flow for inclusion in message metadata

### Integration Points

- `MessageInputBar` — add mic button, recording state, gesture handling
- `record` package — audio recording and amplitude stream
- `ChatScreen` — receive recorded file path + duration + waveform, trigger send

### Acceptance Criteria

- Empty text field shows mic button; typing switches to send button
- Hold mic → recording starts, live waveform and timer shown
- Release mic → recording stops, voice message sent
- Swipe left while holding → "Thả để hủy" shown, release discards recording
- Microphone permission denied → snackbar shown, no crash
- Recording reaches 5 minutes → auto-stops and sends
