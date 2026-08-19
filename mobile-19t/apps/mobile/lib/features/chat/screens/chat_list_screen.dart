import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_interaction.dart';
import '../../../core/theme/app_motion.dart';
import '../providers/chat_providers.dart';
import '../widgets/conversation_tile.dart';
import '../widgets/conversation_peek_preview.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../../../shared/widgets/heart_header_badge.dart';
import '../../../shared/widgets/animated_fab.dart';
import '../../../shared/widgets/animated_icon_button.dart';
import '../../../shared/widgets/shimmer_skeleton.dart';
import '../screens/contact_picker_screen.dart';
import '../screens/group_create_members_screen.dart';
import '../../auth/providers/auth_notifier.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  final String? selectedConversationId;

  const ChatListScreen({
    super.key,
    this.isEmbedded = false,
    this.selectedConversationId,
  });

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final _searchController = TextEditingController();
  final _addButtonKey = GlobalKey();
  bool _isSearching = false;
  String _searchQuery = '';
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        final normalizedQuery = text.trim();
        setState(() {
          _searchQuery = normalizedQuery;
        });
      }
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    setState(() {
      _isSearching = false;
      _searchQuery = '';
    });
    _searchController.clear();
  }

  bool get _isWideScreen => MediaQuery.of(context).size.width >= 768;

  void _navigateToChat(String convId) {
    if (widget.isEmbedded) {
      context.go('/chat/$convId');
    } else {
      context.push('/chat/$convId');
    }
  }

  void _openSavedMessages() {
    context.push('/bookmarks');
  }

  Future<void> _showConversationPreview(
    LocalConversation conversation,
    String? currentUserId,
  ) {
    return showConversationPeekPreview(
      context: context,
      conversation: conversation,
      currentUserId: currentUserId,
      onOpenChat: () => _navigateToChat(conversation.id),
    );
  }

  void _onFabPressed() {
    if (_isWideScreen) {
      _showPopupMenu();
    } else {
      _showBottomSheet();
    }
  }

  void _showPopupMenu() {
    final palette = context.appPalette;
    final renderBox =
        _addButtonKey.currentContext!.findRenderObject() as RenderBox;
    final buttonPos = renderBox.localToGlobal(Offset.zero);
    final buttonSize = renderBox.size;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(
        buttonPos.dx,
        buttonPos.dy + buttonSize.height,
        buttonSize.width,
        0,
      ),
      Offset.zero & overlay.size,
    );
    showMenu<String>(
      context: context,
      position: position,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.surfaceVariant),
      ),
      items: [
        PopupMenuItem(
          value: 'direct',
          child: ListTile(
            leading: Icon(Icons.chat, color: palette.primary),
            title: Text(
              'Chat mới',
              style: TextStyle(color: palette.textPrimary),
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'group',
          child: ListTile(
            leading: Icon(Icons.group_add, color: palette.primary),
            title: Text(
              'Tạo nhóm',
              style: TextStyle(color: palette.textPrimary),
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ).then((value) {
      if (value == 'direct') {
        _openContactPicker();
      } else if (value == 'group') {
        _openGroupCreate();
      }
    });
  }

  void _showBottomSheet() {
    final palette = context.appPalette;
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.chat, color: palette.primary),
              title: Text(
                'Chat mới',
                style: TextStyle(color: palette.textPrimary),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _openContactPicker();
              },
            ),
            ListTile(
              leading: Icon(Icons.group_add, color: palette.primary),
              title: Text(
                'Tạo nhóm',
                style: TextStyle(color: palette.textPrimary),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _openGroupCreate();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openContactPicker() {
    final palette = context.appPalette;
    if (_isWideScreen) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: palette.surface,
          child: const SizedBox(
            width: 480,
            height: 600,
            child: ContactPickerScreen(asDialog: true),
          ),
        ),
      );
    } else {
      context.push('/contacts/pick');
    }
  }

  void _openGroupCreate() {
    final palette = context.appPalette;
    if (_isWideScreen) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: palette.surface,
          child: const SizedBox(
            width: 480,
            height: 600,
            child: GroupCreateMembersScreen(asDialog: true),
          ),
        ),
      );
    } else {
      context.push('/group/create/members');
    }
  }

  Widget _buildBody() {
    final palette = context.appPalette;
    if (_isSearching && _searchQuery.length >= 2) {
      return _buildSearchResults();
    }

    final conversationsAsync = ref.watch(chatListProvider);
    final authState = ref.watch(authNotifierProvider);
    final currentUserId = authState.valueOrNull?.user?.id;

    return conversationsAsync.when(
      loading: () => ListView.builder(
        physics: appScrollPhysics(context),
        itemCount: 8,
        itemBuilder: (context, index) => const ConversationSkeleton(),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (conversations) {
        if (conversations.isEmpty) {
          return Center(
            child: Text(
              'Chưa có cuộc trò chuyện nào',
              style: TextStyle(color: palette.textSecondary),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.read(chatListProvider.notifier).refresh(),
          child: ListView.builder(
            physics: appScrollPhysics(context),
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conv = conversations[index];
              return RepaintBoundary(
                child: ConversationTile(
                  key: ValueKey(conv.id),
                  conversation: conv,
                  isSelected: conv.id == widget.selectedConversationId,
                  currentUserId: currentUserId,
                  onTap: () => _navigateToChat(conv.id),
                  onLongPress: () =>
                      _showConversationPreview(conv, currentUserId),
                ),
              );
            },
          ),
        );
      },
    );
  }

  bool _conversationMatchesSearch(
    LocalConversation conversation,
    String normalizedQuery,
  ) {
    final displayName =
        (conversation.type == 'DIRECT'
            ? conversation.otherMemberName
            : conversation.name) ??
        conversation.name ??
        conversation.otherMemberName ??
        '';
    return displayName.toLowerCase().contains(normalizedQuery.toLowerCase());
  }

  Widget _buildSearchResults() {
    final palette = context.appPalette;
    final conversationsAsync = ref.watch(chatListProvider);
    final authState = ref.watch(authNotifierProvider);
    final currentUserId = authState.valueOrNull?.user?.id;

    return conversationsAsync.when(
      loading: () => ListView.builder(
        physics: appScrollPhysics(context),
        itemCount: 8,
        itemBuilder: (context, index) => const ConversationSkeleton(),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (conversations) {
        final filtered = conversations
            .where(
              (conversation) =>
                  _conversationMatchesSearch(conversation, _searchQuery),
            )
            .toList(growable: false);

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              'Không tìm thấy cuộc trò chuyện phù hợp',
              style: TextStyle(color: palette.textSecondary),
            ),
          );
        }

        return ListView(
          physics: appScrollPhysics(context),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Cuộc trò chuyện',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...filtered.map(
              (conv) => RepaintBoundary(
                child: ConversationTile(
                  key: ValueKey('search-${conv.id}'),
                  conversation: conv,
                  isSelected: conv.id == widget.selectedConversationId,
                  currentUserId: currentUserId,
                  onTap: () => _navigateToChat(conv.id),
                  onLongPress: () =>
                      _showConversationPreview(conv, currentUserId),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    if (widget.isEmbedded) {
      // Embedded mode: no Scaffold/AppBar, just the body with a search header
      return Column(
        children: [
          // Compact header with search
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border(bottom: BorderSide(color: palette.surfaceVariant)),
            ),
            child: Row(
              children: [
                Text(
                  'Chat',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _isSearching ? Icons.close : Icons.search,
                    color: palette.textSecondary,
                    size: 20,
                  ),
                  tooltip: _isSearching ? 'Đóng' : 'Tìm kiếm',
                  splashRadius: 18,
                  onPressed: () {
                    if (_isSearching) {
                      _clearSearch();
                    } else {
                      setState(() => _isSearching = true);
                    }
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.bookmarks_outlined,
                    color: palette.textSecondary,
                    size: 20,
                  ),
                  tooltip: 'Tin nhắn đã lưu',
                  splashRadius: 18,
                  onPressed: _openSavedMessages,
                ),
                IconButton(
                  key: _addButtonKey,
                  icon: Icon(Icons.add, color: palette.primary, size: 20),
                  tooltip: 'Thêm mới',
                  splashRadius: 18,
                  onPressed: _onFabPressed,
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: AppMotion.fast,
            curve: AppMotion.enterCurve,
            child: _isSearching
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: palette.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm cuộc trò chuyện...',
                          hintStyle: TextStyle(color: palette.textHint),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: palette.textHint,
                            size: 18,
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 0,
                          ),
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(child: _buildBody()),
        ],
      );
    }

    // Full-screen mode (mobile)
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: palette.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm cuộc trò chuyện...',
                  hintStyle: TextStyle(color: palette.textHint),
                  border: InputBorder.none,
                ),
                onChanged: _onSearchChanged,
              )
            : const Text('Chat'),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Center(child: HeartHeaderBadge(compact: true)),
          ),
          AnimatedIconButton(
            icon: _isSearching ? Icons.close : Icons.search,
            tooltip: _isSearching ? 'Đóng' : 'Tìm kiếm',
            onPressed: () {
              if (_isSearching) {
                _clearSearch();
              } else {
                setState(() => _isSearching = true);
              }
            },
          ),
          AnimatedIconButton(
            icon: Icons.bookmarks_outlined,
            tooltip: 'Tin nhắn đã lưu',
            onPressed: _openSavedMessages,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: AnimatedFAB(
        icon: Icons.add,
        onPressed: _onFabPressed,
        backgroundColor: palette.primary,
        foregroundColor: palette.isLight ? Colors.white : palette.background,
        rotateOnTap: true,
        tooltip: 'Tạo cuộc trò chuyện mới',
      ),
    );
  }
}
