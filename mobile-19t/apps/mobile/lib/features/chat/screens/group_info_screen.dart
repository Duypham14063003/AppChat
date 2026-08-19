import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:drift/drift.dart' show Value;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/optimized_network_image.dart';
import '../../auth/providers/auth_notifier.dart';
import '../data/chat_avatar_resolver.dart';
import '../providers/chat_providers.dart';
import '../providers/conversation_assets_provider.dart';
import '../widgets/chat_avatar.dart';
import 'contact_picker_screen.dart';
import 'image_viewer_screen.dart';
import 'video_player_screen.dart';

enum _GroupInfoTab { members, media, files, links }

extension on _GroupInfoTab {
  String get label => switch (this) {
    _GroupInfoTab.members => 'Members',
    _GroupInfoTab.media => 'Media',
    _GroupInfoTab.files => 'Files',
    _GroupInfoTab.links => 'Links',
  };
}

class _GroupInfoMediaItem {
  const _GroupInfoMediaItem({
    required this.type,
    required this.source,
    required this.createdAt,
    this.thumbnail,
    this.caption,
  });

  final String type;
  final String source;
  final DateTime createdAt;
  final String? thumbnail;
  final String? caption;
}

class GroupInfoScreen extends ConsumerStatefulWidget {
  const GroupInfoScreen({
    super.key,
    required this.conversationId,
    this.asPanel = false,
    this.onClose,
  });

  final String conversationId;
  final bool asPanel;
  final VoidCallback? onClose;

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  bool _isLoading = false;
  _GroupInfoTab _selectedTab = _GroupInfoTab.members;
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  Color _loadingScrimColor(BuildContext context) {
    final palette = context.appPalette;
    return palette.textPrimary.withValues(alpha: palette.isLight ? 0.12 : 0.28);
  }

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
    final shouldShow = _scrollController.offset > 520;
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

  void _refreshGroupData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ref.invalidate(conversationDetailProvider(widget.conversationId));
      ref.invalidate(conversationMembersProvider(widget.conversationId));
      ref.invalidate(chatListProvider);
    });
  }

  Future<void> _updateLocalConversation({
    String? name,
    String? avatarUrl,
  }) async {
    final dao = ref.read(chatDaoProvider);
    await dao.updateConversation(
      widget.conversationId,
      LocalConversationsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        avatarUrl: avatarUrl != null ? Value(avatarUrl) : const Value.absent(),
      ),
    );
  }

  Future<void> _showRenameDialog(String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final palette = ctx.appPalette;
        return AlertDialog(
          backgroundColor: palette.surface,
          title: Text(
            'Đổi tên nhóm',
            style: AppTypography.titleLarge.copyWith(
              color: palette.textPrimary,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: AppTypography.bodyLarge.copyWith(color: palette.textPrimary),
            decoration: InputDecoration(
              hintText: 'Nhập tên nhóm mới',
              hintStyle: TextStyle(color: palette.textHint),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (newName == null || newName.isEmpty || newName == currentName) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(chatRepositoryProvider);
      final result = await repo.updateConversation(
        widget.conversationId,
        name: newName,
      );
      await _updateLocalConversation(
        name: (result['name'] as String?) ?? newName,
      );
      _refreshGroupData();
      if (mounted) {
        showTopSnackBar(context, message: 'Đã đổi tên nhóm');
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, message: 'Không thể đổi tên nhóm: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changeGroupAvatar() async {
    if (_isLoading) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (image == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(chatRepositoryProvider);
      final uploaded = await repo.uploadImages([image]);
      if (uploaded.isEmpty) {
        throw StateError('Upload ảnh không trả về dữ liệu');
      }

      final uploadedUrl = uploaded.first['url'] as String?;
      if (uploadedUrl == null || uploadedUrl.trim().isEmpty) {
        throw StateError('Không nhận được URL ảnh từ server');
      }

      final result = await repo.updateConversation(
        widget.conversationId,
        avatarUrl: uploadedUrl,
      );
      await _updateLocalConversation(
        avatarUrl: resolveChatAvatarUrl(
          (result['avatar_url'] as String?) ?? uploadedUrl,
        ),
      );
      _refreshGroupData();

      if (mounted) {
        showTopSnackBar(context, message: 'Đã cập nhật avatar nhóm');
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map ? data['message'] as String? : null;
      if (mounted) {
        showTopSnackBar(
          context,
          message:
              message ?? 'Không thể cập nhật avatar nhóm. Vui lòng thử lại.',
        );
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, message: 'Không thể cập nhật avatar nhóm: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddMembersDialog(
    Map<String, Map<String, String?>> members,
  ) async {
    final selectedIds = await showDialog<List<String>>(
      context: context,
      builder: (ctx) {
        final palette = ctx.appPalette;
        return Dialog(
          backgroundColor: palette.surface,
          child: SizedBox(
            width: 520,
            height: 640,
            child: _AddMembersDialog(existingMemberIds: members.keys.toSet()),
          ),
        );
      },
    );

    if (selectedIds == null || selectedIds.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(chatRepositoryProvider);
      final result = await repo.addMembers(widget.conversationId, selectedIds);
      _refreshGroupData();
      if (mounted) {
        final added = result['added'] ?? selectedIds.length;
        showTopSnackBar(context, message: 'Đã thêm $added thành viên');
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, message: 'Không thể thêm thành viên: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final palette = ctx.appPalette;
        return AlertDialog(
          backgroundColor: palette.surface,
          title: Text('Rời nhóm', style: TextStyle(color: palette.textPrimary)),
          content: Text(
            'Bạn có chắc muốn rời nhóm?',
            style: TextStyle(color: palette.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Rời nhóm'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(chatRepositoryProvider);
      final userId = ref.read(authNotifierProvider).valueOrNull?.user?.id ?? '';
      await repo.removeMember(widget.conversationId, userId);
      _refreshGroupData();
      if (mounted) context.go('/chat');
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, message: 'Lỗi: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeMember({
    required String userId,
    required String name,
    required String role,
  }) async {
    if (role == 'creator') return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final palette = ctx.appPalette;
        return AlertDialog(
          backgroundColor: palette.surface,
          title: Text(
            'Xóa thành viên',
            style: TextStyle(color: palette.textPrimary),
          ),
          content: Text(
            'Bạn có chắc muốn xóa $name khỏi nhóm?',
            style: TextStyle(color: palette.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Xóa',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(chatRepositoryProvider);
      await repo.removeMember(widget.conversationId, userId);
      _refreshGroupData();
      if (mounted) {
        showTopSnackBar(context, message: 'Đã xóa $name khỏi nhóm');
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, message: 'Không thể xóa thành viên: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final palette = ctx.appPalette;
        return AlertDialog(
          backgroundColor: palette.surface,
          title: Text('Xóa nhóm', style: TextStyle(color: palette.textPrimary)),
          content: Text(
            'Bạn có chắc muốn xóa nhóm? Hành động này không thể hoàn tác.',
            style: TextStyle(color: palette.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Xóa',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(chatRepositoryProvider);
      await repo.deleteGroup(widget.conversationId);
      _refreshGroupData();
      if (mounted) context.go('/chat');
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, message: 'Lỗi: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openDirectChat({
    required String userId,
    required String name,
  }) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(chatRepositoryProvider);
      final result = await repo.createConversation(userId);
      final convId = result['id'] as String;
      if (!mounted) return;
      context.go('/chat/$convId');
    } catch (e) {
      if (mounted) {
        showTopSnackBar(
          context,
          message: 'Không thể mở chat riêng với $name: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showMemberActionsSheet({
    required String userId,
    required String name,
    required String? avatarUrl,
    required String role,
    required bool isCurrentUser,
  }) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final palette = sheetContext.appPalette;
        final roleLabel = switch (role) {
          'creator' => 'Người tạo nhóm',
          'admin' => 'Quản trị viên',
          _ => 'Thành viên',
        };
        final initials = name
            .split(' ')
            .where((part) => part.isNotEmpty)
            .take(2)
            .map((part) => part[0].toUpperCase())
            .join();

        return Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.surfaceVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                ChatAvatar(
                  radius: 34,
                  displayName: initials.isEmpty ? name : initials,
                  imageUrl: avatarUrl,
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: AppTypography.titleLarge.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isCurrentUser ? '$roleLabel • Bạn' : roleLabel,
                  style: AppTypography.bodyMedium.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: palette.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: palette.surfaceVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thông tin người dùng',
                        style: AppTypography.titleMedium.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tên hiển thị: $name',
                        style: AppTypography.bodyMedium.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Vai trò trong nhóm: $roleLabel',
                        style: AppTypography.bodyMedium.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isCurrentUser
                        ? null
                        : () => Navigator.of(sheetContext).pop('dm'),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: Text(
                      isCurrentUser
                          ? 'Đây là tài khoản của bạn'
                          : 'Nhắn tin riêng',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == 'dm' && mounted) {
      await _openDirectChat(userId: userId, name: name);
    }
  }

  String _resolveAttachmentUrl(String urlOrPath) {
    if (urlOrPath.startsWith('/uploads')) {
      return '${AppConfig.instance.apiUrl}$urlOrPath';
    }
    return urlOrPath;
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(_resolveAttachmentUrl(url));
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _openExternalAttachment({String? url, String? localPath}) async {
    Uri? uri;
    if (localPath != null &&
        localPath.isNotEmpty &&
        !localPath.startsWith('blob:')) {
      uri = Uri.file(localPath);
    } else if (url != null && url.isNotEmpty) {
      uri = Uri.tryParse(_resolveAttachmentUrl(url));
    }
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _openImageViewer(List<String> imageUrls, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ImageViewerScreen(imageUrls: imageUrls, initialIndex: initialIndex),
      ),
    );
  }

  void _openVideoPlayer(String videoUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VideoPlayerScreen(videoUrl: videoUrl)),
    );
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

  String _formatSectionTime(DateTime dt) {
    final now = DateTime.now();
    final isSameDay =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (isSameDay) return time;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} $time';
  }

  Widget _buildTabSwitcher(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.surfaceVariant),
      ),
      child: Row(
        children: _GroupInfoTab.values.map((tab) {
          final selected = tab == _selectedTab;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? palette.primary.withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tab.label,
                  textAlign: TextAlign.center,
                  style: AppTypography.titleSmall.copyWith(
                    color: selected ? palette.primary : palette.textSecondary,
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

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final convDetail = ref.watch(
      conversationDetailProvider(widget.conversationId),
    );
    final membersAsync = ref.watch(
      conversationMembersProvider(widget.conversationId),
    );
    final authState = ref.watch(authNotifierProvider);
    final currentUserId = authState.valueOrNull?.user?.id ?? '';

    // Watch assets using new API
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

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.asPanel,
        leading: widget.asPanel
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Đóng',
                onPressed: widget.onClose ?? () => Navigator.maybePop(context),
              )
            : null,
        title: const Text('Thông tin nhóm'),
      ),
      body: convDetail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (conv) {
          if (conv == null) {
            return const Center(child: Text('Không tìm thấy nhóm'));
          }

          final members =
              membersAsync.valueOrNull ?? <String, Map<String, String?>>{};
          final currentRole = members[currentUserId]?['role'];
          final isMember = currentRole != null;
          final canAddMembers = isMember;
          final canManageGroupInfo =
              currentRole == 'creator' || currentRole == 'admin';
          final canRemoveMembers = currentRole == 'creator';
          final canDeleteGroup = currentRole == 'creator';
          final displayMembers = members.entries.toList()
            ..sort((a, b) {
              if (a.key == currentUserId) return -1;
              if (b.key == currentUserId) return 1;
              return (a.value['name'] ?? '').compareTo(b.value['name'] ?? '');
            });

          // Use API data
          final mediaItems = mediaAsync.valueOrNull ?? [];
          final fileItems = filesAsync.valueOrNull ?? [];
          final linkItems = linksAsync.valueOrNull ?? [];
          final summary = summaryAsync.valueOrNull;

          return Stack(
            children: [
              ListView(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const SizedBox(height: 24),
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ChatAvatar(
                          radius: 40,
                          displayName: conv.name ?? 'Nhóm',
                          imageUrl: conv.avatarUrl,
                          isGroup: true,
                          iconSize: 36,
                        ),
                        if (canManageGroupInfo)
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Material(
                              color: palette.primary,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _isLoading ? null : _changeGroupAvatar,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.camera_alt_outlined,
                                    size: 18,
                                    color: palette.background,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              conv.name ?? 'Nhóm',
                              textAlign: TextAlign.center,
                              style: AppTypography.headlineSmall.copyWith(
                                color: palette.textPrimary,
                              ),
                            ),
                          ),
                          if (canManageGroupInfo) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Đổi tên nhóm',
                              onPressed: _isLoading
                                  ? null
                                  : () =>
                                        _showRenameDialog(conv.name ?? 'Nhóm'),
                              icon: Icon(
                                Icons.edit_outlined,
                                color: palette.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '${displayMembers.length} thành viên',
                      style: AppTypography.bodyMedium.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                  if (canManageGroupInfo) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: _isLoading ? null : _changeGroupAvatar,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Đổi avatar nhóm'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _buildTabSwitcher(context),
                  if (_selectedTab == _GroupInfoTab.members) ...[
                    // const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text(
                            'Thành viên',
                            style: AppTypography.titleMedium.copyWith(
                              color: palette.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          if (canAddMembers)
                            TextButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : () => _showAddMembersDialog(members),
                              icon: const Icon(Icons.person_add_alt_1),
                              label: const Text('Thêm'),
                            ),
                        ],
                      ),
                    ),
                    if (membersAsync.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (displayMembers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          'Chưa có dữ liệu thành viên',
                          style: AppTypography.bodyMedium.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      )
                    else
                      ...displayMembers.map((entry) {
                        final userId = entry.key;
                        final member = entry.value;
                        final isCurrentUser = userId == currentUserId;
                        final memberRole = member['role'] ?? 'member';
                        final canRemove =
                            canRemoveMembers &&
                            !isCurrentUser &&
                            memberRole != 'creator';
                        return _MemberTile(
                          userId: userId,
                          name: member['name'] ?? 'Unknown',
                          avatarUrl: member['avatar'],
                          role: memberRole,
                          isCurrentUser: isCurrentUser,
                          canRemove: canRemove,
                          onTap: () => _showMemberActionsSheet(
                            userId: userId,
                            name: member['name'] ?? 'Unknown',
                            avatarUrl: member['avatar'],
                            role: memberRole,
                            isCurrentUser: isCurrentUser,
                          ),
                          onRemove: _isLoading || !canRemove
                              ? null
                              : () => _removeMember(
                                  userId: userId,
                                  name: member['name'] ?? 'Unknown',
                                  role: memberRole,
                                ),
                        );
                      }),
                  ] else if (_selectedTab == _GroupInfoTab.media) ...[
                    _AssetSectionCard(
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
                            return const _EmptyGroupInfoSection(
                              message: 'Chưa có ảnh hoặc video trong nhóm',
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
                                  'group_media_${item.type}_${item.createdAt.millisecondsSinceEpoch}_$firstUrl',
                                ),
                                child: _MediaGridTile(
                                  item: _GroupInfoMediaItem(
                                    type: item.type,
                                    source: firstUrl,
                                    createdAt: item.createdAt,
                                    thumbnail: item.thumbnail,
                                    caption: item.caption,
                                  ),
                                  onTap: () {
                                    if (item.type == 'video') {
                                      _openVideoPlayer(firstUrl);
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
                  ] else if (_selectedTab == _GroupInfoTab.files) ...[
                    _AssetSectionCard(
                      title: 'Files',
                      countLabel: '${fileItems.length} items',
                      child: fileItems.isEmpty
                          ? const _EmptyGroupInfoSection(
                              message: 'Chưa có file nào trong nhóm',
                            )
                          : Column(
                              children: fileItems
                                  .map(
                                    (item) => _InfoActionTile(
                                      icon: Icons.attach_file_rounded,
                                      title: item.name,
                                      subtitle: [
                                        if ((item.mimeType ?? '').isNotEmpty)
                                          item.mimeType!,
                                        if (_formatFileSize(
                                          item.size,
                                        ).isNotEmpty)
                                          _formatFileSize(item.size),
                                        _formatSectionTime(item.createdAt),
                                      ].join(' • '),
                                      onTap: () => _openExternalAttachment(
                                        url: item.url,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                  ] else ...[
                    _AssetSectionCard(
                      title: 'Links',
                      countLabel: '${linkItems.length} items',
                      child: linkItems.isEmpty
                          ? const _EmptyGroupInfoSection(
                              message: 'Chưa có liên kết nào trong nhóm',
                            )
                          : Column(
                              children: linkItems
                                  .map(
                                    (item) => _InfoActionTile(
                                      icon: Icons.link_rounded,
                                      title: item.content,
                                      subtitle:
                                          '${item.senderName} • ${_formatSectionTime(item.createdAt)}',
                                      onTap: () => _openExternalUrl(item.url),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.exit_to_app,
                      color: AppColors.warning,
                    ),
                    title: const Text(
                      'Rời nhóm',
                      style: TextStyle(color: AppColors.warning),
                    ),
                    onTap: _isLoading ? null : _leaveGroup,
                  ),
                  if (canDeleteGroup)
                    ListTile(
                      leading: const Icon(
                        Icons.delete_forever,
                        color: AppColors.danger,
                      ),
                      title: const Text(
                        'Xóa nhóm',
                        style: TextStyle(color: AppColors.danger),
                      ),
                      onTap: _isLoading ? null : _deleteGroup,
                    ),
                ],
              ),
              if (_isLoading)
                ColoredBox(
                  color: _loadingScrimColor(context),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              Positioned(
                right: 20,
                bottom: 28,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 180),
                  offset: _showScrollToTop ? Offset.zero : const Offset(0, 1.4),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _showScrollToTop ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !_showScrollToTop,
                      child: FloatingActionButton.small(
                        heroTag: 'group-info-scroll-top',
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
    );
  }
}

class _AssetSectionCard extends StatelessWidget {
  const _AssetSectionCard({
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.titleMedium.copyWith(
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            countLabel,
            style: AppTypography.bodySmall.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _EmptyGroupInfoSection extends StatelessWidget {
  const _EmptyGroupInfoSection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: palette.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MediaGridTile extends StatelessWidget {
  const _MediaGridTile({required this.item, required this.onTap});

  final _GroupInfoMediaItem item;
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
                  errorBuilder: (_, _, _) => Container(
                    color: palette.surfaceVariant,
                    alignment: Alignment.center,
                    child: Icon(
                      item.type == 'video'
                          ? Icons.videocam_rounded
                          : Icons.image_outlined,
                      color: palette.textHint,
                      size: 28,
                    ),
                  ),
                )
              else
                OptimizedNetworkImage(
                  key: ValueKey('group_media_thumb_${item.type}_$resolved'),
                  imageUrl: resolved,
                  fit: BoxFit.cover,
                  memCacheWidth: 320,
                  memCacheHeight: 320,
                  errorWidget: Container(
                    color: palette.surfaceVariant,
                    alignment: Alignment.center,
                    child: Icon(
                      item.type == 'video'
                          ? Icons.videocam_rounded
                          : Icons.image_outlined,
                      color: palette.textHint,
                      size: 28,
                    ),
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

class _InfoActionTile extends StatelessWidget {
  const _InfoActionTile({
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
    final palette = context.appPalette;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: palette.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: palette.primary),
      ),
      title: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.bodyLarge.copyWith(color: palette.textPrimary),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.bodySmall.copyWith(color: palette.textSecondary),
      ),
      trailing: Icon(
        Icons.open_in_new_rounded,
        size: 18,
        color: palette.textSecondary,
      ),
      onTap: onTap,
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.role,
    required this.isCurrentUser,
    required this.canRemove,
    this.onTap,
    this.onRemove,
  });

  final String userId;
  final String name;
  final String? avatarUrl;
  final String role;
  final bool isCurrentUser;
  final bool canRemove;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final roleLabel = switch (role) {
      'creator' => 'Creator',
      'admin' => 'Admin',
      _ => 'Member',
    };
    final initials = name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return ListTile(
      onTap: onTap,
      leading: ChatAvatar(
        displayName: initials.isEmpty ? name : initials,
        imageUrl: avatarUrl,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(name, style: TextStyle(color: palette.textPrimary)),
          ),
          if (isCurrentUser) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Bạn',
                style: AppTypography.labelSmall.copyWith(
                  color: palette.primary,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(roleLabel, style: TextStyle(color: palette.textSecondary)),
      trailing: canRemove
          ? IconButton(
              tooltip: 'Xóa thành viên',
              onPressed: onRemove,
              icon: const Icon(
                Icons.person_remove_alt_1,
                color: AppColors.danger,
              ),
            )
          : null,
    );
  }
}

class _AddMembersDialog extends ConsumerStatefulWidget {
  const _AddMembersDialog({required this.existingMemberIds});

  final Set<String> existingMemberIds;

  @override
  ConsumerState<_AddMembersDialog> createState() => _AddMembersDialogState();
}

class _AddMembersDialogState extends ConsumerState<_AddMembersDialog> {
  final _searchController = TextEditingController();
  final Set<String> _selectedIds = {};
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _searchQuery = value.trim());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final contactsAsync = ref.watch(contactListProvider(_searchQuery));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.close, color: palette.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Text(
                'Thêm thành viên',
                style: AppTypography.titleLarge.copyWith(
                  color: palette.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _selectedIds.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(_selectedIds.toList()),
                child: Text(
                  'Xong',
                  style: TextStyle(
                    color: _selectedIds.isEmpty
                        ? palette.textHint
                        : palette.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: TextStyle(color: palette.textPrimary),
            decoration: InputDecoration(
              hintText: 'Tìm kiếm nhân sự...',
              hintStyle: TextStyle(color: palette.textHint),
              prefixIcon: Icon(Icons.search, color: palette.textHint),
            ),
          ),
        ),
        Expanded(
          child: contactsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                'Lỗi: $e',
                style: TextStyle(color: palette.textSecondary),
              ),
            ),
            data: (contacts) {
              final availableContacts = contacts
                  .where(
                    (contact) => !widget.existingMemberIds.contains(contact.id),
                  )
                  .toList();

              if (availableContacts.isEmpty) {
                return Center(
                  child: Text(
                    'Không còn ai để thêm',
                    style: AppTypography.bodyMedium.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                );
              }

              return ListView.builder(
                itemCount: availableContacts.length,
                itemBuilder: (context, index) {
                  final contact = availableContacts[index];
                  final selected = _selectedIds.contains(contact.id);
                  return ListTile(
                    leading: ChatAvatar(
                      displayName: contact.name,
                      imageUrl: contact.avatarUrl,
                    ),
                    title: Text(
                      contact.name,
                      style: TextStyle(color: palette.textPrimary),
                    ),
                    subtitle: Text(
                      [
                        if (contact.jobTitle != null &&
                            contact.jobTitle!.isNotEmpty)
                          contact.jobTitle!,
                        if (contact.department != null &&
                            contact.department!.isNotEmpty)
                          contact.department!,
                      ].join(' · '),
                      style: TextStyle(color: palette.textSecondary),
                    ),
                    trailing: Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      color: selected ? palette.primary : palette.textHint,
                    ),
                    onTap: () {
                      setState(() {
                        if (selected) {
                          _selectedIds.remove(contact.id);
                        } else {
                          _selectedIds.add(contact.id);
                        }
                      });
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
