import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_interaction.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../../../shared/widgets/tappable_scale.dart';
import '../../../shared/widgets/hero_avatar.dart';
import '../providers/chat_drafts_provider.dart';

class ConversationTile extends ConsumerStatefulWidget {
  final LocalConversation conversation;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final String? currentUserId;

  static final Map<String, _TimeCache> _timeCache = {};

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.currentUserId,
  });

  @override
  ConsumerState<ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends ConsumerState<ConversationTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final draft = ref.watch(chatDraftsProvider)[widget.conversation.id];
    final conversation = widget.conversation;
    final isWide = MediaQuery.of(context).size.width >= 768;
    final canHover = prefersDesktopUi(context);

    final name = conversation.type == 'DIRECT'
        ? (conversation.otherMemberName ?? 'Unknown')
        : (conversation.name ?? 'Group');
    final avatar = conversation.type == 'DIRECT'
        ? conversation.otherMemberAvatar
        : conversation.avatarUrl;
    final isOnline =
        conversation.type == 'DIRECT' &&
        conversation.otherMemberLastSeenAt != null &&
        DateTime.now()
                .difference(conversation.otherMemberLastSeenAt!)
                .inMinutes <
            2;

    var subtitle = conversation.lastMessageContent ?? '';
    if (subtitle.isEmpty) {
      subtitle = 'Bắt đầu cuộc trò chuyện';
    }

    final highlightTile = widget.isSelected || (canHover && _isHovered);
    final surfaceColor = widget.isSelected
        ? palette.surfaceVariant.withValues(alpha: 0.92)
        : canHover && _isHovered
        ? palette.surfaceVariant.withValues(alpha: 0.62)
        : Colors.transparent;
    final borderColor = widget.isSelected
        ? palette.primary.withValues(alpha: 0.22)
        : canHover && _isHovered
        ? palette.surfaceVariant.withValues(alpha: 0.98)
        : Colors.transparent;

    final tile = ListTile(
      tileColor: Colors.transparent,
      hoverColor: Colors.transparent,
      splashColor: palette.primary.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: EdgeInsets.symmetric(
        horizontal: isWide ? 14 : 16,
        vertical: 4,
      ),
      leading: Stack(
        children: [
          HeroAvatar(
            tag: 'avatar_${conversation.id}',
            imageUrl: avatar,
            radius: 24,
            fallbackIcon: conversation.type == 'DIRECT'
                ? Icons.person
                : Icons.group,
          ),
          if (isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.online,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.background, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        name,
        style: TextStyle(
          color: palette.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: draft != null && draft.isNotEmpty
          ? Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: '[Nháp] ',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: draft,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : Text(
              subtitle,
              style: TextStyle(
                color: conversation.unreadCount > 0
                    ? palette.textPrimary
                    : palette.textSecondary,
                fontWeight: conversation.unreadCount > 0
                    ? FontWeight.w500
                    : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(conversation.lastMessageAt),
            style: TextStyle(
              fontSize: 12,
              color: conversation.unreadCount > 0
                  ? palette.primary
                  : palette.textHint,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (conversation.unreadMentionCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '@',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (conversation.unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    conversation.unreadCount > 99
                        ? '99+'
                        : '${conversation.unreadCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
    );

    final decoratedTile = RepaintBoundary(
      child: AnimatedContainer(
        duration: AppMotion.instant,
        curve: AppMotion.standardCurve,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow: highlightTile
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: palette.isLight ? 0.05 : 0.16,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ]
              : const [],
        ),
        child: tile,
      ),
    );

    if (isWide) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: canHover ? (_) => setState(() => _isHovered = true) : null,
          onExit: canHover ? (_) => setState(() => _isHovered = false) : null,
          child: TappableScale(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            hoverScale: 1.005,
            scaleDown: 0.985,
            duration: AppMotion.instant,
            enableHaptic: true,
            child: decoratedTile,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TappableScale(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          enableHaptic: true,
          scaleDown: 0.985,
          child: decoratedTile,
        ),
        Divider(height: 1, indent: 80, color: palette.surfaceVariant),
      ],
    );
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    final conversation = widget.conversation;
    final cacheKey = '${conversation.id}_${dateTime.millisecondsSinceEpoch}';
    final cached = ConversationTile._timeCache[cacheKey];
    final now = DateTime.now();

    if (cached != null && now.difference(cached.calculatedAt).inSeconds < 30) {
      return cached.formatted;
    }

    final diff = now.difference(dateTime);
    late final String formatted;

    if (diff.inMinutes < 1) {
      formatted = 'Vừa xong';
    } else if (diff.inHours < 1) {
      formatted = '${diff.inMinutes}p';
    } else if (diff.inDays < 1) {
      formatted = '${diff.inHours}h';
    } else if (diff.inDays < 7) {
      formatted = '${diff.inDays}d';
    } else {
      formatted = '${dateTime.day}/${dateTime.month}';
    }

    ConversationTile._timeCache[cacheKey] = _TimeCache(formatted, now);

    if (ConversationTile._timeCache.length > 100) {
      final keys = ConversationTile._timeCache.keys.toList();
      for (var i = 0; i < keys.length - 100; i++) {
        ConversationTile._timeCache.remove(keys[i]);
      }
    }

    return formatted;
  }
}

class _TimeCache {
  final String formatted;
  final DateTime calculatedAt;

  const _TimeCache(this.formatted, this.calculatedAt);
}
