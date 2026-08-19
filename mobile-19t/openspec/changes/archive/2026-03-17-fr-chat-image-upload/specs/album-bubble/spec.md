## album-bubble

Chat bubble widget for rendering single images and multi-image albums with Telegram-style mosaic grid layout.

### Requirements

1. **Single image bubble** (message type `image`)
   - Display image with preserved aspect ratio
   - Max width: 75% of screen (same as text bubble)
   - Max height: 300px
   - Show loading placeholder while image loads (shimmer or grey box)
   - Show error placeholder if image fails to load
   - Caption text below image (if present in metadata)
   - Timestamp and status indicator overlay on bottom-right of image

2. **Album bubble** (message type `album`)
   - Mosaic grid layout based on image count:
     - 1 image: full width (delegates to single image layout)
     - 2 images: side by side, equal width, 2px gap
     - 3 images: 1 large left (2/3 width) + 2 stacked right (1/3 width), 2px gap
     - 4 images: 2×2 grid, 2px gap
     - 5+ images: 2×2 grid, 4th position shows "+N" overlay with remaining count
   - All images have rounded corners matching bubble shape
   - Caption below grid (if present)
   - Timestamp and status on bottom-right

3. **Upload progress state**
   - During upload: show circular progress indicator overlay on each image
   - Use local file path for display (optimistic UI) before upload completes
   - After upload: switch to network URL via `cached_network_image`

4. **Tap interaction**
   - Tap any image → open full-screen viewer (handled by `image-preview` capability)
   - Pass image index and full image list to viewer

5. **Bubble styling**
   - Same border radius pattern as text bubbles (first/last in group)
   - Same alignment (mine=right, theirs=left)
   - Same sender name/avatar for group chats
   - Clip images to bubble border radius

### Metadata Schema

```json
// type: "image"
{
  "url": "/uploads/chat/abc.jpg",
  "size": 2048576,
  "mimeType": "image/jpeg"
}

// type: "album"
{
  "images": [
    { "url": "/uploads/chat/abc.jpg", "size": 2048576, "mimeType": "image/jpeg" },
    { "url": "/uploads/chat/def.png", "size": 1024000, "mimeType": "image/png" }
  ]
}
```

### Integration Points

- `MessageBubble` widget — add type branching for `image` and `album`
- `cached_network_image` package — efficient image loading with disk cache
- `ChatNotifier` — pass local file paths during upload for optimistic display

### Acceptance Criteria

- Single image renders with correct aspect ratio, max height 300
- 2 images render side by side
- 3 images render in L-shape layout
- 4 images render in 2×2 grid
- 7 images render as 2×2 grid with "+3" overlay on 4th
- Caption displays below image grid
- Timestamp/status overlay visible on images
- Loading placeholder shown while image loads
- Tap on image opens full-screen viewer
