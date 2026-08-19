import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../data/encrypted_message_adapter.dart';

class ReplyPreviewBar extends StatelessWidget {
  final LocalMessage message;
  final String senderName;
  final Color? senderNameColor;
  final VoidCallback onClose;

  const ReplyPreviewBar({
    super.key,
    required this.message,
    required this.senderName,
    this.senderNameColor,
    required this.onClose,
  });

  String get _contentPreview {
    switch (message.type) {
      case 'image':
        return 'Ảnh';
      case 'album':
        return 'Ảnh';
      case 'video':
        return 'Video';
      case 'voice':
        return 'Tin nhắn thoại';
      default:
        return (message.content?.isNotEmpty ?? false)
            ? message.content!
            : encryptedMessagePreviewPlaceholder;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.surfaceVariant)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: palette.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  senderName,
                  style: TextStyle(
                    color: senderNameColor ?? palette.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _contentPreview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: palette.textSecondary),
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
