import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../data/chat_avatar_resolver.dart';
import '../providers/chat_providers.dart';
import 'chat_avatar.dart';

Future<void> showMessageSeenBySheet({
  required BuildContext context,
  required String conversationId,
  required String messageId,
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
          height: 400,
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
                      'Đã xem bởi',
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _MessageSeenBySheet(
                    conversationId: conversationId,
                    messageId: messageId,
                    asDialog: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  } else {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MessageSeenBySheet(
        conversationId: conversationId,
        messageId: messageId,
      ),
    );
  }
}

class _MessageSeenBySheet extends ConsumerWidget {
  const _MessageSeenBySheet({
    required this.conversationId,
    required this.messageId,
    this.asDialog = false,
  });

  final String conversationId;
  final String messageId;
  final bool asDialog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appPalette;
    final seenByAsync = ref.watch(
      messageSeenByProvider((convId: conversationId, messageId: messageId)),
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!asDialog) ...[
          Text(
            'Đã xem bởi',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Flexible(
          child: seenByAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, _) =>
                _SeenByStateMessage(message: _seenByErrorMessage(error)),
            data: (response) {
              if (response.seenBy.isEmpty) {
                return const _SeenByStateMessage(message: 'Chưa có ai xem');
              }

              return ListView.separated(
                shrinkWrap: true,
                itemCount: response.seenBy.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: palette.surfaceVariant),
                itemBuilder: (context, index) {
                  final user = response.seenBy[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ChatAvatar(
                      displayName: user.name,
                      imageUrl: resolveChatAvatarUrl(user.avatarUrl),
                      radius: 22,
                    ),
                    title: Text(
                      user.name.isNotEmpty ? user.name : 'Thành viên',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: user.seenAt == null
                        ? null
                        : Text(
                            _formatSeenAt(user.seenAt!),
                            style: TextStyle(color: palette.textSecondary),
                          ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    if (asDialog) {
      return content;
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: content,
      ),
    );
  }
}

class _SeenByStateMessage extends StatelessWidget {
  const _SeenByStateMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.textSecondary, fontSize: 14),
        ),
      ),
    );
  }
}

String _seenByErrorMessage(Object error) {
  if (error is DioException) {
    final statusCode = error.response?.statusCode;
    switch (statusCode) {
      case 400:
        return 'Tin nhắn này không còn hỗ trợ xem đã xem';
      case 403:
        return 'Bạn không có quyền xem danh sách đã xem';
      case 404:
        return 'Tin nhắn không còn tồn tại';
    }
  }
  return 'Không thể tải danh sách đã xem';
}

String _formatSeenAt(DateTime seenAt) {
  final day = seenAt.day.toString().padLeft(2, '0');
  final month = seenAt.month.toString().padLeft(2, '0');
  final year = seenAt.year.toString();
  final hour = seenAt.hour.toString().padLeft(2, '0');
  final minute = seenAt.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}
