## offline-media-queue

Offline support for image messages: cache selected images locally, queue uploads, retry on reconnect.

### Requirements

1. **Drift table: `PendingUploads`**
   - `id` — text, primary key (UUID)
   - `convId` — text (conversation ID)
   - `localPaths` — text (JSON array of local file paths in app cache)
   - `caption` — text, nullable
   - `status` — text, default `'queued'` (queued / uploading / uploaded / failed)
   - `retryCount` — integer, default 0
   - `createdAt` — dateTime

2. **Cache flow** (when sending images while offline)
   - Copy selected image files to app cache directory (`getApplicationCacheDirectory()/chat_uploads/`)
   - Insert `PendingUploads` record with local paths
   - Create optimistic message in `LocalMessages` with `type: 'album'` or `type: 'image'`, `status: 'pending'`, and metadata containing local file paths
   - Display images from local cache in chat bubble

3. **Upload flow** (when connectivity restored)
   - `OfflineQueueService` checks for pending uploads on WS reconnect
   - Process pending uploads sequentially (one at a time to avoid overwhelming)
   - For each: upload files via `POST /chat/upload` → send WS message with URLs → update local message metadata with server URLs → delete cached files → delete `PendingUploads` record
   - On upload failure: increment `retryCount`, set status to `queued` for retry
   - After 5 failed retries: set status to `failed`, update message status to `failed`

4. **Retry UI**
   - Failed image messages show "Gửi thất bại" label and retry button (same as text messages)
   - Tap retry → reset retry count, re-queue upload

5. **Cleanup**
   - On successful upload: delete cached files from app cache
   - On app start: clean up orphaned cache files (pending_uploads records with no matching message)

### Integration Points

- `OfflineQueueService` — extend existing service to handle media uploads
- `ChatNotifier` — detect offline state, trigger cache flow instead of upload
- `WebSocketManager` — trigger pending upload processing on reconnect
- `AppDatabase` — add `PendingUploads` table, run `build_runner` after

### Acceptance Criteria

- Send image while offline → image appears in chat from local cache with pending status
- Reconnect → image automatically uploaded and message updated with server URL
- Upload fails 5 times → message shows "Gửi thất bại" with retry button
- Tap retry → upload retried successfully
- After successful upload → cached files deleted from device
- App restart while offline → pending uploads still queued and processed on reconnect
