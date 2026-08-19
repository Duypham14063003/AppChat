import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/chat_providers.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../../../core/utils/snackbar_utils.dart';

class GroupCreateNameScreen extends ConsumerStatefulWidget {
  final List<String> memberIds;
  final bool asDialog;

  const GroupCreateNameScreen({
    super.key,
    required this.memberIds,
    this.asDialog = false,
  });

  @override
  ConsumerState<GroupCreateNameScreen> createState() =>
      _GroupCreateNameScreenState();
}

class _GroupCreateNameScreenState extends ConsumerState<GroupCreateNameScreen> {
  final _nameController = TextEditingController();
  bool _isCreating = false;
  XFile? _selectedAvatar;
  Uint8List? _selectedAvatarBytes;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    if (_isCreating) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (image == null || !mounted) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;

    setState(() {
      _selectedAvatar = image;
      _selectedAvatarBytes = bytes;
    });
  }

  Future<void> _createGroup() async {
    if (_isCreating || _nameController.text.trim().isEmpty) return;
    setState(() => _isCreating = true);

    try {
      final repo = ref.read(chatRepositoryProvider);
      final result = await repo.createGroupConversation(
        _nameController.text.trim(),
        widget.memberIds,
      );
      final convId = result['id'] as String;
      if (_selectedAvatar != null) {
        final uploaded = await repo.uploadImages([_selectedAvatar!]);
        final avatarUrl = uploaded.firstOrNull?['url'] as String?;
        if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
          await repo.updateConversation(convId, avatarUrl: avatarUrl);
        }
      }
      if (mounted) {
        ref.invalidate(chatListProvider);
        if (widget.asDialog) {
          Navigator.of(context).pop();
          if (context.mounted) context.go('/chat/$convId');
        } else {
          context.pushReplacement('/chat/$convId');
        }
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, message: 'Không thể tạo nhóm: $e');
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final canCreate = _nameController.text.trim().isNotEmpty && !_isCreating;

    final createButton = _isCreating
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: palette.primary,
            ),
          )
        : TextButton(
            onPressed: canCreate ? _createGroup : null,
            child: Text(
              'Tạo nhóm',
              style: TextStyle(
                color: canCreate ? palette.primary : palette.textHint,
              ),
            ),
          );

    final bodyContent = Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: _isCreating ? null : _pickAvatar,
            child: CircleAvatar(
              radius: 28,
              backgroundColor: palette.surfaceVariant,
              foregroundImage: _selectedAvatarBytes != null
                  ? MemoryImage(_selectedAvatarBytes!)
                  : null,
              child: _selectedAvatarBytes == null
                  ? Icon(
                      Icons.camera_alt,
                      color: palette.textHint,
                      size: 24,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _nameController,
              autofocus: true,
              style: TextStyle(color: palette.textPrimary, fontSize: 18),
              decoration: InputDecoration(
                hintText: 'Tên nhóm',
                hintStyle: TextStyle(color: palette.textHint),
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
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
                  'Đặt tên nhóm',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                createButton,
              ],
            ),
          ),
          Divider(height: 1, color: palette.surfaceVariant),
          bodyContent,
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đặt tên nhóm'),
        actions: [createButton],
      ),
      body: bodyContent,
    );
  }
}
