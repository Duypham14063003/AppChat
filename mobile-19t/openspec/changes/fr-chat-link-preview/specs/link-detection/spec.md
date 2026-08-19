# Link Detection

## Overview

Detects URLs in message text input and triggers preview fetching. Uses regex pattern to find first URL in text. Debounces fetching by 500ms to avoid excessive API calls while user is typing.

## Requirements

### Functional

- **LD-001**: System detects URLs in text input using regex pattern `https?://[^\s]+`
- **LD-002**: System extracts first URL only (ignores subsequent URLs)
- **LD-003**: System debounces preview fetching by 500ms after user stops typing
- **LD-004**: If URL is detected, system calls backend API to fetch preview
- **LD-005**: If URL is removed from text, system clears preview
- **LD-006**: If URL is changed, system fetches new preview
- **LD-007**: System shows loading indicator while fetching preview

### Non-Functional

- **LD-NFR-001**: URL detection completes within 10ms (regex is fast)
- **LD-NFR-002**: Debounce timer cancels previous timer on each text change
- **LD-NFR-003**: Detection works for URLs anywhere in text (beginning, middle, end)

## User Flow

```
User types in MessageInputBar
    ↓
TextField onChange triggered
    ↓
Extract text content
    ↓
Apply regex: https?://[^\s]+
    ↓
[No match] → Clear preview, return
[Match found] → Extract first URL
    ↓
Cancel previous debounce timer
    ↓
Start new debounce timer (500ms)
    ↓
[User continues typing] → Cancel timer, restart
[User stops typing for 500ms] → Timer fires
    ↓
Call fetchLinkPreview(url)
```

## Technical Details

### Flutter Implementation

**Location**: `apps/mobile/lib/features/chat/widgets/message_input_bar.dart`

**State additions**:
```dart
class _MessageInputBarState extends State<MessageInputBar> {
  Timer? _debounceTimer;
  String? _currentUrl;
  LinkPreview? _currentPreview;
  bool _isLoadingPreview = false;
  
  // Existing state...
}
```

**URL detection method**:
```dart
void _onTextChanged(String text) {
  setState(() => _hasText = text.trim().isNotEmpty);
  
  // Detect URL
  final urlRegex = RegExp(r'https?://[^\s]+');
  final match = urlRegex.firstMatch(text);
  final url = match?.group(0);
  
  // If URL changed
  if (url != _currentUrl) {
    _currentUrl = url;
    
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    if (url == null) {
      // URL removed
      setState(() {
        _currentPreview = null;
        _isLoadingPreview = false;
      });
    } else {
      // URL detected, debounce fetch
      setState(() => _isLoadingPreview = true);
      _debounceTimer = Timer(Duration(milliseconds: 500), () {
        _fetchLinkPreview(url);
      });
    }
  }
}
```

**Preview fetching method**:
```dart
Future<void> _fetchLinkPreview(String url) async {
  try {
    final repo = ref.read(chatRepositoryProvider);
    final preview = await repo.fetchLinkPreview(url);
    
    if (mounted && _currentUrl == url) {
      setState(() {
        _currentPreview = preview;
        _isLoadingPreview = false;
      });
    }
  } catch (e) {
    debugPrint('[MessageInputBar] Failed to fetch link preview: $e');
    if (mounted) {
      setState(() {
        _currentPreview = null;
        _isLoadingPreview = false;
      });
    }
  }
}
```

**Dispose**:
```dart
@override
void dispose() {
  _debounceTimer?.cancel();
  _controller.dispose();
  _focusNode.dispose();
  super.dispose();
}
```

### Regex Pattern

**Pattern**: `https?://[^\s]+`

**Explanation**:
- `https?` — matches "http" or "https"
- `://` — matches "://"
- `[^\s]+` — matches one or more non-whitespace characters

**Examples**:
- ✅ "Check https://example.com" → matches "https://example.com"
- ✅ "https://example.com/path?query=1" → matches full URL
- ✅ "Visit http://localhost:3000" → matches "http://localhost:3000"
- ✅ "https://example.com and https://other.com" → matches "https://example.com" (first only)
- ❌ "example.com" → no match (no protocol)
- ❌ "ftp://example.com" → no match (not http/https)

## Testing

### Unit Tests

- Test URL detection with various text inputs
- Test first URL extraction from multi-URL text
- Test debounce timer cancellation
- Test preview clearing when URL removed
- Test preview fetching when URL detected

### Widget Tests

- Test TextField onChange triggers URL detection
- Test loading indicator appears during fetch
- Test preview card appears after successful fetch
- Test preview clears when URL removed from text

## Acceptance Criteria

- [ ] URLs detected using regex pattern
- [ ] First URL extracted from multi-URL text
- [ ] Preview fetching debounced by 500ms
- [ ] Loading indicator shown during fetch
- [ ] Preview cleared when URL removed
- [ ] Preview updated when URL changed
- [ ] Debounce timer cancelled on text change
- [ ] Debounce timer cancelled on dispose

