## mention-rendering

Render mention entities in MessageBubble as styled, clickable text spans using Text.rich. Parse metadata.mentions to split content into normal and mention TextSpans.

### Requirements

1. **Mention-aware text rendering in MessageBubble**
   - Replace plain `Text(message.content ?? '')` with `Text.rich(_buildMentionText(message))`
   - Parse `message.metadata` JSON to extract `mentions` array
   - If no mentions or metadata is null: render as plain TextSpan (no behavior change)
   - If mentions exist: split content into segments based on mention offsets

2. **TextSpan construction**
   - Build `List<TextSpan>` by iterating through content:
     - Sort mentions by offset ascending
     - For each gap between mentions: create normal TextSpan (default style)
     - For each mention: create styled TextSpan with:
       - Color: `AppColors.gold`
       - FontWeight: `FontWeight.w600`
       - `TapGestureRecognizer` for tap handling
     - After last mention: create normal TextSpan for remaining text
   - Handle edge cases:
     - Overlapping mentions (shouldn't happen, but skip if detected)
     - Mention offset/length exceeding content length (truncate gracefully)
     - Empty content with mentions (render nothing)

3. **Mention tap handler**
   - On tap: navigate to user profile (if profile screen exists) or show user info bottom sheet
   - For `user_id: "all"`: no tap action (or show "Tất cả thành viên" label)
   - Use `TapGestureRecognizer` — must be disposed properly to avoid memory leaks
   - Add `onMentionTap` callback parameter to `MessageBubble` (optional)

4. **Caption mentions**
   - Image/album captions also use plain `Text()` for caption display
   - Apply same mention rendering to captions if metadata contains mentions
   - Reuse the same `_buildMentionText()` helper method

5. **Self-mention highlighting**
   - If current user is mentioned: optionally render with slightly different background (subtle highlight)
   - This is a nice-to-have — can be deferred. Core requirement is accent color for all mentions.

6. **Performance**
   - Mention parsing should be cached per message (don't re-parse metadata on every build)
   - Use `_parseMetadata()` which already exists in MessageBubble
   - TextSpan construction is lightweight — no performance concern for <50 users

### Technical Details

**Helper method in MessageBubble:**
```dart
TextSpan _buildMentionText(LocalMessage message) {
  final mentions = _parseMentions();
  if (mentions == null || mentions.isEmpty) {
    return TextSpan(
      text: message.content ?? '',
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
    );
  }

  final content = message.content ?? '';
  final spans = <TextSpan>[];
  int currentIndex = 0;

  // Sort mentions by offset
  final sorted = List<Map<String, dynamic>>.from(mentions)
    ..sort((a, b) => (a['offset'] as int).compareTo(b['offset'] as int));

  for (final mention in sorted) {
    final offset = mention['offset'] as int;
    final length = mention['length'] as int;
    final end = (offset + length).clamp(0, content.length);

    // Normal text before mention
    if (offset > currentIndex) {
      spans.add(TextSpan(
        text: content.substring(currentIndex, offset.clamp(0, content.length)),
      ));
    }

    // Mention span
    spans.add(TextSpan(
      text: content.substring(offset.clamp(0, content.length), end),
      style: const TextStyle(
        color: AppColors.gold,
        fontWeight: FontWeight.w600,
      ),
      recognizer: TapGestureRecognizer()..onTap = () {
        // Navigate to profile or show user info
      },
    ));

    currentIndex = end;
  }

  // Remaining text after last mention
  if (currentIndex < content.length) {
    spans.add(TextSpan(text: content.substring(currentIndex)));
  }

  return TextSpan(
    style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
    children: spans,
  );
}
```

### Integration Points

- `MessageBubble._buildBubble()` — replace `Text()` with `Text.rich()`
- `MessageBubble._parseMetadata()` — already exists, reuse for mention extraction
- `ChatScreen` — pass `onMentionTap` callback if profile navigation is available
- `AppColors.gold` — accent color for mention spans (already defined)

### Acceptance Criteria

- Message with mentions renders mention text in gold/accent color
- Message without mentions renders identically to current behavior (no regression)
- Tap on mention text triggers tap handler (no crash, recognizer works)
- Multiple mentions in one message all render correctly
- `@Tất cả` renders in gold like other mentions
- Mention at start of message renders correctly
- Mention at end of message renders correctly
- Adjacent mentions render correctly
- Image/album captions with mentions render correctly
- Long messages with mentions don't cause performance issues
- GestureRecognizers are properly disposed (no memory leaks)

