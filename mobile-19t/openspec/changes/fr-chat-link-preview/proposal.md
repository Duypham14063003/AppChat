## Why

Text messaging (CHAT-FR-001) is complete and working well. Users frequently share URLs in conversations — articles, GitHub repos, documentation, etc. Currently, URLs appear as plain text with no visual context. Users must click the link to see what it's about, which creates friction and uncertainty.

Link preview (CHAT-FR-027, P2 COULD) enhances the messaging experience by automatically fetching and displaying Open Graph metadata for URLs. This provides visual context (image, title, description) before clicking, making conversations richer and more informative.

The feature follows Telegram's UX pattern: detect URL while typing, fetch preview before sending, show preview card below input field, allow user to remove preview, and include preview in sent message.

## What Changes

Frontend (Flutter):
- Add URL detection in `MessageInputBar` — regex pattern to find first URL in text
- Add debounced preview fetching (500ms delay after typing stops)
- Create `LinkPreviewCard` widget for input area — compact horizontal layout with remove button
- Create `LinkPreviewBubble` widget for message bubbles — full-width vertical layout with image
- Update `MessageInputBar` to show preview card below text field
- Update `MessageBubble` to render link preview from metadata
- Call new backend endpoint `POST /chat/link-preview` to fetch metadata
- Include preview data in message metadata when sending

Backend (NestJS):
- Create `POST /chat/link-preview` endpoint accepting URL
- Add `open-graph-scraper` package for metadata extraction
- Implement URL validation (format, no private IPs, no localhost)
- Fetch URL with 5-second timeout and 5MB max size
- Parse Open Graph tags (og:title, og:description, og:image, og:url)
- Fallback to Twitter Card tags and HTML meta tags
- Cache preview data in Redis (24h TTL) to avoid repeated fetches
- Rate limit: 10 requests per minute per user

## Capabilities

### New Capabilities
- `link-detection`: URL detection in text input using regex, extract first URL only
- `link-preview-fetch`: Backend endpoint to fetch Open Graph metadata with caching
- `link-preview-ui`: LinkPreviewCard (input area) and LinkPreviewBubble (message bubble) widgets

### Modified Capabilities
- `chat-messaging`: Extend message metadata to include linkPreview object
- `flutter-chat-ui`: Update MessageInputBar and MessageBubble for link preview rendering

## Impact

- **Database**: No schema changes — existing `metadata` JSONB column sufficient
- **API endpoints**: New `POST /chat/link-preview` endpoint for metadata fetching
- **Packages (Flutter)**: None (use built-in regex and http)
- **Packages (API)**: `open-graph-scraper` (Open Graph metadata extraction)
- **Redis**: New cache keys `link-preview:{url}` with 24h TTL
- **Performance**: Debounced fetching (500ms) prevents excessive API calls. Redis cache reduces external HTTP requests.
- **Security**: URL validation blocks private IPs, localhost, and malicious schemes. Timeout and size limits prevent abuse.

