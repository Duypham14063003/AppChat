import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_avatar.dart';

class ForwardChatPickerScreen extends ConsumerStatefulWidget {
  final String sourceConvId;
  final List<String> messageIds;
  final bool asDialog;

  const ForwardChatPickerScreen({
    super.key,
    required this.sourceConvId,
    required this.messageIds,
    this.asDialog = false,
  });

  @override
  ConsumerState<ForwardChatPickerScreen> createState() =>
      _ForwardChatPickerScreenState();
}

class _ForwardChatPickerScreenState
    extends ConsumerState<ForwardChatPickerScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _selectedConvIds = {};
  bool _hideSender = false;
  bool _isSending = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value.trim().toLowerCase());
  }

  void _toggleConversation(String convId) {
    setState(() {
      if (_selectedConvIds.contains(convId)) {
        _selectedConvIds.remove(convId);
      } else {
        _selectedConvIds.add(convId);
      }
    });
  }

  Future<void> _send() async {
    if (_selectedConvIds.isEmpty || _isSending) return;
    setState(() => _isSending = true);

    await ref
        .read(chatMessagesProvider(widget.sourceConvId).notifier)
        .forwardMessages(
          widget.messageIds,
          _selectedConvIds.toList(),
          _hideSender,
        );

    if (!mounted) return;
    final msgCount = widget.messageIds.length;
    final convCount = _selectedConvIds.length;
    showTopSnackBar(
      context,
      message:
          'Đã chuyển tiếp $msgCount tin nhắn đến $convCount cuộc trò chuyện',
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final conversationsAsync = ref.watch(chatListProvider);
    final conversations = conversationsAsync.valueOrNull ?? [];

    final filtered = _searchQuery.isEmpty
        ? conversations
        : conversations.where((c) {
            final name = (c.name ?? c.otherMemberName ?? '').toLowerCase();
            return name.contains(_searchQuery);
          }).toList();

    final bodyContent = Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            cursorColor: palette.primary,
            style: TextStyle(color: palette.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Tìm cuộc trò chuyện...',
              hintStyle: TextStyle(color: palette.textHint),
              prefixIcon: Icon(Icons.search, color: palette.textHint),
              filled: true,
              fillColor: palette.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        // Selected chips
        if (_selectedConvIds.isNotEmpty)
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _selectedConvIds.map((id) {
                final conv = conversations
                    .where((c) => c.id == id)
                    .firstOrNull;
                final label = conv?.name ?? conv?.otherMemberName ?? 'Chat';
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Chip(
                    label: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.textPrimary,
                      ),
                    ),
                    deleteIcon: Icon(
                      Icons.close,
                      size: 16,
                      color: palette.primary,
                    ),
                    onDeleted: () => _toggleConversation(id),
                    backgroundColor: palette.primary.withValues(
                      alpha: palette.isLight ? 0.10 : 0.16,
                    ),
                    side: BorderSide.none,
                  ),
                );
              }).toList(),
            ),
          ),
        // Hide sender toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Ẩn nguồn',
                  style: TextStyle(color: palette.textPrimary, fontSize: 14),
                ),
              ),
              Switch(
                value: _hideSender,
                activeThumbColor: palette.primary,
                activeTrackColor: palette.primary.withValues(
                  alpha: palette.isLight ? 0.32 : 0.42,
                ),
                inactiveTrackColor: palette.surfaceVariant,
                onChanged: (v) => setState(() => _hideSender = v),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: palette.surfaceVariant),
        // Conversation list
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final conv = filtered[index];
              final isSelected = _selectedConvIds.contains(conv.id);
              final displayName = conv.name ?? conv.otherMemberName ?? 'Chat';
              final displayAvatar = conv.avatarUrl ?? conv.otherMemberAvatar;
              final isGroup = conv.type == 'GROUP';

              return ListTile(
                leading: ChatAvatar(
                  radius: 22,
                  displayName: displayName,
                  imageUrl: displayAvatar,
                  isGroup: isGroup,
                ),
                title: Text(
                  displayName,
                  style: TextStyle(color: palette.textPrimary, fontSize: 15),
                ),
                trailing: Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isSelected ? palette.primary : palette.textHint,
                ),
                onTap: () => _toggleConversation(conv.id),
              );
            },
          ),
        ),
      ],
    );

    if (widget.asDialog) {
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
                  'Chuyển tiếp đến',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _isSending
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.primary,
                        ),
                      )
                    : TextButton(
                        onPressed: _selectedConvIds.isEmpty ? null : _send,
                        child: Text(
                          'Gửi',
                          style: TextStyle(
                            color: _selectedConvIds.isEmpty ? palette.textHint : palette.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.surfaceVariant),
          Expanded(child: bodyContent),
        ],
      );
    }

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        title: const Text('Chuyển tiếp đến'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: palette.surfaceVariant),
        ),
      ),
      body: bodyContent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: _selectedConvIds.isEmpty
            ? palette.surfaceVariant
            : palette.primary,
        onPressed: _selectedConvIds.isEmpty ? null : _send,
        child: _isSending
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: palette.isLight ? Colors.white : palette.background,
                ),
              )
            : Icon(
                Icons.send,
                color: _selectedConvIds.isEmpty
                    ? palette.textHint
                    : (palette.isLight ? Colors.white : palette.background),
              ),
      ),
    );
  }
}
