import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../data/chat_avatar_resolver.dart';
import '../providers/chat_providers.dart';
import 'message_bubble.dart';
import 'reaction_bar.dart';
import 'reaction_picker.dart';
import 'reaction_details_sheet.dart';
import 'swipe_to_reply.dart';

class MessageItem extends ConsumerStatefulWidget {
  final LocalMessage message;
  final bool isMine;
  final String? senderName;
  final String? senderAvatar;
  final Color? senderNameColor;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final bool showAvatar;
  final bool showSenderName;
  final void Function(List<String> urls, int index)? onImageTap;
  final void Function(String videoUrl)? onVideoTap;
  final String conversationId;
  final bool isHighlighted;
  final String? replyToSenderName;
  final String? replyToContent;
  final String? replyToType;
  final Color? replyToSenderColor;
  final VoidCallback? onReplyTap;
  final VoidCallback? onSwipeReply;
  final VoidCallback? onLongPressAction;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onSelectionTap;
  final bool isBookmarked;
  final List<MessageSeenByUser> seenByUsers;
  final VoidCallback? onSeenByTap;
  final bool reserveSeenBySpace;

  const MessageItem({
    super.key,
    required this.message,
    required this.isMine,
    required this.conversationId,
    this.senderName,
    this.senderAvatar,
    this.senderNameColor,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.showAvatar = true,
    this.showSenderName = true,
    this.onImageTap,
    this.onVideoTap,
    this.isHighlighted = false,
    this.replyToSenderName,
    this.replyToContent,
    this.replyToType,
    this.replyToSenderColor,
    this.onReplyTap,
    this.onSwipeReply,
    this.onLongPressAction,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectionTap,
    this.isBookmarked = false,
    this.seenByUsers = const [],
    this.onSeenByTap,
    this.reserveSeenBySpace = false,
  });

  @override
  ConsumerState<MessageItem> createState() => _MessageItemState();
}
// MESSAGE_ITEM_STATE_PLACEHOLDER

class _MessageItemState extends ConsumerState<MessageItem>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _pickerOverlay;
  final _bubbleKey = GlobalKey();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppMotion.medium,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: AppMotion.standardCurve,
      ),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: AppMotion.enterCurve,
          ),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    _dismissPicker();
    _animationController.dispose();
    super.dispose();
  }

  void _dismissPicker() {
    _pickerOverlay?.remove();
    _pickerOverlay = null;
  }

  void _showReactionPicker() {
    if (widget.message.type == 'system') return;
    _dismissPicker();

    final renderBox =
        _bubbleKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _pickerOverlay = OverlayEntry(
      builder: (_) => ReactionPicker(
        anchorPosition: position,
        anchorWidth: size.width,
        onEmojiSelected: (emoji) {
          _dismissPicker();
          _toggleReaction(emoji);
        },
        onDismiss: _dismissPicker,
      ),
    );

    Overlay.of(context).insert(_pickerOverlay!);
  }

  void _toggleReaction(String emoji) {
    ref
        .read(chatMessagesProvider(widget.conversationId).notifier)
        .toggleReaction(widget.message.id, emoji);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final reactionsAsync = ref.watch(
      messageReactionsProvider(widget.message.id),
    );
    final reactions = reactionsAsync.valueOrNull ?? [];

    final bubble = RepaintBoundary(
      child: KeyedSubtree(
        key: _bubbleKey,
        child: MessageBubble(
          message: widget.message,
          isMine: widget.isMine,
          senderName: widget.senderName,
          senderAvatar: widget.senderAvatar,
          senderNameColor: widget.senderNameColor,
          isFirstInGroup: widget.isFirstInGroup,
          isLastInGroup: widget.isLastInGroup,
          showAvatar: widget.showAvatar,
          showSenderName: widget.showSenderName,
          isHighlighted: widget.isHighlighted,
          onImageTap: widget.onImageTap,
          onVideoTap: widget.onVideoTap,
          replyToSenderName: widget.replyToSenderName,
          replyToContent: widget.replyToContent,
          replyToType: widget.replyToType,
          replyToSenderColor: widget.replyToSenderColor,
          onReplyTap: widget.onReplyTap,
          isBookmarked: widget.isBookmarked,
        ),
      ),
    );

    return SwipeToReply(
      enabled:
          !widget.isSelectionMode &&
          widget.message.type != 'system' &&
          widget.onSwipeReply != null,
      onReply: () => widget.onSwipeReply?.call(),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: GestureDetector(
            onLongPress: widget.isSelectionMode
                ? null
                : (widget.onLongPressAction ?? _showReactionPicker),
            onSecondaryTap: widget.isSelectionMode
                ? null
                : (widget.onLongPressAction ?? _showReactionPicker),
            onDoubleTap: widget.isSelectionMode
                ? null
                : () => _toggleReaction('❤️'),
            onTap: widget.isSelectionMode ? widget.onSelectionTap : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      widget.isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: widget.isSelected
                          ? palette.primary
                          : palette.textHint,
                      size: 22,
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: widget.isMine
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      bubble,
                      if (reactions.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(
                            left: widget.isMine
                                ? 0
                                : (widget.showAvatar ? 34 : 0),
                          ),
                          child: ReactionBar(
                            reactions: reactions,
                            onToggle: _toggleReaction,
                            onShowDetails: (r) =>
                                showReactionDetailsSheet(context, r),
                          ),
                        ),
                      if ((widget.seenByUsers.isNotEmpty ||
                              widget.reserveSeenBySpace) &&
                          widget.onSeenByTap != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: AnimatedSize(
                              duration: AppMotion.medium,
                              curve: AppMotion.enterCurve,
                              child: widget.seenByUsers.isNotEmpty
                                  ? _SeenByAvatarRow(
                                      users: widget.seenByUsers,
                                      onTap: widget.onSeenByTap!,
                                    )
                                  : const SizedBox(width: 1, height: 22),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeenByAvatarRow extends ConsumerWidget {
  const _SeenByAvatarRow({required this.users, required this.onTap});

  final List<MessageSeenByUser> users;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleUsers = users.take(5).toList();
    final remainingCount = users.length - visibleUsers.length;
    const avatarRadius = 11.0;
    const overlap = 8.0;
    final totalWidth =
        (visibleUsers.length * (avatarRadius * 2 - overlap)) +
        overlap +
        (remainingCount > 0 ? 26 : 0);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: totalWidth,
        height: avatarRadius * 2,
        child: Stack(
          children: [
            for (var i = 0; i < visibleUsers.length; i++)
              Positioned(
                right: i * (avatarRadius * 2 - overlap),
                child: _SeenAvatar(
                  name: visibleUsers[i].name,
                  avatarUrl: visibleUsers[i].avatarUrl,
                  radius: avatarRadius,
                ),
              ),
            if (remainingCount > 0)
              Positioned(
                right: visibleUsers.length * (avatarRadius * 2 - overlap),
                child: Container(
                  width: avatarRadius * 2,
                  height: avatarRadius * 2,
                  decoration: BoxDecoration(
                    color: context.appPalette.surfaceVariant,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.appPalette.background,
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '+$remainingCount',
                    style: TextStyle(
                      color: context.appPalette.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SeenAvatar extends StatelessWidget {
  const _SeenAvatar({
    required this.name,
    required this.avatarUrl,
    required this.radius,
  });

  final String name;
  final String? avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return CircleAvatar(
      radius: radius,
      backgroundColor: palette.background,
      child: CircleAvatar(
        radius: radius - 1.5,
        backgroundColor: palette.surfaceVariant,
        foregroundImage: resolveChatAvatarUrl(avatarUrl) != null
            ? NetworkImage(resolveChatAvatarUrl(avatarUrl)!)
            : null,
        child: Text(
          _initials(name),
          style: TextStyle(
            color: palette.primary,
            fontWeight: FontWeight.w700,
            fontSize: 8,
          ),
        ),
      ),
    );
  }

  String _initials(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '?';
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words.first[0]}${words.last[0]}'.toUpperCase();
    }
    return words.first[0].toUpperCase();
  }
}
