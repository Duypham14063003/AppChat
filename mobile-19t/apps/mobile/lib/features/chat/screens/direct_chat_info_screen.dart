import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/providers/auth_notifier.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../../../shared/widgets/optimized_network_image.dart';
import '../data/chat_avatar_resolver.dart';
import '../providers/chat_providers.dart';
import '../providers/conversation_assets_provider.dart';
import 'image_viewer_screen.dart';
import 'video_player_screen.dart';

enum _DirectInfoTab { contact, media, files, links }

extension on _DirectInfoTab {
  String get label => switch (this) {
    _DirectInfoTab.contact => 'Liên hệ',
    _DirectInfoTab.media => 'Media',
    _DirectInfoTab.files => 'Files',
    _DirectInfoTab.links => 'Links',
  };
}

class _DirectInfoMediaItem {
  const _DirectInfoMediaItem({
    required this.type,
    required this.source,
    this.thumbnail,
  });

  final String type;
  final String source;
  final String? thumbnail;
}

class DirectChatMemberInfo {
  const DirectChatMemberInfo({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.email,
    this.phoneNumber,
    this.department,
    this.jobTitle,
    this.lastSeenAt,
  });

  final String userId;
  final String name;
  final String? avatarUrl;
  final String? email;
  final String? phoneNumber;
  final String? department;
  final String? jobTitle;
  final DateTime? lastSeenAt;
}

final directChatMemberInfoProvider =
    FutureProvider.family<DirectChatMemberInfo?, String>((
      ref,
      conversationId,
    ) async {
      try {
        final repo = ref.read(chatRepositoryProvider);
        final authState = ref.read(authNotifierProvider);
        final currentUserId = authState.valueOrNull?.user?.id ?? '';
        final result = await repo.getConversation(conversationId);

        if ((result['type'] as String? ?? 'DIRECT') != 'DIRECT') {
          return null;
        }

        final members = result['members'] as List? ?? [];
        for (final item in members) {
          final member = item as Map<String, dynamic>;
          final user = member['user'] as Map<String, dynamic>?;
          if (user == null) continue;
          final userId = _readString(user, const ['id']) ?? '';
          if (userId.isEmpty || userId == currentUserId) continue;

          final lastSeenRaw =
              _readString(user, const ['last_seen_at']) ??
              _readString(member, const ['last_seen_at']);

          return DirectChatMemberInfo(
            userId: userId,
            name: _readString(user, const ['name', 'full_name']) ?? 'Liên hệ',
            avatarUrl: resolveChatAvatarUrl(
              _readString(user, const ['avatar_url', 'avatarUrl']),
            ),
            email: _readString(user, const ['email']),
            phoneNumber: _readString(user, const [
              'phone_number',
              'phoneNumber',
            ]),
            department: _readString(user, const [
              'department_name',
              'department',
            ]),
            jobTitle: _readString(user, const ['job_title', 'jobTitle']),
            lastSeenAt: lastSeenRaw == null
                ? null
                : DateTime.tryParse(lastSeenRaw)?.toLocal(),
          );
        }
      } catch (_) {}

      return null;
    });

String? _readString(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

class DirectChatInfoScreen extends ConsumerStatefulWidget {
  const DirectChatInfoScreen({
    super.key,
    required this.conversationId,
    this.asPanel = false,
    this.onClose,
  });

  final String conversationId;
  final bool asPanel;
  final VoidCallback? onClose;

  @override
  ConsumerState<DirectChatInfoScreen> createState() =>
      _DirectChatInfoScreenState();
}

class _DirectChatInfoScreenState extends ConsumerState<DirectChatInfoScreen> {
  final ScrollController _scrollController = ScrollController();
  _DirectInfoTab _selectedTab = _DirectInfoTab.contact;
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final shouldShow = _scrollController.offset > 420;
    if (shouldShow == _showScrollToTop) return;
    setState(() => _showScrollToTop = shouldShow);
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _refresh(WidgetRef ref) {
    ref.invalidate(conversationDetailProvider(widget.conversationId));
    ref.invalidate(directChatMemberInfoProvider(widget.conversationId));
    ref.invalidate(conversationMediaListProvider(widget.conversationId));
    ref.invalidate(conversationFilesListProvider(widget.conversationId));
    ref.invalidate(conversationLinksListProvider(widget.conversationId));
    ref.invalidate(conversationAssetsSummaryProvider(widget.conversationId));
    return Future<void>.value();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final conversationAsync = ref.watch(
      conversationDetailProvider(widget.conversationId),
    );
    final memberAsync = ref.watch(
      directChatMemberInfoProvider(widget.conversationId),
    );
    final mediaAsync = ref.watch(
      conversationMediaListProvider(widget.conversationId),
    );
    final filesAsync = ref.watch(
      conversationFilesListProvider(widget.conversationId),
    );
    final linksAsync = ref.watch(
      conversationLinksListProvider(widget.conversationId),
    );
    final summaryAsync = ref.watch(
      conversationAssetsSummaryProvider(widget.conversationId),
    );
    final backgroundColor = palette.background;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.asPanel,
        leading: widget.asPanel
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Đóng',
                onPressed: widget.onClose ?? () => Navigator.maybePop(context),
              )
            : null,
        title: const Text('Thông tin trò chuyện'),
        centerTitle: true,
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: conversationAsync.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 180),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (error, stackTrace) => _StateMessageView(
            icon: Icons.error_outline,
            message: 'Không tải được thông tin cuộc trò chuyện',
            actionLabel: 'Thử lại',
            onPressed: () => ref.invalidate(
              conversationDetailProvider(widget.conversationId),
            ),
          ),
          data: (conv) {
            if (conv == null) {
              return _StateMessageView(
                icon: Icons.chat_bubble_outline,
                message: 'Không tìm thấy cuộc trò chuyện',
                actionLabel: 'Quay lại',
                onPressed: () => context.pop(),
              );
            }

            final member = memberAsync.valueOrNull;
            final displayName =
                member?.name ?? conv.otherMemberName ?? conv.name ?? 'Liên hệ';
            final displayAvatar =
                member?.avatarUrl ?? conv.otherMemberAvatar ?? conv.avatarUrl;
            final lastSeen = member?.lastSeenAt ?? conv.otherMemberLastSeenAt;
            final isOnline =
                lastSeen != null &&
                DateTime.now().difference(lastSeen).inMinutes < 2;
            final mediaItems = mediaAsync.valueOrNull ?? [];
            final fileItems = filesAsync.valueOrNull ?? [];
            final linkItems = linksAsync.valueOrNull ?? [];
            final summary = summaryAsync.valueOrNull;

            return Stack(
              children: [
                ListView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                  children: [
                    _HeaderSection(
                      name: displayName,
                      avatarUrl: displayAvatar,
                      lastSeenLabel: _formatLastSeen(lastSeen),
                    ),
                    const SizedBox(height: 28),
                    _DirectTabStrip(
                      selectedTab: _selectedTab,
                      onSelected: (tab) => setState(() => _selectedTab = tab),
                    ),
                    const SizedBox(height: 22),
                    if (_selectedTab == _DirectInfoTab.contact) ...[
                      _InfoSection(
                        title: 'Thông tin liên hệ',
                        rows: [
                          _InfoRowData(
                            label: 'Trạng thái',
                            value: isOnline
                                ? 'Đang hoạt động'
                                : _formatLastSeen(lastSeen),
                          ),
                          _InfoRowData(
                            label: 'Email',
                            value: member?.email ?? 'Chưa cập nhật',
                          ),
                          _InfoRowData(
                            label: 'Số điện thoại',
                            value: member?.phoneNumber ?? 'Chưa cập nhật',
                          ),
                          _InfoRowData(
                            label: 'Chức vụ',
                            value: member?.jobTitle ?? 'Chưa cập nhật',
                          ),
                          _InfoRowData(
                            label: 'Phòng ban',
                            value: member?.department ?? 'Chưa cập nhật',
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      _InfoSection(
                        title: 'Cuộc trò chuyện',
                        rows: [
                          const _InfoRowData(
                            label: 'Loại',
                            value: 'Chat cá nhân',
                          ),
                          _InfoRowData(
                            label: 'Tạo lúc',
                            value: _formatDateTime(conv.createdAt),
                          ),
                          _InfoRowData(
                            label: 'Mã',
                            value: widget.conversationId,
                          ),
                        ],
                      ),
                    ] else if (_selectedTab == _DirectInfoTab.media) ...[
                      _DirectAssetCard(
                        title: 'Media',
                        countLabel: summary != null
                            ? '${summary.mediaCount} items'
                            : '${mediaItems.length} items',
                        child: mediaAsync.when(
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          error: (e, _) => Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text('Lỗi: $e'),
                            ),
                          ),
                          data: (items) {
                            if (items.isEmpty) {
                              return const _DirectEmptyState(
                                message: 'Chưa có ảnh hoặc video',
                              );
                            }
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: items.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: 1,
                                  ),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                final firstUrl = item.urls.isNotEmpty
                                    ? item.urls.first
                                    : '';
                                return RepaintBoundary(
                                  key: ValueKey(
                                    'direct_media_${item.type}_${item.createdAt.millisecondsSinceEpoch}_$firstUrl',
                                  ),
                                  child: _DirectMediaTile(
                                    item: _DirectInfoMediaItem(
                                      type: item.type,
                                      source: firstUrl,
                                      thumbnail: item.thumbnail,
                                    ),
                                    onTap: () {
                                      if (item.type == 'video') {
                                        _openVideoPlayer(context, firstUrl);
                                        return;
                                      }
                                      final allImageUrls = items
                                          .where(
                                            (m) =>
                                                m.type == 'image' ||
                                                m.type == 'album',
                                          )
                                          .expand((m) => m.urls)
                                          .toList();
                                      final imageIndex = allImageUrls.indexOf(
                                        firstUrl,
                                      );
                                      _openImageViewer(
                                        context,
                                        allImageUrls,
                                        imageIndex < 0 ? 0 : imageIndex,
                                      );
                                    },
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ] else if (_selectedTab == _DirectInfoTab.files) ...[
                      _DirectAssetCard(
                        title: 'Files',
                        countLabel: '${fileItems.length} items',
                        child: fileItems.isEmpty
                            ? const _DirectEmptyState(
                                message: 'Chưa có file nào',
                              )
                            : Column(
                                children: fileItems
                                    .map(
                                      (item) => _DirectActionTile(
                                        icon: Icons.attach_file_rounded,
                                        title: item.name,
                                        subtitle: [
                                          if ((item.mimeType ?? '').isNotEmpty)
                                            item.mimeType!,
                                          if (_formatFileSize(
                                            item.size,
                                          ).isNotEmpty)
                                            _formatFileSize(item.size),
                                          _formatDateTime(item.createdAt),
                                        ].join(' • '),
                                        onTap: () =>
                                            _openExternalAttachment(item.url),
                                      ),
                                    )
                                    .toList(),
                              ),
                      ),
                    ] else ...[
                      _DirectAssetCard(
                        title: 'Links',
                        countLabel: '${linkItems.length} items',
                        child: linkItems.isEmpty
                            ? const _DirectEmptyState(
                                message: 'Chưa có liên kết nào',
                              )
                            : Column(
                                children: linkItems
                                    .map(
                                      (item) => _DirectActionTile(
                                        icon: Icons.link_rounded,
                                        title: item.content,
                                        subtitle:
                                            '${item.senderName} • ${_formatDateTime(item.createdAt)}',
                                        onTap: () =>
                                            _openExternalAttachment(item.url),
                                      ),
                                    )
                                    .toList(),
                              ),
                      ),
                    ],
                  ],
                ),
                Positioned(
                  right: 20,
                  bottom: 28,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 180),
                    offset: _showScrollToTop
                        ? Offset.zero
                        : const Offset(0, 1.4),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: _showScrollToTop ? 1 : 0,
                      child: IgnorePointer(
                        ignoring: !_showScrollToTop,
                        child: FloatingActionButton.small(
                          heroTag: 'direct-info-scroll-top',
                          onPressed: _scrollToTop,
                          backgroundColor: palette.primary,
                          foregroundColor: palette.background,
                          child: const Icon(Icons.keyboard_arrow_up_rounded),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openImageViewer(
    BuildContext context,
    List<String> urls,
    int initialIndex,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ImageViewerScreen(imageUrls: urls, initialIndex: initialIndex),
      ),
    );
  }

  void _openVideoPlayer(BuildContext context, String videoUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VideoPlayerScreen(videoUrl: videoUrl)),
    );
  }

  Future<void> _openExternalAttachment(String? url) async {
    if (url == null || url.isEmpty) return;
    final resolved = url.startsWith('/uploads')
        ? '${AppConfig.instance.apiUrl}$url'
        : url;
    final uri = Uri.tryParse(resolved);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

class _StateMessageView extends StatelessWidget {
  const _StateMessageView({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      children: [
        const SizedBox(height: 120),
        Icon(icon, size: 36, color: _secondaryTextColor(context)),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: _secondaryTextColor(context), fontSize: 15),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton(onPressed: onPressed, child: Text(actionLabel)),
        ),
      ],
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.name,
    required this.avatarUrl,
    required this.lastSeenLabel,
  });

  final String name;
  final String? avatarUrl;
  final String lastSeenLabel;

  @override
  Widget build(BuildContext context) {
    final accentColor = _accentColor(context);

    return Row(
      children: [
        _MemberAvatar(
          name: name,
          avatarUrl: avatarUrl,
          accentColor: accentColor,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _primaryTextColor(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      lastSeenLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _secondaryTextColor(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({
    required this.name,
    required this.avatarUrl,
    required this.accentColor,
  });

  final String name;
  final String? avatarUrl;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 34,
      backgroundColor: accentColor.withValues(alpha: 0.12),
      foregroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
      child: Text(
        _initials(name),
        style: TextStyle(
          color: accentColor,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';

    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words.first[0]}${words.last[0]}'.toUpperCase();
    }

    return words.first[0].toUpperCase();
  }
}

class _DirectTabStrip extends StatelessWidget {
  const _DirectTabStrip({required this.selectedTab, required this.onSelected});

  final _DirectInfoTab selectedTab;
  final ValueChanged<_DirectInfoTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _separatorColor(context)),
      ),
      child: Row(
        children: _DirectInfoTab.values.map((tab) {
          final selected = tab == selectedTab;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? _accentColor(context).withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tab.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? _accentColor(context)
                        : _secondaryTextColor(context),
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DirectAssetCard extends StatelessWidget {
  const _DirectAssetCard({
    required this.title,
    required this.countLabel,
    required this.child,
  });

  final String title;
  final String countLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _separatorColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: _primaryTextColor(context),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            countLabel,
            style: TextStyle(color: _secondaryTextColor(context), fontSize: 13),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DirectEmptyState extends StatelessWidget {
  const _DirectEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: _secondaryTextColor(context), fontSize: 14),
        ),
      ),
    );
  }
}

class _DirectMediaTile extends StatelessWidget {
  const _DirectMediaTile({required this.item, required this.onTap});

  final _DirectInfoMediaItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final preview = item.thumbnail ?? item.source;
    final resolved = preview.startsWith('/uploads')
        ? '${AppConfig.instance.apiUrl}$preview'
        : preview;
    final isNetworkSource =
        resolved.startsWith('http') || resolved.startsWith('blob:');

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: palette.surfaceVariant,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!kIsWeb && !isNetworkSource)
                Image.file(
                  File(preview),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      _DirectMediaFallback(isVideo: item.type == 'video'),
                )
              else
                OptimizedNetworkImage(
                  key: ValueKey('direct_media_thumb_${item.type}_$resolved'),
                  imageUrl: resolved,
                  fit: BoxFit.cover,
                  memCacheWidth: 320,
                  memCacheHeight: 320,
                  errorWidget: _DirectMediaFallback(
                    isVideo: item.type == 'video',
                  ),
                ),
              if (item.type == 'video')
                Container(
                  color: Colors.black.withValues(alpha: 0.28),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectMediaFallback extends StatelessWidget {
  const _DirectMediaFallback({required this.isVideo});

  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.appPalette.surfaceVariant,
      alignment: Alignment.center,
      child: Icon(
        isVideo ? Icons.videocam_rounded : Icons.image_outlined,
        color: context.appPalette.textHint,
        size: 28,
      ),
    );
  }
}

class _DirectActionTile extends StatelessWidget {
  const _DirectActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _accentColor(context).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: _accentColor(context)),
      ),
      title: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: _primaryTextColor(context),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: _secondaryTextColor(context), fontSize: 12),
      ),
      trailing: Icon(
        Icons.open_in_new_rounded,
        size: 18,
        color: _secondaryTextColor(context),
      ),
      onTap: onTap,
    );
  }
}

class _InfoRowData {
  const _InfoRowData({required this.label, required this.value});

  final String label;
  final String value;
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.rows});

  final String title;
  final List<_InfoRowData> rows;

  @override
  Widget build(BuildContext context) {
    final separatorColor = _separatorColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: _primaryTextColor(context),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        for (var index = 0; index < rows.length; index++) ...[
          if (index > 0)
            Divider(height: 1, thickness: 1, color: separatorColor),
          _InfoRow(row: rows[index]),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.row});

  final _InfoRowData row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              row.label,
              style: TextStyle(
                color: _secondaryTextColor(context),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              row.value,
              style: TextStyle(
                color: _primaryTextColor(context),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _accentColor(BuildContext context) {
  return context.appPalette.primary;
}

Color _primaryTextColor(BuildContext context) {
  return context.appPalette.textPrimary;
}

Color _secondaryTextColor(BuildContext context) {
  return context.appPalette.textSecondary;
}

Color _separatorColor(BuildContext context) {
  return Theme.of(context).dividerColor;
}

String _formatLastSeen(DateTime? lastSeenAt) {
  if (lastSeenAt == null) return 'Không có trạng thái';

  final diff = DateTime.now().difference(lastSeenAt);
  if (diff.inMinutes < 2) return 'Đang hoạt động';
  if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
  if (diff.inHours < 24) return '${diff.inHours} giờ trước';
  return _formatDate(lastSeenAt);
}

String _formatDateTime(DateTime dateTime) {
  final d = dateTime.day.toString().padLeft(2, '0');
  final m = dateTime.month.toString().padLeft(2, '0');
  final y = dateTime.year.toString().padLeft(4, '0');
  final h = dateTime.hour.toString().padLeft(2, '0');
  final min = dateTime.minute.toString().padLeft(2, '0');
  return '$d/$m/$y $h:$min';
}

String _formatDate(DateTime dateTime) {
  final d = dateTime.day.toString().padLeft(2, '0');
  final m = dateTime.month.toString().padLeft(2, '0');
  final y = dateTime.year.toString().padLeft(4, '0');
  return '$d/$m/$y';
}

String _formatFileSize(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  const units = ['B', 'KB', 'MB', 'GB'];
  double size = bytes.toDouble();
  var unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }
  final precision = size >= 100 || unitIndex == 0 ? 0 : 1;
  return '${size.toStringAsFixed(precision)} ${units[unitIndex]}';
}
