# Link Preview UI

## Overview

UI components for displaying link previews in two contexts: compact preview card in input area (before sending) and full preview bubble in message bubbles (after sending). Includes remove functionality for input preview and tap-to-open for both.

## Requirements

### Functional

- **LPUI-001**: LinkPreviewCard widget displays preview in input area (below TextField)
- **LPUI-002**: LinkPreviewCard shows compact horizontal layout: image (60x60), title (1 line), description (1 line), remove button [×]
- **LPUI-003**: LinkPreviewCard remove button clears preview when tapped
- **LPUI-004**: LinkPreviewCard opens URL in browser when tapped (except remove button)
- **LPUI-005**: LinkPreviewBubble widget displays preview in message bubble
- **LPUI-006**: LinkPreviewBubble shows full vertical layout: image (full width, 200px height), title (2 lines), description (3 lines), site name
- **LPUI-007**: LinkPreviewBubble opens URL in browser when tapped
- **LPUI-008**: Both widgets handle missing image gracefully (show placeholder or hide)
- **LPUI-009**: Both widgets handle missing title/description gracefully (hide if null)
- **LPUI-010**: MessageInputBar shows loading indicator while fetching preview
- **LPUI-011**: MessageBubble renders LinkPreviewBubble when metadata.linkPreview exists

### Non-Functional

- **LPUI-NFR-001**: Images load with CachedNetworkImage for performance
- **LPUI-NFR-002**: Text truncates with ellipsis when exceeding max lines
- **LPUI-NFR-003**: Tap feedback provides visual indication (ripple effect)
- **LPUI-NFR-004**: Widgets are responsive and adapt to screen width

## User Flow

```
INPUT AREA FLOW:
────────────────
User types URL → Preview fetched
    ↓
LinkPreviewCard appears below TextField
    ↓
User can:
├─ Tap [×] → Preview removed
├─ Tap card → URL opens in browser
└─ Send message → Preview included in metadata


MESSAGE BUBBLE FLOW:
────────────────────
Message received with metadata.linkPreview
    ↓
MessageBubble renders LinkPreviewBubble
    ↓
User taps preview → URL opens in browser
```

## Technical Details

### Flutter Implementation

**Location**: `apps/mobile/lib/features/chat/widgets/link_preview_card.dart` (new file)

**LinkPreviewCard** (for input area):
```dart
class LinkPreviewCard extends StatelessWidget {
  final LinkPreview preview;
  final VoidCallback onRemove;

  const LinkPreviewCard({
    required this.preview,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.surfaceVariant),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.surface,
      ),
      child: Row(
        children: [
          // Remove button
          IconButton(
            icon: Icon(Icons.close, size: 20),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
          SizedBox(width: 8),
          
          // Image
          if (preview.image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: preview.image!,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 60,
                  height: 60,
                  color: AppColors.surfaceVariant,
                ),
                errorWidget: (context, url, error) => Container(
                  width: 60,
                  height: 60,
                  color: AppColors.surfaceVariant,
                  child: Icon(Icons.link, color: AppColors.textSecondary),
                ),
              ),
            ),
          
          SizedBox(width: 12),
          
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (preview.title != null)
                  Text(
                    preview.title!,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (preview.description != null)
                  Text(
                    preview.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (preview.siteName != null)
                  Text(
                    preview.siteName!,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

**Location**: `apps/mobile/lib/features/chat/widgets/link_preview_bubble.dart` (new file)

**LinkPreviewBubble** (for message bubble):
```dart
class LinkPreviewBubble extends StatelessWidget {
  final LinkPreview preview;

  const LinkPreviewBubble({required this.preview});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openUrl(preview.url),
      child: Container(
        margin: EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.surfaceVariant),
          borderRadius: BorderRadius.circular(8),
          color: AppColors.surface,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            if (preview.image != null)
              CachedNetworkImage(
                imageUrl: preview.image!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: double.infinity,
                  height: 200,
                  color: AppColors.surfaceVariant,
                ),
                errorWidget: (context, url, error) => SizedBox.shrink(),
              ),
            
            // Text content
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (preview.title != null)
                    Text(
                      preview.title!,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (preview.description != null) ...[
                    SizedBox(height: 4),
                    Text(
                      preview.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (preview.siteName != null) ...[
                    SizedBox(height: 8),
                    Text(
                      preview.siteName!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
```

**MessageInputBar update**: `apps/mobile/lib/features/chat/widgets/message_input_bar.dart`

```dart
// Add to build method, after TextField:
if (_isLoadingPreview)
  Padding(
    padding: EdgeInsets.all(8),
    child: Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 8),
        Text('Đang tải preview...', style: TextStyle(fontSize: 12)),
      ],
    ),
  ),

if (_currentPreview != null)
  LinkPreviewCard(
    preview: _currentPreview!,
    onRemove: () {
      setState(() {
        _currentPreview = null;
        _currentUrl = null;
      });
    },
  ),
```

**MessageBubble update**: `apps/mobile/lib/features/chat/widgets/message_bubble.dart`

```dart
// In _buildBubble method, after text content:
if (message.type == 'text' && meta != null && meta['linkPreview'] != null) {
  final linkPreview = LinkPreview.fromJson(
    meta['linkPreview'] as Map<String, dynamic>,
  );
  return LinkPreviewBubble(preview: linkPreview);
}
```

**Send message with preview**: `apps/mobile/lib/features/chat/providers/chat_providers.dart`

```dart
// In sendMessage method:
Future<void> sendMessage(String text, {LinkPreview? linkPreview}) async {
  // ... existing code ...
  
  final metadata = linkPreview != null
      ? {'linkPreview': linkPreview.toJson()}
      : null;
  
  _sendMessage(
    type: 'text',
    content: text,
    metadata: metadata,
    id: id,
  );
}
```

**MessageInputBar onSend update**:
```dart
void _send() {
  final text = _controller.text.trim();
  if (text.isEmpty) return;
  
  widget.onSend(text, linkPreview: _currentPreview);
  
  _controller.clear();
  setState(() {
    _hasText = false;
    _showEmojiPicker = false;
    _currentPreview = null;
    _currentUrl = null;
  });
  _focusNode.requestFocus();
}
```

### Dependencies

Add to `apps/mobile/pubspec.yaml`:
```yaml
dependencies:
  cached_network_image: ^3.3.0  # Already exists
  url_launcher: ^6.2.0          # For opening URLs
```

## Testing

### Widget Tests

- Test LinkPreviewCard renders with all fields
- Test LinkPreviewCard renders with missing image
- Test LinkPreviewCard renders with missing description
- Test LinkPreviewCard remove button triggers onRemove
- Test LinkPreviewCard tap opens URL
- Test LinkPreviewBubble renders with all fields
- Test LinkPreviewBubble renders with missing fields
- Test LinkPreviewBubble tap opens URL
- Test MessageInputBar shows loading indicator
- Test MessageInputBar shows LinkPreviewCard
- Test MessageBubble renders LinkPreviewBubble

### Integration Tests

- Test full flow: type URL → preview appears → send → bubble shows preview
- Test remove preview → send → bubble shows no preview
- Test tap preview in bubble → URL opens

## Acceptance Criteria

- [ ] LinkPreviewCard displays in input area with compact layout
- [ ] LinkPreviewCard shows image (60x60), title (1 line), description (1 line)
- [ ] LinkPreviewCard remove button [×] clears preview
- [ ] LinkPreviewCard tap opens URL in browser
- [ ] LinkPreviewBubble displays in message bubble with full layout
- [ ] LinkPreviewBubble shows image (200px height), title (2 lines), description (3 lines)
- [ ] LinkPreviewBubble tap opens URL in browser
- [ ] Loading indicator shown while fetching preview
- [ ] Missing fields handled gracefully (no crash)
- [ ] Images cached with CachedNetworkImage
- [ ] Text truncates with ellipsis
- [ ] Tap feedback provides visual indication

