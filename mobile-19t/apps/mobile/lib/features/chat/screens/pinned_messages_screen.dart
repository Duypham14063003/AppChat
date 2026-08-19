import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/providers/auth_notifier.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/app_database.dart';
import '../data/encrypted_message_adapter.dart';
import '../providers/chat_providers.dart';
import '../../../core/theme/theme_color_presets.dart';

Future<void> showPinnedMessages(
  BuildContext context, {
  required String conversationId,
}) {
  final palette = context.appPalette;
  final isWide = MediaQuery.of(context).size.width >= 768;

  if (isWide) {
    return showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          width: 480,
          height: 600,
          child: Column(
            children: [
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: palette.surface,
                  border: Border(bottom: BorderSide(color: palette.surfaceVariant)),
                ),
                child: Row(
                  children: [
                    Text(
                      'Tin nhắn đã ghim',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: palette.textSecondary, size: 20),
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _PinnedMessagesView(
                  conversationId: conversationId,
                  asDialog: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  } else {
    return showPinnedMessagesBottomSheet(context, conversationId: conversationId);
  }
}

Future<void> showPinnedMessagesBottomSheet(
  BuildContext context, {
  required String conversationId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final palette = sheetContext.appPalette;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (_, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              top: false,
              child: _PinnedMessagesView(
                conversationId: conversationId,
                scrollController: scrollController,
              ),
            ),
          );
        },
      );
    },
  );
}

class PinnedMessagesListScreen extends ConsumerWidget {
  final String conversationId;

  const PinnedMessagesListScreen({super.key, required this.conversationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.appPalette.background,
      body: SafeArea(child: _PinnedMessagesView(conversationId: conversationId)),
    );
  }
}

class _PinnedMessagesView extends ConsumerWidget {
  const _PinnedMessagesView({
    required this.conversationId,
    this.scrollController,
    this.asDialog = false,
  });

  final String conversationId;
  final ScrollController? scrollController;
  final bool asDialog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appPalette;
    final pinsAsync = ref.watch(pinnedMessagesProvider(conversationId));
    final pins = pinsAsync.valueOrNull ?? [];
    final authState = ref.watch(authNotifierProvider);
    final currentUserId = authState.valueOrNull?.user?.id ?? '';
    final convDetail = ref.watch(conversationDetailProvider(conversationId));
    final conv = convDetail.valueOrNull;
    final isGroup = conv?.type == 'GROUP';
    final members =
        ref.watch(conversationMembersProvider(conversationId)).valueOrNull ??
        {};
    final myRole = members[currentUserId]?['role'];
    final canUnpinAll = !isGroup || myRole == 'creator' || myRole == 'admin';

    Future<void> unpinAll(BuildContext context, WidgetRef ref) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final dialogPalette = ctx.appPalette;
          return AlertDialog(
            backgroundColor: dialogPalette.surface,
            title: Text(
              'Bỏ ghim tất cả?',
              style: TextStyle(color: dialogPalette.textPrimary),
            ),
            content: Text(
              'Tất cả tin nhắn ghim sẽ bị bỏ ghim.',
              style: TextStyle(
                color: dialogPalette.textSecondary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Hủy',
                  style: TextStyle(
                    color: dialogPalette.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Bỏ ghim',
                  style: TextStyle(
                    color: dialogPalette.primary,
                  ),
                ),
              ),
            ],
          );
        },
      );
      if (confirmed == true) {
        await ref
            .read(pinnedMessagesProvider(conversationId).notifier)
            .unpinAllMessages();
      }
    }

    return Column(
      children: [
        if (!asDialog) ...[
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: palette.surfaceVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Tin nhắn đã ghim',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
                if (canUnpinAll && pins.isNotEmpty)
                  TextButton(
                    onPressed: () => unpinAll(context, ref),
                    style: TextButton.styleFrom(foregroundColor: palette.primary),
                    child: const Text(
                      'Bỏ ghim tất cả',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.surfaceVariant),
        ] else if (canUnpinAll && pins.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Bỏ ghim tất cả'),
                  onPressed: () => unpinAll(context, ref),
                  style: TextButton.styleFrom(foregroundColor: palette.primary),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.surfaceVariant),
        ],
        Expanded(
          child: pinsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Error: $e',
            style: TextStyle(color: palette.textPrimary),
          ),
        ),
        data: (pins) {
          if (pins.isEmpty) {
            return Center(
              child: Text(
                'Chưa có tin nhắn ghim',
                style: TextStyle(color: palette.textSecondary),
              ),
            );
          }
          return ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: pins.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: palette.surfaceVariant),
            itemBuilder: (context, index) {
              final pin = pins[index];
              return _PinnedMessageTile(pin: pin);
            },
          );
        },
      ),
        ),
      ],
    );
  }
}

class _PinnedMessageTile extends ConsumerWidget {
  final PinnedMessageData pin;

  const _PinnedMessageTile({required this.pin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appPalette;
    final senderName = pin.senderName ?? 'Unknown';
    final content = pin.messageContent ?? encryptedMessagePreviewPlaceholder;
    final pinnerName = pin.pinnerName ?? '';
    final time = _formatTime(pin.pinnedAt);
    final isActionable = _isActionable(pin);

    return ListTile(
      onTap: isActionable ? () => _handleTap(ref) : null,
      leading: CircleAvatar(
        backgroundColor: palette.surfaceVariant,
        child: Text(
          senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
          style: TextStyle(color: palette.primary),
        ),
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
            time,
            style: TextStyle(color: palette.textSecondary, fontSize: 11),
          ),
          if (isActionable) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.open_in_new_rounded,
              size: 16,
              color: palette.textSecondary,
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            content,
            style: TextStyle(color: palette.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            'Ghim bởi $pinnerName',
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

  bool _isActionable(PinnedMessageData item) {
    if (item.messageType == 'file') return true;
    if (item.messageType != 'text') return false;
    return _extractUrl(item.messageContent ?? '') != null;
  }

  Future<void> _handleTap(WidgetRef ref) async {
    if (pin.messageType == 'file') {
      final metadata =
          pin.messageMetadata ?? await _loadMetadataFromLocalMessage(ref);
      final fileUrl = metadata?['url'] as String?;
      final localPath = metadata?['localPath'] as String?;
      await _openAttachment(fileUrl, localPath: localPath);
      return;
    }

    final url = _extractUrl(pin.messageContent ?? '');
    if (url != null) {
      await _openUrl(url);
    }
  }

  Future<Map<String, dynamic>?> _loadMetadataFromLocalMessage(
    WidgetRef ref,
  ) async {
    final dao = ref.read(chatDaoProvider);
    final message = await dao.getMessage(pin.messageId);
    final metadataJson = message?.metadata;
    if (metadataJson == null || metadataJson.isEmpty) {
      return null;
    }
    final adapter = ref.read(encryptedMessageAdapterProvider);
    return adapter.decodeMetadata(metadataJson);
  }

  static final RegExp _urlRegex = RegExp(r'https?://[^\s]+');

  String? _extractUrl(String content) {
    final match = _urlRegex.firstMatch(content);
    return match?.group(0);
  }

  String _resolveAttachmentUrl(String urlOrPath) {
    if (urlOrPath.startsWith('/uploads')) {
      return '${AppConfig.instance.apiUrl}$urlOrPath';
    }
    return urlOrPath;
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(_resolveAttachmentUrl(url));
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _openAttachment(String? url, {String? localPath}) async {
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

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}';
  }
}
