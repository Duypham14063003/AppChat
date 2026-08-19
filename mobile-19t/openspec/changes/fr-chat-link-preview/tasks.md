# Implementation Tasks

## Phase 1: Dependencies & Setup

### Task 1.1: Add backend dependencies
- [x] Add `open-graph-scraper: ^6.5.0` to `apps/api/package.json`
- [x] Run `npm install` in `apps/api`

### Task 1.2: Add Flutter dependencies
- [x] Add `url_launcher: ^6.2.0` to `apps/mobile/pubspec.yaml`
- [x] Run `flutter pub get`
- [x] Verify `cached_network_image` already exists

## Phase 2: Backend Implementation

### Task 2.1: Create LinkPreviewService
- [x] Create `apps/api/src/modules/chat/services/link-preview.service.ts`
- [x] Implement `fetchPreview(url, userId)` method
- [x] Implement `isValidUrl(url)` private method for validation
- [x] Add URL format validation (http/https only)
- [x] Add private IP blocking (127.0.0.1, 192.168.*, 10.*, 172.16-31.*)
- [x] Add localhost blocking
- [x] Implement rate limiting (Redis: `rate-limit:link-preview:{userId}`, 10/min)
- [x] Implement Redis caching (key: `link-preview:{url}`, TTL: 24h)
- [x] Integrate `open-graph-scraper` for metadata extraction
- [x] Implement fallback chain: Open Graph → Twitter Card → HTML meta → title only
- [x] Set timeout to 5 seconds
- [x] Handle errors gracefully (return null)

### Task 2.2: Create LinkPreviewController
- [x] Create `apps/api/src/modules/chat/link-preview.controller.ts`
- [x] Add `POST /chat/link-preview` endpoint
- [x] Apply `JwtAuthGuard` for authentication
- [x] Accept `url` in request body
- [x] Call `LinkPreviewService.fetchPreview()`
- [x] Return preview object or null

### Task 2.3: Update ChatModule
- [x] Import `LinkPreviewController` in `apps/api/src/modules/chat/chat.module.ts`
- [x] Import `LinkPreviewService` in `apps/api/src/modules/chat/chat.module.ts`
- [x] Add to `controllers` array
- [x] Add to `providers` array

## Phase 3: Flutter - Data Layer

### Task 3.1: Create LinkPreview model
- [x] Create `apps/mobile/lib/features/chat/models/link_preview.dart`
- [x] Define `LinkPreview` class with fields: url, title, description, image, siteName
- [x] Implement `fromJson()` factory constructor
- [x] Implement `toJson()` method

### Task 3.2: Update ChatRepository
- [x] Add `fetchLinkPreview(String url)` method in `apps/mobile/lib/features/chat/data/chat_repository.dart`
- [x] POST to `/chat/link-preview` with url
- [x] Parse response to `LinkPreview` object
- [x] Handle errors and return null

## Phase 4: Flutter - URL Detection

### Task 4.1: Update MessageInputBar state
- [x] Add state variables in `apps/mobile/lib/features/chat/widgets/message_input_bar.dart`:
  - `Timer? _linkDebounceTimer`
  - `String? _currentUrl`
  - `LinkPreview? _currentPreview`
  - `bool _isLoadingPreview`

### Task 4.2: Implement URL detection
- [x] Add `_detectUrl(String text)` method
- [x] Implement regex pattern: `RegExp(r'https?://[^\s]+')`
- [x] Extract first URL from text
- [x] Compare with `_currentUrl` to detect changes
- [x] Cancel previous debounce timer on change
- [x] Clear preview if URL removed
- [x] Start new debounce timer (500ms) if URL detected

### Task 4.3: Implement preview fetching
- [x] Add `_fetchLinkPreview(String url)` async method
- [x] Call `onFetchLinkPreview` callback
- [x] Update `_currentPreview` state on success
- [x] Clear `_isLoadingPreview` on completion
- [x] Handle errors gracefully

### Task 4.4: Update dispose
- [x] Cancel `_linkDebounceTimer` in dispose method

## Phase 5: Flutter - UI Components

### Task 5.1: Create LinkPreviewCard widget
- [x] Create `apps/mobile/lib/features/chat/widgets/link_preview_card.dart`
- [x] Implement compact horizontal layout
- [x] Add remove button [×] (IconButton)
- [x] Add image (60x60, CachedNetworkImage)
- [x] Add title (1 line, bold)
- [x] Add description (1 line, secondary color)
- [x] Add site name (small, gray)
- [x] Handle missing fields gracefully

### Task 5.2: Create LinkPreviewBubble widget
- [x] Create `apps/mobile/lib/features/chat/widgets/link_preview_bubble.dart`
- [x] Implement full-width vertical layout
- [x] Add image (full width, 200px height, CachedNetworkImage)
- [x] Add title (2 lines, bold)
- [x] Add description (3 lines, secondary color)
- [x] Add site name (small, gray)
- [x] Add GestureDetector for tap-to-open URL
- [x] Implement `_openUrl()` method using `url_launcher`
- [x] Handle missing fields gracefully

### Task 5.3: Update MessageInputBar UI
- [x] Add loading indicator below TextField (when `_isLoadingPreview`)
- [x] Add LinkPreviewCard below TextField (when `_currentPreview != null`)
- [x] Pass `onRemove` callback to clear preview
- [x] Update `onSend` callback signature to include `LinkPreview?`
- [x] Clear preview state after sending

### Task 5.4: Update MessageBubble
- [x] Check for `metadata.linkPreview` in message
- [x] Parse `linkPreview` to `LinkPreview` object
- [x] Render `LinkPreviewBubble` widget
- [x] Position below message text content

## Phase 6: Flutter - Message Sending

### Task 6.1: Update ChatProviders
- [x] Update `sendMessage()` signature in `apps/mobile/lib/features/chat/providers/chat_providers.dart`
- [x] Accept optional `LinkPreview? linkPreview` parameter
- [x] Build metadata object with `linkPreview` if provided
- [x] Pass metadata to WS payload and local Drift insert

### Task 6.2: Update ChatScreen
- [x] Update `MessageInputBar` onSend callback in `apps/mobile/lib/features/chat/screens/chat_screen.dart`
- [x] Pass `linkPreview` parameter to `sendMessage()`
- [x] Pass `onFetchLinkPreview` callback to MessageInputBar

## Phase 7: Testing

### Task 7.1: Backend tests
- [x] Test URL validation (valid, invalid, private IP, localhost)
- [x] Test rate limiting (10 requests/min)
- [x] Test Redis caching (cache hit, cache miss)
- [x] Test Open Graph parsing
- [x] Test fallback chain
- [x] Test timeout handling
- [x] Test error handling
- [x] Test POST /chat/link-preview endpoint

### Task 7.2: Flutter unit tests
- [ ] Test LinkPreview model (fromJson, toJson)
- [ ] Test ChatRepository.fetchLinkPreview()
- [ ] Test URL detection regex
- [ ] Test debounce timer logic

### Task 7.3: Flutter widget tests
- [ ] Test LinkPreviewCard rendering
- [ ] Test LinkPreviewCard remove button
- [ ] Test LinkPreviewBubble rendering
- [ ] Test MessageInputBar with preview
- [ ] Test MessageBubble with preview

### Task 7.4: Integration tests
- [ ] Test full flow: type URL → preview → send → display
- [ ] Test remove preview → send → no preview
- [ ] Test tap preview → URL opens

## Phase 8: Documentation

### Task 8.1: Update CLAUDE.md
- [ ] Document link preview feature
- [ ] Add POST /chat/link-preview endpoint
- [ ] Add open-graph-scraper package to API dependencies
- [ ] Add url_launcher package to mobile dependencies

## Estimated Effort

- Phase 1: 0.5 hours
- Phase 2: 3 hours
- Phase 3: 1 hour
- Phase 4: 2 hours
- Phase 5: 4 hours
- Phase 6: 1 hour
- Phase 7: 3 hours
- Phase 8: 0.5 hours

**Total: ~15 hours**

## Dependencies

- Phase 2 depends on Phase 1
- Phase 3 depends on Phase 1
- Phase 4 depends on Phase 3
- Phase 5 depends on Phase 3
- Phase 6 depends on Phase 4, 5
- Phase 7 depends on all previous phases
- Phase 8 depends on Phase 7

