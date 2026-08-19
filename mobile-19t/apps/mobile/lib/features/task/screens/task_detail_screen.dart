import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../providers/task_providers.dart';
import '../models/task_models.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  final int taskId;
  final bool asDialog;
  const TaskDetailScreen({
    super.key,
    required this.taskId,
    this.asDialog = false,
  });
  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  final _ctrl = TextEditingController();
  bool _sending = false;
  bool _subtasksExpanded = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final taskAsync = ref.watch(taskDetailProvider(widget.taskId));
    final notesAsync = ref.watch(logNotesProvider(widget.taskId));

    final customHeader = widget.asDialog
        ? Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: palette.surfaceVariant)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.close, color: palette.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                Text(
                  'Chi tiết task',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        : const SizedBox.shrink();

    return Scaffold(
      backgroundColor: palette.background,
      appBar: widget.asDialog
          ? null
          : AppBar(title: const Text('Chi tiết task')),
      body: Column(
        children: [
          customHeader,
          Expanded(
            child: taskAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Lỗi: $e',
                  style: TextStyle(color: palette.textSecondary),
                ),
              ),
              data: (task) => task == null
                  ? Center(
                      child: Text(
                        'Không tìm thấy task',
                        style: TextStyle(color: palette.textSecondary),
                      ),
                    )
                  : _body(task, notesAsync),
            ),
          ),
          _noteInput(),
        ],
      ),
    );
  }

  Widget _body(Task task, AsyncValue<List<LogNote>> notesAsync) {
    final palette = context.appPalette;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.name,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (task.stage != null) _badge(task.stage!.name, AppColors.info),
              if (task.dateDeadline != null) _deadlineBadge(task.dateDeadline!),
              if (task.priority > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    task.priority,
                    (_) =>
                        const Icon(Icons.star, size: 16, color: AppColors.gold),
                  ),
                ),
            ],
          ),
          if (task.assignees.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: task.assignees
                  .map(
                    (a) => Chip(
                      avatar: CircleAvatar(
                        backgroundColor: palette.surfaceVariant,
                        child: Text(
                          a.name[0].toUpperCase(),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      label: Text(a.name, style: const TextStyle(fontSize: 12)),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (task.description != null && task.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Mô tả',
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            HtmlWidget(
              task.description!,
              textStyle: TextStyle(color: palette.textPrimary, fontSize: 14),
            ),
          ],
          if (task.subtaskCount > 0) ...[
            const SizedBox(height: 20),
            _subtasksSection(task),
          ],
          const SizedBox(height: 20),
          Text(
            'Ghi chú',
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _notes(notesAsync),
        ],
      ),
    );
  }

  Widget _subtasksSection(Task task) {
    final palette = context.appPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _subtasksExpanded = !_subtasksExpanded),
          child: Row(
            children: [
              Icon(
                _subtasksExpanded ? Icons.expand_less : Icons.expand_more,
                color: palette.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                'Subtasks (${task.subtaskCount})',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (_subtasksExpanded) _subtasksList(),
      ],
    );
  }

  Widget _subtasksList() {
    final palette = context.appPalette;
    final subtasksAsync = ref.watch(subtaskListProvider(widget.taskId));
    return subtasksAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          'Lỗi: $e',
          style: TextStyle(color: palette.textSecondary, fontSize: 12),
        ),
      ),
      data: (subtasks) {
        if (subtasks.isEmpty)
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Không có subtask',
              style: TextStyle(color: palette.textHint, fontSize: 12),
            ),
          );
        return Column(
          children: subtasks.map((st) => _subtaskTile(st)).toList(),
        );
      },
    );
  }

  Widget _subtaskTile(Task subtask) {
    final palette = context.appPalette;
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: palette.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                subtask.name,
                style: TextStyle(color: palette.textPrimary, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (subtask.stage != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  subtask.stage!.name,
                  style: const TextStyle(
                    color: AppColors.info,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _notes(AsyncValue<List<LogNote>> notesAsync) {
    final palette = context.appPalette;
    return notesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text(
        'Lỗi tải ghi chú',
        style: TextStyle(color: palette.textSecondary),
      ),
      data: (notes) {
        if (notes.isEmpty)
          return Text(
            'Chưa có ghi chú',
            style: TextStyle(color: palette.textHint, fontSize: 13),
          );
        return Column(children: notes.map(_noteCard).toList());
      },
    );
  }

  Widget _noteCard(LogNote note) {
    final palette = context.appPalette;
    final date = DateTime.tryParse(note.date);
    final rel = date != null ? _relativeTime(date) : note.date;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  note.authorName ?? 'Hệ thống',
                  style: TextStyle(
                    color: palette.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  rel,
                  style: TextStyle(color: palette.textHint, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 6),
            HtmlWidget(
              note.body,
              textStyle: TextStyle(color: palette.textPrimary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noteInput() {
    final palette = context.appPalette;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.surfaceVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: TextStyle(color: palette.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Nhập ghi chú...',
                  hintStyle: TextStyle(color: palette.textHint),
                  filled: true,
                  fillColor: palette.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: _sending
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.primary,
                      ),
                    )
                  : Icon(Icons.send, color: palette.primary),
              onPressed: _sending ? null : _submitNote,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitNote() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    _ctrl.clear();
    try {
      await ref
          .read(logNotesProvider(widget.taskId).notifier)
          .createLogNote(text);
    } catch (e) {
      if (mounted) showTopSnackBar(context, message: 'Lỗi: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _deadlineBadge(String deadline) {
    final date = DateTime.tryParse(deadline);
    if (date == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final diff = date.difference(DateTime(now.year, now.month, now.day)).inDays;
    final color = diff < 0
        ? AppColors.danger
        : diff <= 3
        ? AppColors.warning
        : AppColors.textSecondary;
    final label = diff < 0
        ? 'Quá hạn ${-diff} ngày'
        : diff == 0
        ? 'Hôm nay'
        : diff == 1
        ? 'Ngày mai'
        : '${date.day}/${date.month}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule, size: 14, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }

  static String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
