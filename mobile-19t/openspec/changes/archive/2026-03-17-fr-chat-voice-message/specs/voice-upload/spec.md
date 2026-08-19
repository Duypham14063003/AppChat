## voice-upload

Extend upload endpoint for audio MIME types, voice message send flow in ChatNotifier, and offline queue reuse.

### Requirements

1. **API: Extend upload MIME whitelist**
   - In `upload.controller.ts`, add to allowed MIME types:
     - `audio/aac`
     - `audio/mp4`
     - `audio/mpeg`
     - `audio/x-m4a`
     - `audio/m4a`
   - Keep existing image MIME types
   - No other changes to upload endpoint — same validation, same storage, same response format

2. **Flutter: ChatRepository — uploadVoice method**
   - Add `uploadVoice(String filePath)` method to `ChatRepository`
   - Create `FormData` with single `MultipartFile` entry (field name `files`)
   - POST to `/chat/upload`
   - Return uploaded file metadata `{url, originalName, size, mimeType}`
   - Reuse same `onSendProgress` callback pattern as `uploadImages`

3. **Flutter: ChatNotifier — sendVoiceMessage**
   - Add `sendVoiceMessage(String convId, String filePath, double duration, List<double> waveform)` method
   - Generate message UUID
   - Build metadata: `{localPath, duration, waveform, size, mimeType}` (for optimistic UI)
   - Insert optimistic message to Drift: `type: 'voice'`, `status: 'pending'`, metadata with local path
   - If online:
     - Upload via `ChatRepository.uploadVoice(filePath)`
     - On success: build final metadata `{url, duration, waveform, size, mimeType}`, send WS `send_message` event with `type: 'voice'`, update local message
     - On failure: update message status to `failed`
   - If offline:
     - Copy voice file to app cache dir
     - Insert `PendingUploads` record with local path
     - `OfflineQueueService` handles upload on reconnect (existing logic)

4. **Voice message metadata schema**
   ```json
   {
     "url": "/uploads/chat/uuid-timestamp.m4a",
     "duration": 12.5,
     "waveform": [0.1, 0.3, 0.8, 0.5, ...],
     "size": 198000,
     "mimeType": "audio/aac",
     "localPath": "/cache/voice_uuid.m4a"
   }
   ```
   - `localPath` only present during pending/upload state, removed after successful upload
   - `waveform` is array of 50-100 normalized doubles (0.0-1.0)

5. **Wire in ChatScreen**
   - `MessageInputBar.onVoiceRecorded` callback: `void Function(String path, double duration, List<double> waveform)`
   - `ChatScreen` receives callback → calls `chatNotifier.sendVoiceMessage()`

### Integration Points

- `upload.controller.ts` — extend MIME whitelist
- `ChatRepository` — new `uploadVoice` method
- `ChatNotifier` — new `sendVoiceMessage` method
- `ChatScreen` — wire voice recording callback to send flow
- `OfflineQueueService` — reuse existing pending upload processing (no changes needed)
- `PendingUploads` table — reuse as-is

### Acceptance Criteria

- Upload .m4a file via `POST /chat/upload` → succeeds, returns URL
- Upload .mp3 file → succeeds (audio/mpeg in whitelist)
- Upload .exe file → rejected (not in whitelist)
- Send voice message online → optimistic bubble shown, upload completes, WS message sent
- Send voice message offline → cached locally, uploaded on reconnect
- Recipient receives voice message with waveform and duration in metadata
- Failed upload after 5 retries → message shows "Gửi thất bại" with retry button
