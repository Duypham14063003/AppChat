import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/user_repository.dart';
import '../screens/contact_picker_screen.dart';
import '../screens/group_create_name_screen.dart';
import '../widgets/chat_avatar.dart';
import '../../../core/theme/theme_color_presets.dart';

class GroupCreateMembersScreen extends ConsumerStatefulWidget {
  final bool asDialog;

  const GroupCreateMembersScreen({super.key, this.asDialog = false});

  @override
  ConsumerState<GroupCreateMembersScreen> createState() =>
      _GroupCreateMembersScreenState();
}

class _GroupCreateMembersScreenState
    extends ConsumerState<GroupCreateMembersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;
  final Set<String> _selectedIds = {};
  final Map<String, UserContact> _selectedContacts = {};

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

  void _toggleContact(UserContact contact) {
    setState(() {
      if (_selectedIds.contains(contact.id)) {
        _selectedIds.remove(contact.id);
        _selectedContacts.remove(contact.id);
      } else {
        _selectedIds.add(contact.id);
        _selectedContacts[contact.id] = contact;
      }
    });
  }

  void _onNext() {
    final memberIds = _selectedIds.toList();
    if (widget.asDialog) {
      final palette = context.appPalette;
      Navigator.of(context).pop();
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: palette.surface,
          child: SizedBox(
            width: 480,
            height: 600,
            child: GroupCreateNameScreen(memberIds: memberIds, asDialog: true),
          ),
        ),
      );
    } else {
      context.push('/group/create/name', extra: memberIds);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final contactsAsync = ref.watch(contactListProvider(_searchQuery));
    final canProceed = _selectedIds.length >= 2;

    final searchField = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: palette.textPrimary),
        decoration: InputDecoration(
          hintText: 'Tìm kiếm liên hệ...',
          hintStyle: TextStyle(color: palette.textHint),
          prefixIcon: Icon(Icons.search, color: palette.textHint),
          border: const OutlineInputBorder(),
        ),
        onChanged: _onSearchChanged,
      ),
    );

    final chipRow = _selectedContacts.isNotEmpty
        ? SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _selectedContacts.values.map((c) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Chip(
                    backgroundColor: palette.surfaceVariant,
                    label: Text(
                      c.name,
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.textPrimary,
                      ),
                    ),
                    deleteIcon: Icon(
                      Icons.close,
                      size: 16,
                      color: palette.textSecondary,
                    ),
                    onDeleted: () => _toggleContact(c),
                  ),
                );
              }).toList(),
            ),
          )
        : const SizedBox.shrink();

    final contactList = Expanded(
      child: contactsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Lỗi: $e',
            style: TextStyle(color: palette.textSecondary),
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
                trailing: selected
                    ? Icon(Icons.check_circle, color: palette.primary)
                    : Icon(Icons.circle_outlined, color: palette.textHint),
                onTap: () => _toggleContact(contact),
              );
            },
          );
        },
      ),
    );

    final nextButton = TextButton(
      onPressed: canProceed ? _onNext : null,
      child: Text(
        'Tiếp',
        style: TextStyle(
          color: canProceed ? palette.primary : palette.textHint,
        ),
      ),
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
                  'Tạo nhóm',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                nextButton,
              ],
            ),
          ),
          searchField,
          chipRow,
          contactList,
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tạo nhóm'), actions: [nextButton]),
      body: Column(children: [searchField, chipRow, contactList]),
    );
  }
}
