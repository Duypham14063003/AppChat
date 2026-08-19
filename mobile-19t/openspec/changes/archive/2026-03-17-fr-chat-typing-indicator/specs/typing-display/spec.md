# Typing Display

## Overview

Displays typing indicator UI above MessageInputBar. Shows animated dots and group-aware text. Handles different display modes: direct chat ("typing..."), group with 1-3 users (show names), group with 4+ users (show count).

## Requirements

### Functional

- **TD-001**: TypingIndicator widget displays above MessageInputBar
- **TD-002**: Widget shows animated dots (3 dots with fade in/out)
- **TD-003**: Widget displays "typing..." in direct chat (no name)
- **TD-004**: Widget displays "Name is typing..." in group with 1 user
- **TD-005**: Widget displays "Name1, Name2 are typing..." in group with 2-3 users
- **TD-006**: Widget displays "N people are typing..." in group with 4+ users
- **TD-007**: Widget filters out current user from display
- **TD-008**: Widget hides when no users are typing
- **TD-009**: Widget uses secondary text color (gray)
- **TD-010**: Widget uses italic font style

### Non-Functional

- **TD-NFR-001**: Animation runs at 60fps (smooth)
- **TD-NFR-002**: Widget height is minimal (~24px)
- **TD-NFR-003**: Widget does not cause layout jank

## User Flow

```
ChatScreen renders
    ↓
Check typingUsers map
    ↓
[Empty] → Hide TypingIndicator
[Not empty] → Show TypingIndicator
    ↓
Filter out current user
    ↓
Determine display text:
├─ Direct chat → "typing..."
├─ Group, 1 user → "Name is typing..."
├─ Group, 2-3 users → "Name1, Name2 are typing..."
└─ Group, 4+ users → "N people are typing..."
    ↓
Render text + animated dots
    ↓
Animation controller loops (1.5s cycle)
    ↓
Dots fade in/out with 0.5s offset
```

## Technical Details

### Flutter Implementation

**Location**: `apps/mobile/lib/features/chat/widgets/typing_indicator.dart` (new file)

**Widget structure**:
```dart
class TypingIndicator extends StatefulWidget {
  final List<String> typingUserIds;
  final bool isGroup;
  final String? currentUserId;

  const TypingIndicator({
    super.key,
    required this.typingUserIds,
    required this.isGroup,
    this.currentUserId,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter out current user
    final users = widget.typingUserIds
        .where((id) => id != widget.currentUserId)
        .toList();

    if (users.isEmpty) return SizedBox.shrink();

    // Determine display text
    String text;
    if (!widget.isGroup) {
      text = 'typing';
    } else if (users.length == 1) {
      text = '${_getUserName(users[0])} is typing';
    } else if (users.length <= 3) {
      final names = users.map(_getUserName).join(', ');
      text = '$names are typing';
    } else {
      text = '${users.length} people are typing';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
          SizedBox(width: 4),
          AnimatedDots(controller: _controller),
        ],
      ),
    );
  }

  String _getUserName(String userId) {
    // TODO: Get user name from conversation members
    // For now, return placeholder
    return 'User';
  }
}
```

**Animated dots widget**:
```dart
class AnimatedDots extends StatelessWidget {
  final AnimationController controller;

  const AnimatedDots({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final progress = controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(progress, 0),
            SizedBox(width: 2),
            _buildDot(progress, 0.33),
            SizedBox(width: 2),
            _buildDot(progress, 0.66),
          ],
        );
      },
    );
  }

  Widget _buildDot(double progress, double offset) {
    // Calculate opacity: fade in/out with offset
    final adjustedProgress = (progress + offset) % 1.0;
    final opacity = adjustedProgress < 0.5
        ? adjustedProgress * 2 // Fade in
        : (1.0 - adjustedProgress) * 2; // Fade out

    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withOpacity(opacity.clamp(0.3, 1.0)),
        shape: BoxShape.circle,
      ),
    );
  }
}
```

**Integration in ChatScreen**:
```dart
// In build method, in Column before MessageInputBar:
Column(
  children: [
    // Message list...
    Expanded(
      child: ListView.builder(...),
    ),
    
    // Typing indicator
    if (_typingUsers.isNotEmpty)
      TypingIndicator(
        typingUserIds: _typingUsers.keys.toList(),
        isGroup: conv?.type == 'GROUP',
        currentUserId: authState.valueOrNull?.user?.id,
      ),
    
    // Message input
    MessageInputBar(...),
  ],
)
```

### User Name Resolution

**Option 1**: Get from conversation members (recommended)
```dart
String _getUserName(String userId) {
  final conv = ref.read(chatConversationProvider(widget.conversationId));
  final member = conv?.members?.firstWhere(
    (m) => m.userId == userId,
    orElse: () => null,
  );
  return member?.user?.name ?? 'User';
}
```

**Option 2**: Get from separate user cache (if available)
```dart
String _getUserName(String userId) {
  final user = ref.read(userCacheProvider(userId));
  return user?.name ?? 'User';
}
```

**Option 3**: Pass user names from parent (simplest for MVP)
```dart
// In ChatScreen, pass Map<userId, userName>
TypingIndicator(
  typingUsers: _typingUsers.map((id, ts) => MapEntry(
    id,
    _getUserNameFromConv(id),
  )),
  isGroup: conv?.type == 'GROUP',
)
```

## Testing

### Widget Tests

- Test TypingIndicator renders with 1 user
- Test TypingIndicator renders with 3 users
- Test TypingIndicator renders with 5 users
- Test TypingIndicator hides when empty
- Test TypingIndicator filters out current user
- Test AnimatedDots animation runs
- Test text displays correctly for direct chat
- Test text displays correctly for group chat

### Visual Tests

- Test dots animate smoothly (60fps)
- Test opacity transitions are smooth
- Test layout does not jank when appearing/disappearing

## Acceptance Criteria

- [ ] TypingIndicator displays above MessageInputBar
- [ ] Animated dots (3 dots) with fade in/out
- [ ] Direct chat shows "typing..."
- [ ] Group with 1 user shows "Name is typing..."
- [ ] Group with 2-3 users shows "Name1, Name2 are typing..."
- [ ] Group with 4+ users shows "N people are typing..."
- [ ] Current user filtered out from display
- [ ] Widget hides when no users typing
- [ ] Text uses secondary color and italic style
- [ ] Animation runs smoothly at 60fps
- [ ] No layout jank when appearing/disappearing

