## voice-playback

VoiceBubble widget with waveform visualization, play/pause control, duration display, and progress tracking via `just_audio`.

### Requirements

1. **Packages**
   - Add `just_audio: ^0.9.x` to `pubspec.yaml`
   - Run `flutter pub get`

2. **AudioPlayerProvider (Riverpod)**
   - Create a `audioPlayerProvider` — singleton `AudioPlayer` instance
   - Create a `currentlyPlayingMessageProvider` — `StateProvider<String?>` tracking message ID currently playing
   - When a new message starts playing: stop current, update provider, start new
   - When playback completes: clear provider, reset position to 0
   - Dispose player on provider disposal

3. **VoiceBubble widget** (`lib/features/chat/widgets/voice_bubble.dart`)
   - Accept: `message` (LocalMessage), `isMine` (bool)
   - Layout (horizontal row):
     - Left: play/pause circle button (40x40)
       - Play icon when idle/paused
       - Pause icon when playing this message
       - Loading indicator when buffering
     - Center: waveform bars
       - Parse `waveform` array from message metadata
       - Render as vertical bars (2px wide, 2px gap, height 4-28px based on value)
       - Played portion: theme primary color (gold for mine, accent for theirs)
       - Unplayed portion: muted color (grey)
       - Progress position calculated from `just_audio` position stream / total duration
     - Right: duration label
       - When idle: show total duration (MM:SS) from metadata
       - When playing: show current position (MM:SS)
   - Bubble background: same as text bubble (mine = dark, theirs = light)
   - Timestamp + status overlay: bottom-right, same as other message types

4. **Playback flow**
   - Tap play → `audioPlayer.setUrl(metadata.url)` → `audioPlayer.play()`
   - Update `currentlyPlayingMessageProvider` with message ID
   - Stream `audioPlayer.positionStream` for progress updates
   - Tap pause → `audioPlayer.pause()`
   - Playback complete → reset to beginning, show play icon, show total duration

5. **Waveform rendering**
   - If waveform data exists in metadata: render bars from data
   - If no waveform data (edge case — old messages): render flat bars as placeholder
   - Number of bars: fit available width (container width / 4px per bar)
   - Resample waveform array to match number of bars using linear interpolation

6. **MessageBubble integration**
   - In `MessageBubble._buildBubble()`: add case for `message.type == 'voice'`
   - Render `VoiceBubble` widget
   - Keep existing text/image/album/system handling

7. **ConversationTile integration**
   - If last message type is `voice`: show "🎤 Tin nhắn thoại" in conversation list

### Integration Points

- `MessageBubble` — route voice type to VoiceBubble
- `just_audio` — audio playback and position streaming
- `ChatProviders` — new audio player and currently-playing providers
- `ConversationTile` — voice message preview text

### Acceptance Criteria

- Voice message shows waveform bars with play button and duration
- Tap play → audio plays, waveform progress animates, duration shows current position
- Tap pause → audio pauses, can resume
- Playback completes → resets to beginning
- Play message A, then tap play on message B → A stops, B starts
- Voice message from other user renders with correct bubble color
- Conversation list shows "🎤 Tin nhắn thoại" for voice messages
