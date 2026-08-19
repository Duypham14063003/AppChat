import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/encrypted_message_adapter.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../providers/chat_providers.dart';
import 'chat_avatar.dart';

Future<void> showConversationPeekPreview({
  required BuildContext context,
  required LocalConversation conversation,
  required String? currentUserId,
  required VoidCallback onOpenChat,
  AsyncValue<List<LocalMessage>>? previewMessagesOverride,
}) {
  final isWide = MediaQuery.of(context).size.width >= 768;

  if (isWide) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.26),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(32),
          child: SizedBox(
            width: 468,
            height: 680,
            child: ConversationPeekPreview(
              conversation: conversation,
              currentUserId: currentUserId,
              onOpenChat: () {
                Navigator.of(dialogContext).pop();
                onOpenChat();
              },
              previewMessagesOverride: previewMessagesOverride,
            ),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.22),
    builder: (sheetContext) {
      final mediaQuery = MediaQuery.of(sheetContext);
      final double maxHeight = math.min<double>(
        mediaQuery.size.height * 0.78,
        680.0,
      );
      final double maxWidth = math.min<double>(
        mediaQuery.size.width - 12.0,
        520.0,
      );
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            6.0,
            0.0,
            6.0,
            math.max<double>(mediaQuery.padding.bottom, 6.0),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              child: ConversationPeekPreview(
                conversation: conversation,
                currentUserId: currentUserId,
                onOpenChat: () {
                  Navigator.of(sheetContext).pop();
                  onOpenChat();
                },
                previewMessagesOverride: previewMessagesOverride,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class ConversationPeekPreview extends ConsumerWidget {
  const ConversationPeekPreview({
    super.key,
    required this.conversation,
    required this.currentUserId,
    required this.onOpenChat,
    this.previewMessagesOverride,
  });

  final LocalConversation conversation;
  final String? currentUserId;
  final VoidCallback onOpenChat;
  final AsyncValue<List<LocalMessage>>? previewMessagesOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appPalette;
    final overrideMessagesAsync = previewMessagesOverride;
    final AsyncValue<List<LocalMessage>> messagesAsync;
    if (overrideMessagesAsync != null) {
      messagesAsync = overrideMessagesAsync;
    } else {
      messagesAsync = ref.watch(
        chatConversationPreviewProvider(conversation.id),
      );
    }
    final name = _conversationName(conversation);
    final avatar = conversation.type == 'DIRECT'
        ? conversation.otherMemberAvatar
        : conversation.avatarUrl;
    final shellColor = Color.alphaBlend(
      palette.primary.withValues(alpha: palette.isLight ? 0.06 : 0.12),
      palette.surface,
    );
    final bodyColor = Color.alphaBlend(
      palette.surface.withValues(alpha: 0.92),
      palette.background,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: palette.isLight ? 0.08 : 0.2),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: palette.primary.withValues(
              alpha: palette.isLight ? 0.05 : 0.1,
            ),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Material(
          color: shellColor,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                _PreviewHandle(color: palette.textHint.withValues(alpha: 0.34)),
                _PreviewHeader(
                  name: name,
                  avatarUrl: avatar,
                  isGroup: conversation.type != 'DIRECT',
                  unreadCount: conversation.unreadCount,
                  unreadMentionCount: conversation.unreadMentionCount,
                ),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: bodyColor,
                      border: Border(
                        top: BorderSide(
                          color: palette.surfaceVariant.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                    child: messagesAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (error, _) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Không thể tải xem trước',
                            style: TextStyle(color: palette.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      data: (messages) => _PreviewMessageList(
                        messages: messages,
                        currentUserId: currentUserId,
                      ),
                    ),
                  ),
                ),
                _PreviewFooter(onOpenChat: onOpenChat),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _conversationName(LocalConversation conversation) {
    if (conversation.type == 'DIRECT') {
      return conversation.otherMemberName ?? 'Unknown';
    }
    return conversation.name ?? 'Group';
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({
    required this.name,
    required this.avatarUrl,
    required this.isGroup,
    required this.unreadCount,
    required this.unreadMentionCount,
  });

  final String name;
  final String? avatarUrl;
  final bool isGroup;
  final int unreadCount;
  final int unreadMentionCount;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final unreadLabel = _unreadLabel();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.fromLTRB(16, 16, 10, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              palette.primary.withValues(alpha: palette.isLight ? 0.12 : 0.18),
              palette.surface,
            ),
            palette.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: palette.primary.withValues(
            alpha: palette.isLight ? 0.12 : 0.18,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: palette.primary.withValues(alpha: 0.22),
              ),
            ),
            child: ChatAvatar(
              radius: 24,
              displayName: name,
              imageUrl: avatarUrl,
              isGroup: isGroup,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PreviewInfoChip(
                      icon: Icons.visibility_outlined,
                      label: 'Xem nhanh',
                    ),
                    _PreviewInfoChip(
                      icon: unreadCount > 0
                          ? Icons.mark_chat_unread_rounded
                          : Icons.schedule_rounded,
                      label: unreadLabel,
                      emphasized: unreadCount > 0 || unreadMentionCount > 0,
                    ),
                    if (unreadMentionCount > 0)
                      const _PreviewInfoChip(
                        icon: Icons.alternate_email_rounded,
                        label: 'Có nhắc đến bạn',
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Mở nhanh để xem nội dung gần đây, chưa làm mất trạng thái chưa đọc.',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: palette.surface.withValues(alpha: 0.78),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              tooltip: 'Đóng',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, color: palette.textSecondary),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  String _unreadLabel() {
    if (unreadCount <= 0 && unreadMentionCount <= 0) {
      return 'Chưa đánh dấu đã đọc';
    }
    final countLabel = unreadCount > 99 ? '99+' : '$unreadCount';
    if (unreadMentionCount > 0) {
      return '$countLabel tin chưa đọc';
    }
    return '$countLabel tin chưa đọc';
  }
}

class _PreviewHandle extends StatelessWidget {
  const _PreviewHandle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 5,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _PreviewInfoChip extends StatelessWidget {
  const _PreviewInfoChip({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final chipColor = emphasized
        ? palette.primary.withValues(alpha: palette.isLight ? 0.14 : 0.2)
        : palette.surface.withValues(alpha: 0.72);
    final iconColor = emphasized ? palette.primary : palette.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: emphasized
              ? palette.primary.withValues(alpha: 0.22)
              : palette.surfaceVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: emphasized ? palette.textPrimary : palette.textSecondary,
              fontSize: 12,
              fontWeight: emphasized ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewMessageList extends StatelessWidget {
  const _PreviewMessageList({
    required this.messages,
    required this.currentUserId,
  });

  final List<LocalMessage> messages;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    if (messages.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: palette.surfaceVariant.withValues(alpha: 0.65),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                color: palette.textHint,
                size: 26,
              ),
              const SizedBox(height: 10),
              Text(
                'Chưa có tin nhắn để xem trước',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Khi cuộc trò chuyện có nội dung mới, phần xem nhanh sẽ hiện ở đây.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scrollbar(
      thumbVisibility: messages.length > 3,
      radius: const Radius.circular(999),
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        itemCount: messages.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final message = messages[index];
          if (message.type == 'system') {
            return _SystemPreviewMessage(
              text: _previewTextForMessage(message),
              timeLabel: _formatPreviewTime(message.createdAt),
            );
          }

          final isMine =
              currentUserId != null && message.senderId == currentUserId;
          final bubbleColor = isMine
              ? Color.alphaBlend(
                  palette.primary.withValues(
                    alpha: palette.isLight ? 0.18 : 0.22,
                  ),
                  palette.surface,
                )
              : palette.surface;
          final messageIcon = _previewIconForMessageType(message.type);

          return Column(
            crossAxisAlignment: isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Align(
                alignment: isMine
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isMine
                            ? palette.primary.withValues(alpha: 0.18)
                            : palette.surfaceVariant.withValues(alpha: 0.72),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: palette.isLight ? 0.04 : 0.08,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (messageIcon != null) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Icon(
                                messageIcon,
                                size: 16,
                                color: isMine
                                    ? palette.primary
                                    : palette.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              _previewTextForMessage(message),
                              style: TextStyle(
                                color: palette.textPrimary,
                                height: 1.42,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  isMine
                      ? 'Bạn • ${_formatPreviewTime(message.createdAt)}'
                      : _formatPreviewTime(message.createdAt),
                  style: TextStyle(
                    color: palette.textHint,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SystemPreviewMessage extends StatelessWidget {
  const _SystemPreviewMessage({required this.text, required this.timeLabel});

  final String text;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: palette.surface.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: palette.surfaceVariant.withValues(alpha: 0.72),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: palette.textSecondary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            timeLabel,
            style: TextStyle(
              color: palette.textHint,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewFooter extends StatelessWidget {
  const _PreviewFooter({required this.onOpenChat});

  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.98),
        border: Border(
          top: BorderSide(
            color: palette.surfaceVariant.withValues(alpha: 0.75),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: palette.primary.withValues(
                alpha: palette.isLight ? 0.08 : 0.12,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: palette.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.visibility_outlined,
                    size: 16,
                    color: palette.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bạn đang xem nhanh, trạng thái chưa đọc vẫn được giữ nguyên.',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Đóng'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.textPrimary,
                    side: BorderSide(
                      color: palette.surfaceVariant.withValues(alpha: 0.9),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: onOpenChat,
                  icon: const Icon(Icons.arrow_outward_rounded, size: 18),
                  label: const Text('Mở chat'),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.isLight
                        ? Colors.white
                        : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

IconData? _previewIconForMessageType(String type) {
  return switch (type) {
    'image' => Icons.image_outlined,
    'album' => Icons.collections_outlined,
    'voice' => Icons.mic_none_rounded,
    'video' => Icons.videocam_outlined,
    'file' => Icons.attach_file_rounded,
    _ => null,
  };
}

String _formatPreviewTime(DateTime timestamp) {
  final hour = timestamp.hour.toString().padLeft(2, '0');
  final minute = timestamp.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _previewTextForMessage(LocalMessage message) {
  if (message.deletedAt != null) {
    return 'Tin nhắn đã được thu hồi';
  }

  if (message.type == 'system') {
    return _systemPreviewText(message);
  }

  final content = message.content?.trim() ?? '';
  return switch (message.type) {
    'image' => content.isEmpty ? 'Ảnh' : 'Ảnh - $content',
    'album' => content.isEmpty ? 'Nhiều ảnh' : 'Nhiều ảnh - $content',
    'voice' => 'Tin nhắn thoại',
    'video' => content.isEmpty ? 'Video' : 'Video - $content',
    'file' => content.isEmpty ? 'Tệp đính kèm' : 'Tệp đính kèm - $content',
    _ => content.isEmpty ? encryptedMessagePreviewPlaceholder : content,
  };
}

String _systemPreviewText(LocalMessage message) {
  final content = message.content ?? '';
  Map<String, dynamic>? metadata;
  if (message.metadata != null) {
    try {
      metadata = jsonDecode(message.metadata!) as Map<String, dynamic>;
    } catch (_) {
      metadata = null;
    }
  }

  final action = metadata?['action'] as String? ?? content;
  final actorName = metadata?['actor_name'] as String? ?? '';
  final memberName = metadata?['member_name'] as String? ?? '';
  final newName = metadata?['new_name'] as String? ?? '';

  return switch (action) {
    'created_group' => '$actorName đã tạo nhóm',
    'added_member' => '$actorName đã thêm $memberName',
    'removed_member' => '$actorName đã xóa $memberName',
    'left_group' => '$actorName đã rời nhóm',
    'renamed_group' => '$actorName đã đổi tên nhóm thành $newName',
    'changed_avatar' => '$actorName đã đổi ảnh nhóm',
    'pinned_message' => '$actorName đã ghim một tin nhắn',
    'unpinned_message' => '$actorName đã bỏ ghim một tin nhắn',
    'unpinned_all_messages' => '$actorName đã bỏ ghim tất cả tin nhắn',
    'chat_reminder_created' => 'Đã tạo nhắc hẹn',
    'chat_reminder_updated' => 'Đã cập nhật nhắc hẹn',
    'chat_reminder_cancelled' => 'Đã hủy nhắc hẹn',
    'chat_reminder_fired' => 'Nhắc hẹn đến giờ',
    _ => content.isEmpty ? 'Hoạt động mới' : content,
  };
}
