import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/user_repository.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_avatar.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../../../core/utils/snackbar_utils.dart';

final contactListProvider = FutureProvider.family<List<UserContact>, String>((
  ref,
  search,
) async {
  final repo = ref.watch(userRepositoryProvider);
  final result = await repo.getUsers(search: search.isEmpty ? null : search);
  return result.users;
});

class ContactPickerScreen extends ConsumerStatefulWidget {
  final bool asDialog;

  const ContactPickerScreen({super.key, this.asDialog = false});

  @override
  ConsumerState<ContactPickerScreen> createState() =>
      _ContactPickerScreenState();
}

class _ContactPickerScreenState extends ConsumerState<ContactPickerScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;
  bool _isCreating = false;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _searchQuery = value.trim());
    });
  }

  Future<void> _onContactTap(UserContact contact) async {
    if (_isCreating) return;
    setState(() => _isCreating = true);

    try {
      final repo = ref.read(chatRepositoryProvider);
      final result = await repo.createConversation(contact.id);
      final convId = result['id'] as String;
      if (mounted) {
        if (widget.asDialog) {
          Navigator.of(context).pop();
          if (context.mounted) context.go('/chat/$convId');
        } else {
          context.pushReplacement('/chat/$convId');
        }
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(
          context,
          message: 'Không thể tạo cuộc trò chuyện: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final contactsAsync = ref.watch(contactListProvider(_searchQuery));

    final body = contactsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Lỗi tải danh sách: $e',
              style: TextStyle(color: palette.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.invalidate(contactListProvider(_searchQuery)),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
      data: (contacts) {
        if (contacts.isEmpty) {
          return Center(
            child: Text(
              'Không tìm thấy liên hệ',
              style: TextStyle(color: palette.textSecondary),
            ),
          );
        }
        return ListView.builder(
          itemCount: contacts.length,
          itemBuilder: (context, index) {
            final contact = contacts[index];
            return _ContactListItem(
              contact: contact,
              onTap: () => _onContactTap(contact),
            );
          },
        );
      },
    );

    final searchBar = TextField(
      controller: _searchController,
      autofocus: false,
      style: TextStyle(color: palette.textPrimary),
      decoration: InputDecoration(
        hintText: 'Tìm kiếm liên hệ...',
        hintStyle: TextStyle(color: palette.textHint),
        border: InputBorder.none,
        prefixIcon: Icon(Icons.search, color: palette.textHint),
      ),
      onChanged: _onSearchChanged,
    );

    if (widget.asDialog) {
      return Stack(
        children: [
          Column(
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
                      'Chat mới',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: searchBar,
              ),
              Divider(height: 1, color: palette.surfaceVariant),
              Expanded(child: body),
            ],
          ),
          if (_isCreating)
            ColoredBox(
              color: palette.textPrimary.withValues(
                alpha: palette.isLight ? 0.12 : 0.28,
              ),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      );
    }

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: searchBar),
          body: body,
        ),
        if (_isCreating)
          ColoredBox(
            color: palette.textPrimary.withValues(
              alpha: palette.isLight ? 0.12 : 0.28,
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _ContactListItem extends StatelessWidget {
  final UserContact contact;
  final VoidCallback onTap;

  const _ContactListItem({required this.contact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final initials = contact.name.isNotEmpty
        ? contact.name
              .split(' ')
              .where((w) => w.isNotEmpty)
              .take(2)
              .map((w) => w[0].toUpperCase())
              .join()
        : '?';

    final subtitle = [
      if (contact.jobTitle != null && contact.jobTitle!.isNotEmpty)
        contact.jobTitle!,
      if (contact.department != null && contact.department!.isNotEmpty)
        contact.department!,
    ].join(' · ');

    return ListTile(
      leading: ChatAvatar(
        displayName: contact.name.isNotEmpty ? contact.name : initials,
        imageUrl: contact.avatarUrl,
      ),
      title: Text(contact.name, style: TextStyle(color: palette.textPrimary)),
      subtitle: subtitle.isNotEmpty
          ? Text(subtitle, style: TextStyle(color: palette.textSecondary))
          : null,
      onTap: onTap,
    );
  }
}
