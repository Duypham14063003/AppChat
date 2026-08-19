import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/theme_color_presets.dart';

const _quickEmojis = ['👍', '❤️', '😂', '😮', '😢', '🔥'];

String? copyableMessageText(LocalMessage message) {
  if (message.type != 'text' || message.deletedAt != null) {
    return null;
  }
  final text = message.content;
  if (text == null || text.trim().isEmpty) {
    return null;
  }
  return text;
}

void showMessageContextMenu({
  required BuildContext context,
  required LocalMessage message,
  required bool isMine,
  required String conversationId,
  required String conversationType,
  required String? userRole,
  required bool isPinned,
  required bool isBookmarked,
  required void Function(String emoji) onReaction,
  required VoidCallback? onPin,
  required VoidCallback? onUnpin,
  required VoidCallback? onBookmark,
  required VoidCallback? onUnbookmark,
  required VoidCallback? onReply,
  required VoidCallback? onCopy,
  required VoidCallback? onForward,
  VoidCallback? onSeenBy,
  VoidCallback? onReminder,
  VoidCallback? onCreatePoc,
  VoidCallback? onEdit,
  VoidCallback? onRecall,
  VoidCallback? onDelete,
}) {
  if (message.type == 'system') return;
  final palette = context.appPalette;
  final copyableText = copyableMessageText(message);

  final canPin =
      conversationType == 'DIRECT' ||
      userRole == 'creator' ||
      userRole == 'admin' ||
      userRole == 'employee';
  final isRecalled = message.deletedAt != null;
  final canEdit =
      isMine &&
      !isRecalled &&
      message.type == 'text' &&
      (message.content?.trim().isNotEmpty ?? false);
  final canRecall = isMine && !isRecalled;

  final isWide = MediaQuery.of(context).size.width >= 768;

  Widget buildMenuContent(BuildContext menuCtx) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Quick reaction row
        _QuickReactionRow(
          onEmojiSelected: (emoji) {
            Navigator.pop(menuCtx);
            onReaction(emoji);
          },
        ),
        Divider(height: 1, color: palette.surfaceVariant),
        // Pin/Unpin
        if (canPin)
          ListTile(
            dense: isWide,
            leading: Text(
              '\u{1F4CC}',
              style: TextStyle(fontSize: 18, color: palette.textPrimary),
            ),
            title: Text(
              isPinned ? 'Bỏ ghim' : 'Ghim tin nhắn',
              style: TextStyle(color: palette.textPrimary),
            ),
            onTap: () {
              Navigator.pop(menuCtx);
              if (isPinned) {
                onUnpin?.call();
              } else {
                onPin?.call();
              }
            },
          ),
        ListTile(
          dense: isWide,
          leading: Icon(
            isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            color: isBookmarked ? palette.primary : palette.textSecondary,
          ),
          title: Text(
            isBookmarked ? 'Bỏ đánh dấu' : 'Đánh dấu tin nhắn',
            style: TextStyle(color: palette.textPrimary),
          ),
          onTap: () {
            Navigator.pop(menuCtx);
            if (isBookmarked) {
              onUnbookmark?.call();
            } else {
              onBookmark?.call();
            }
          },
        ),
        // Reply
        if (onReply != null)
          ListTile(
            dense: isWide,
            leading: Icon(Icons.reply, color: palette.textSecondary),
            title: Text(
              'Trả lời',
              style: TextStyle(color: palette.textPrimary),
            ),
            onTap: () {
              Navigator.pop(menuCtx);
              onReply.call();
            },
          ),
        if (canEdit && onEdit != null)
          ListTile(
            dense: isWide,
            leading: Icon(Icons.edit_outlined, color: palette.textSecondary),
            title: Text('Sửa', style: TextStyle(color: palette.textPrimary)),
            onTap: () {
              Navigator.pop(menuCtx);
              onEdit.call();
            },
          ),
        // Copy
        if (onCopy != null && copyableText != null)
          ListTile(
            dense: isWide,
            leading: Icon(Icons.copy, color: palette.textSecondary),
            title: Text(
              'Sao chép',
              style: TextStyle(color: palette.textPrimary),
            ),
            onTap: () {
              Navigator.pop(menuCtx);
              onCopy.call();
            },
          ),
        // Forward
        if (onForward != null)
          ListTile(
            dense: isWide,
            leading: Icon(Icons.forward, color: palette.textSecondary),
            title: Text(
              'Chuyển tiếp',
              style: TextStyle(color: palette.textPrimary),
            ),
            onTap: () {
              Navigator.pop(menuCtx);
              onForward.call();
            },
          ),
        if (!isRecalled && onSeenBy != null)
          ListTile(
            dense: isWide,
            leading: Icon(
              Icons.visibility_outlined,
              color: palette.textSecondary,
            ),
            title: Text(
              'Đã xem bởi',
              style: TextStyle(color: palette.textPrimary),
            ),
            onTap: () {
              Navigator.pop(menuCtx);
              onSeenBy.call();
            },
          ),
        if (!isRecalled && onReminder != null)
          ListTile(
            dense: isWide,
            leading: Icon(
              Icons.notifications_active_outlined,
              color: palette.textSecondary,
            ),
            title: Text(
              'Nhắc hẹn',
              style: TextStyle(color: palette.textPrimary),
            ),
            onTap: () {
              Navigator.pop(menuCtx);
              onReminder.call();
            },
          ),
        if (!isRecalled && onCreatePoc != null)
          ListTile(
            dense: isWide,
            leading: Icon(Icons.science_outlined, color: palette.textSecondary),
            title: Text(
              'Tạo yêu cầu PoC',
              style: TextStyle(color: palette.textPrimary),
            ),
            onTap: () {
              Navigator.pop(menuCtx);
              onCreatePoc.call();
            },
          ),
        if (canRecall && onRecall != null)
          ListTile(
            dense: isWide,
            leading: Icon(Icons.undo_outlined, color: palette.textSecondary),
            title: Text(
              'Thu hồi',
              style: TextStyle(color: palette.textPrimary),
            ),
            onTap: () {
              Navigator.pop(menuCtx);
              onRecall.call();
            },
          ),
        // Delete (future)
        if (onDelete != null)
          ListTile(
            dense: isWide,
            leading: Icon(Icons.delete_outline, color: palette.textSecondary),
            title: Text('Xóa', style: TextStyle(color: palette.textPrimary)),
            onTap: () {
              Navigator.pop(menuCtx);
              onDelete.call();
            },
          ),
      ],
    );
  }

  if (isWide) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 320,
          child: SingleChildScrollView(child: buildMenuContent(dialogCtx)),
        ),
      ),
    );
  } else {
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) =>
          SafeArea(child: SingleChildScrollView(child: buildMenuContent(ctx))),
    );
  }
}

class _QuickReactionRow extends StatefulWidget {
  final void Function(String emoji) onEmojiSelected;

  const _QuickReactionRow({required this.onEmojiSelected});

  @override
  State<_QuickReactionRow> createState() => _QuickReactionRowState();
}

class _QuickReactionRowState extends State<_QuickReactionRow> {
  bool _showFullPicker = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    if (_showFullPicker) {
      return SizedBox(
        height: 250,
        child: EmojiPicker(
          onEmojiSelected: (_, emoji) => widget.onEmojiSelected(emoji.emoji),
          config: const Config(height: 250, checkPlatformCompatibility: true),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ..._quickEmojis.map(
            (emoji) => GestureDetector(
              onTap: () => widget.onEmojiSelected(emoji),
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _showFullPicker = true),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: palette.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add, size: 20, color: palette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
