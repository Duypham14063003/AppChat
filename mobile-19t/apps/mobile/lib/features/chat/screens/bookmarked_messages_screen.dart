import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../data/encrypted_message_adapter.dart';
import '../providers/chat_providers.dart';

class BookmarkedMessagesListScreen extends ConsumerWidget {
  final String conversationId;
  final bool asDialog;

  const BookmarkedMessagesListScreen({
    super.key,
    required this.conversationId,
    this.asDialog = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appPalette;
    final bookmarksAsync = ref.watch(
      bookmarkedMessagesProvider(conversationId),
    );

    final bodyContent = bookmarksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Error: $e',
          style: TextStyle(color: palette.textSecondary),
        ),
      ),
      data: (bookmarks) {
        if (bookmarks.isEmpty) {
          return Center(
            child: Text(
              'Chưa có tin nhắn nào được đánh dấu',
              style: TextStyle(color: palette.textSecondary),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: bookmarks.length,
          separatorBuilder: (_, _) =>
              Divider(height: 1, color: palette.surfaceVariant),
          itemBuilder: (context, index) {
            final bookmark = bookmarks[index];
            return _BookmarkedMessageTile(
              bookmark: bookmark,
              onTap: () => Navigator.pop(context, bookmark.messageId),
            );
          },
        );
      },
    );

    if (asDialog) {
      return bodyContent;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tin nhắn đã đánh dấu',
          style: TextStyle(fontSize: 16),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: palette.surfaceVariant),
        ),
      ),
      body: bodyContent,
    );
  }
}

class _BookmarkedMessageTile extends StatelessWidget {
  final BookmarkedMessageData bookmark;
  final VoidCallback onTap;

  const _BookmarkedMessageTile({required this.bookmark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final senderName = bookmark.senderName ?? 'Unknown';
    final content =
        bookmark.messageContent ?? encryptedMessagePreviewPlaceholder;
    final markedTime = _formatTime(bookmark.markedAt);

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: palette.surfaceVariant,
        child: Icon(Icons.bookmark_border, color: palette.primary),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              senderName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: palette.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            markedTime,
            style: TextStyle(color: palette.textSecondary, fontSize: 11),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            'Đã đánh dấu',
            style: TextStyle(
              color: palette.textHint,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}';
  }
}
