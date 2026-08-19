## media-upload

Backend capability for handling image file uploads via REST API with local disk storage.

### Requirements

1. **Upload endpoint** `POST /chat/upload`
   - Accept multipart/form-data with field name `files`
   - Max 10 files per request
   - Max 20MB per file
   - Allowed MIME types: `image/jpeg`, `image/png`, `image/webp`, `image/gif`
   - Return array of uploaded file metadata

2. **File storage**
   - Save to `uploads/chat/` directory relative to project root
   - File naming: `{uuid}-{timestamp}.{ext}` (e.g., `a1b2c3d4-1710600000.jpg`)
   - Create directory if not exists on module init

3. **Static file serving**
   - Serve `uploads/` directory at `/uploads/` URL path via `ServeStaticModule`
   - URL format: `{API_BASE_URL}/uploads/chat/{filename}`

4. **Response format**
   ```json
   {
     "files": [
       {
         "url": "/uploads/chat/a1b2c3d4-1710600000.jpg",
         "originalName": "photo.jpg",
         "size": 2048576,
         "mimeType": "image/jpeg"
       }
     ]
   }
   ```

5. **Authentication**: JWT guard required (reuse existing `JwtAuthGuard`)

6. **Rate limiting**: Reuse existing Redis rate limiter — 10 file uploads/min/user (per CHAT-FR-035)

### Integration Points

- `ChatModule` — add upload controller
- `JwtAuthGuard` — protect upload endpoint
- `app.module.ts` — register `ServeStaticModule` for static file serving
- `MessageType` enum — add `ALBUM` type for multi-image messages

### Acceptance Criteria

- Upload 1 image → returns URL, file exists on disk, accessible via GET
- Upload 10 images → all succeed, all URLs returned
- Upload 11 images → rejected with 400 error
- Upload 25MB file → rejected with 413 error
- Upload non-image file → rejected with 400 error
- Upload without auth → rejected with 401 error
