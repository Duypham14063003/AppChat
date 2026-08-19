import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_avatar.dart';

class GlobalBookmarkedMessagesScreen extends ConsumerStatefulWidget {
  const GlobalBookmarkedMessagesScreen({super.key});

  @override
  ConsumerState<GlobalBookmarkedMessagesScreen> createState() =>
      _GlobalBookmarkedMessagesScreenState();
}

class _GlobalBookmarkedMessagesScreenState
    extends ConsumerState<GlobalBookmarkedMessagesScreen> {
  GlobalBookmarkFilter _filter = GlobalBookmarkFilter.all;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final inboxAsync = ref.watch(globalBookmarkedMessagesProvider(_filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tin nhắn đã lưu', style: TextStyle(fontSize: 16)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: palette.surfaceVariant),
        ),
      ),
      body: Column(
        children: [
          _BookmarkFilterBar(
            selectedFilter: _filter,
            onSelected: (filter) {
              if (_filter == filter) return;
              setState(() => _filter = filter);
            },
          ),
          Expanded(
            child: inboxAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  'Không thể tải tin nhắn đã lưu',
                  style: TextStyle(color: palette.textSecondary),
                ),
              ),
              data: (state) {
                if (state.items.isEmpty) {
                  return _EmptyInbox(filter: _filter);
                }

                return RefreshIndicator(
                  onRefresh: () => ref
                      .read(globalBookmarkedMessagesProvider(_filter).notifier)
                      .refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: state.items.length + (state.hasMore ? 1 : 0),
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: palette.surfaceVariant),
                    itemBuilder: (context, index) {
                      if (index >= state.items.length) {
                        return _LoadMoreTile(
                          isLoading: state.isLoadingMore,
                          onPressed: () => ref
                              .read(
                                globalBookmarkedMessagesProvider(
                                  _filter,
                                ).notifier,
                              )
                              .loadMore(),
                        );
                      }

                      final bookmark = state.items[index];
                      return _GlobalBookmarkedMessageTile(
                        bookmark: bookmark,
                        onTap: () => context.go(
                          '/chat/${bookmark.convId}?messageId=${bookmark.messageId}',
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BookmarkFilterBar extends StatelessWidget {
  const _BookmarkFilterBar({
    required this.selectedFilter,
    required this.onSelected,
  });

  final GlobalBookmarkFilter selectedFilter;
  final ValueChanged<GlobalBookmarkFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Text(
            'Hiển thị',
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          PopupMenuButton<GlobalBookmarkFilter>(
            onSelected: onSelected,
            color: palette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: palette.surfaceVariant),
            ),
            itemBuilder: (context) => GlobalBookmarkFilter.values
                .map((filter) {
                  final isSelected = filter == selectedFilter;
                  return PopupMenuItem<GlobalBookmarkFilter>(
                    value: filter,
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          size: 18,
                          color: isSelected
                              ? palette.primary
                              : palette.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          filter.label,
                          style: TextStyle(color: palette.textPrimary),
                        ),
                      ],
                    ),
                  );
                })
                .toList(growable: false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.surfaceVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.filter_list_rounded,
                    size: 18,
                    color: palette.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    selectedFilter.label,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: palette.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobalBookmarkedMessageTile extends StatelessWidget {
  const _GlobalBookmarkedMessageTile({
    required this.bookmark,
    required this.onTap,
  });

  final BookmarkedMessageData bookmark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final conversationName =
        bookmark.conversationName?.trim().isNotEmpty == true
        ? bookmark.conversationName!
        : 'Cuộc trò chuyện';
    final messagePreview = bookmark.messageContent?.trim().isNotEmpty == true
        ? bookmark.messageContent!
        : 'Tin nhắn không có nội dung';
    final senderName = bookmark.senderName?.trim().isNotEmpty == true
        ? bookmark.senderName!
        : 'Không rõ người gửi';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChatAvatar(
              radius: 22,
              displayName: conversationName,
              imageUrl: bookmark.conversationAvatarUrl,
              isGroup: bookmark.isGroupConversation,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          conversationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(bookmark.markedAt),
                        style: TextStyle(color: palette.textHint, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bookmark.isGroupConversation ? '$senderName:' : senderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    messagePreview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.textPrimary, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.bookmark_rounded,
                        size: 14,
                        color: palette.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Đã lưu',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes}p';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}

class _LoadMoreTile extends StatelessWidget {
  const _LoadMoreTile({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Center(
        child: isLoading
            ? const CircularProgressIndicator(strokeWidth: 2)
            : TextButton(
                onPressed: onPressed,
                child: Text(
                  'Tải thêm',
                  style: TextStyle(color: palette.primary),
                ),
              ),
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox({required this.filter});

  final GlobalBookmarkFilter filter;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final message = switch (filter) {
      GlobalBookmarkFilter.all => 'Bạn chưa lưu tin nhắn nào',
      GlobalBookmarkFilter.direct => 'Chưa có tin nhắn đã lưu trong trò chuyện',
      GlobalBookmarkFilter.group => 'Chưa có tin nhắn đã lưu trong nhóm',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmarks_outlined, size: 42, color: palette.textHint),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
