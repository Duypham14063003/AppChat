## Context

Text messaging is complete. Users share URLs frequently but they appear as plain text with no context. The message entity already has a `metadata` JSONB column that can store link preview data. No link preview functionality exists yet.

This change implements CHAT-FR-027 (Link Preview, P2 COULD). It follows Telegram's UX pattern: pre-send preview fetching, user can remove preview, preview included in message metadata, recipient sees preview immediately.

Key constraints: First URL only (ignore subsequent URLs), external image URLs (no local caching), Redis cache (24h TTL), strict security validation (block private IPs, timeout 5s, max size 5MB).

## Goals / Non-Goals

**Goals:**
- URL detection in MessageInputBar using regex pattern
- Debounced preview fetching (500ms after typing stops)
- Backend endpoint `POST /chat/link-preview` for Open Graph scraping
- LinkPreviewCard widget for input area (compact, horizontal, with remove button)
- LinkPreviewBubble widget for message bubbles (full-width, vertical, with image)
- Open Graph metadata extraction (title, description, image, siteName)
- Fallback to Twitter Card and HTML meta tags
- Redis caching (24h TTL) to avoid repeated fetches
- URL validation (format, block private IPs, block localhost)
- Security: timeout 5s, max response size 5MB, rate limit 10/min per user
- Tap preview card → open URL in browser

**Non-Goals:**
- Special handling for YouTube, Twitter, Instagram (Phase 2)
- oEmbed support for rich embeds
- Image proxying or local caching
- Multiple URL previews in one message
- Preview editing or customization
- Server-side URL detection (client handles detection)
- Background preview fetching for received messages

## Decisions

### D1: Timing — Pre-send preview (Telegram approach)
**Choice**: Fetch preview before sending message. Show preview below input field. User can remove preview. Include preview in message metadata when sending.
**Rationale**: Matches Telegram UX. User sees preview before sending and can remove unwanted previews. Recipient sees preview immediately (no loading state). Better UX than post-send fetching.
**Alternative considered**: Post-send fetching (WhatsApp style) — rejected because it requires message update mechanism and shows loading state to recipient.

### D2: URL detection — Client-side regex
**Choice**: Detect URLs in Flutter using regex pattern `https?://[^\s]+`. Extract first URL only.
**Rationale**: Simple and fast. No server round-trip for detection. Matches Telegram behavior (first URL only). Regex is sufficient for basic URL detection.
**Pattern**: `final urlRegex = RegExp(r'https?://[^\s]+'); final match = urlRegex.firstMatch(text);`

### D3: Debouncing — 500ms delay
**Choice**: Debounce preview fetching by 500ms after user stops typing.
**Rationale**: Prevents excessive API calls while user is typing. 500ms is fast enough to feel instant but slow enough to avoid fetching for every keystroke. Matches Telegram behavior.
**Implementation**: Use `Timer` in Flutter to cancel and restart on each text change.

### D4: Multiple URLs — First URL only
**Choice**: If message contains multiple URLs, preview only the first one.
**Rationale**: Matches Telegram behavior. Simpler UX (one preview card). Cleaner message bubble. Avoids complexity of multiple previews.
**Example**: "Check https://a.com and https://b.com" → preview only https://a.com

### D5: Open Graph scraping — `open-graph-scraper` package
**Choice**: Use `open-graph-scraper` npm package for metadata extraction.
**Rationale**: Popular (1.5k+ stars), handles redirects, fallback to meta tags, TypeScript support. Battle-tested and maintained.
**Fallback chain**:
1. Open Graph tags (og:title, og:description, og:image, og:url, og:site_name)
2. Twitter Card tags (twitter:title, twitter:description, twitter:image)
3. HTML meta tags (<title>, <meta name="description">)
4. Page title only
5. No preview (return null)

### D6: Caching — Redis with 24h TTL
**Choice**: Cache preview data in Redis with key `link-preview:{url}` and 24h TTL.
**Rationale**: Avoids repeated fetches for popular URLs. 24h is long enough to reduce load but short enough to reflect content updates. Redis is already used for session management.
**Cache key**: `link-preview:https://example.com/article`
**Cache value**: JSON string of preview object

### D7: Image handling — External URLs (no caching)
**Choice**: Store og:image URL directly in metadata. No local caching or proxying.
**Rationale**: Simpler implementation. No storage cost. Always up-to-date. Flutter's `CachedNetworkImage` handles image caching on client side.
**Future enhancement**: Proxy images through backend for privacy/reliability.

### D8: Security validation — Strict URL filtering
**Choice**: Validate URLs on backend:
- Format: must match `https?://` pattern
- Block private IPs: 127.0.0.1, 192.168.*, 10.*, 172.16-31.*
- Block localhost
- Block non-HTTP schemes: file://, javascript:, data:
- Timeout: 5 seconds
- Max response size: 5MB
- Follow redirects: max 3
- User-Agent: "NineteenTechBot/1.0"
**Rationale**: Prevents SSRF attacks, protects internal network, prevents abuse. Standard security practices for URL fetching.

### D9: Rate limiting — 10 requests per minute per user
**Choice**: Rate limit preview fetching to 10 requests per minute per user.
**Rationale**: Prevents abuse and excessive load. 10/min is generous for normal usage (users don't send 10 URLs per minute). Use Redis for rate limit tracking.
**Implementation**: Redis key `rate-limit:link-preview:{userId}`, increment on each request, expire after 60s.

### D10: UI layout — Two widget variants
**Choice**: 
- **LinkPreviewCard** (input area): Compact horizontal layout, 60x60 image, 1-line title, 1-line description, remove button [×]
- **LinkPreviewBubble** (message bubble): Full-width vertical layout, 200px height image, 2-line title, 3-line description, no remove button
**Rationale**: Input area needs compact preview to save space. Message bubble can be larger for better readability. Matches Telegram design.

### D11: Error handling — Silent failures
**Choice**: If preview fetch fails (timeout, error, no metadata), don't show preview. Don't show error to user. Message sends normally with URL as text.
**Rationale**: Link preview is enhancement, not critical feature. Failures shouldn't block message sending. User can still click URL to open.

### D12: Metadata structure
**Choice**: Store in `message.metadata.linkPreview`:
```json
{
  "linkPreview": {
    "url": "https://example.com/article",
    "title": "Article Title",
    "description": "Article description...",
    "image": "https://example.com/image.jpg",
    "siteName": "example.com"
  }
}
```
**Rationale**: Nested under `linkPreview` key to avoid conflicts with other metadata (e.g., image messages have `url` for image file). All fields optional (graceful degradation).

## Risks / Trade-offs

- **[External image URLs may break]** → If og:image URL becomes unavailable, preview shows broken image. Mitigated by: Flutter's error handling in CachedNetworkImage. Future: proxy images through backend.
- **[Preview fetch delays message send]** → User must wait for preview to load before sending. Mitigated by: 5s timeout, user can remove preview to send immediately. Alternative: allow sending while preview is loading (complexity).
- **[Cache may serve stale data]** → 24h TTL means content changes won't reflect immediately. Mitigated by: 24h is reasonable balance. Users can manually refresh by editing URL.
- **[SSRF attack vector]** → Malicious user could try to fetch internal URLs. Mitigated by: strict URL validation, block private IPs, timeout, size limit.
- **[Rate limit may block legitimate users]** → 10/min limit could be hit by power users. Mitigated by: 10/min is generous for normal usage. Can increase if needed.
- **[Open Graph tags may be missing]** → Not all sites have Open Graph tags. Mitigated by: fallback chain (Twitter Card → HTML meta → title only → no preview).

## Open Questions

- None — all decisions made during exploration phase.

