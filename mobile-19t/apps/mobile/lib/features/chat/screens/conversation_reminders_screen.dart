import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../models/chat_reminder.dart';
import '../providers/chat_reminder_provider.dart';
import 'package:intl/intl.dart';

class ConversationRemindersScreen extends ConsumerWidget {
  final String conversationId;
  final bool asDialog;

  const ConversationRemindersScreen({
    super.key,
    required this.conversationId,
    this.asDialog = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appPalette;
    final remindersAsync = ref.watch(conversationRemindersProvider(conversationId));

    final bodyContent = remindersAsync.when(
      data: (reminders) {
        if (reminders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none_rounded, size: 64, color: palette.textHint),
                const SizedBox(height: 16),
                Text(
                  'Không có lời nhắc nào',
                  style: TextStyle(color: palette.textSecondary),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reminders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final reminder = reminders[index];
            return _ReminderCard(reminder: reminder);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Lỗi: $error')),
    );

    if (asDialog) {
      return bodyContent;
    }

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Lời nhắc hẹn'),
        backgroundColor: palette.surface,
        foregroundColor: palette.textPrimary,
        elevation: 0,
      ),
      body: bodyContent,
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final ChatReminder reminder;

  const _ReminderCard({required this.reminder});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final timeFormat = DateFormat('HH:mm, dd/MM/yyyy');

    return InkWell(
      onTap: () {
        Navigator.of(context).pop(reminder.messageId);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.surfaceVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 18, color: palette.primary),
                const SizedBox(width: 8),
                Text(
                  timeFormat.format(reminder.remindAt.toLocal()),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                _ScopeBadge(scope: reminder.scope),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Trạng thái: ${reminder.status == 'pending' ? 'Đang chờ' : reminder.status}',
              style: TextStyle(color: palette.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeBadge extends StatelessWidget {
  final String scope;

  const _ScopeBadge({required this.scope});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final isEveryone = scope == 'everyone';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isEveryone ? palette.primary.withValues(alpha: 0.1) : palette.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isEveryone ? 'Mọi người' : 'Chỉ mình tôi',
        style: TextStyle(
          color: isEveryone ? palette.primary : palette.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
