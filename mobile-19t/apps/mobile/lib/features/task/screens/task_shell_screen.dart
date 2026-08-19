import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../../../shared/widgets/heart_header_badge.dart';
import 'my_task_list_screen.dart';
import 'project_list_screen.dart';
import 'task_list_screen.dart';
import 'task_detail_screen.dart';

enum TaskRootMode { myTask, project }

class TaskShellScreen extends ConsumerStatefulWidget {
  const TaskShellScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  ConsumerState<TaskShellScreen> createState() => _TaskShellScreenState();
}

class _TaskShellScreenState extends ConsumerState<TaskShellScreen> {
  TaskRootMode _mode = TaskRootMode.myTask;
  int? _selectedProjectId;
  int? _selectedTaskId;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 768;
    final palette = context.appPalette;

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Tasks'),
              actions: const [
                Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Center(child: HeartHeaderBadge(compact: true)),
                ),
              ],
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: DropdownButtonFormField<TaskRootMode>(
              initialValue: _mode,
              dropdownColor: palette.card,
              decoration: InputDecoration(
                filled: true,
                fillColor: palette.card,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: palette.surfaceVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: palette.primary),
                ),
              ),
              iconEnabledColor: palette.primary,
              style: TextStyle(color: palette.textPrimary),
              items: const [
                DropdownMenuItem(
                  value: TaskRootMode.myTask,
                  child: Text('My task'),
                ),
                DropdownMenuItem(
                  value: TaskRootMode.project,
                  child: Text('Project'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _mode = value;
                  _selectedProjectId = null;
                  _selectedTaskId = null;
                });
              },
            ),
          ),
          Expanded(
            child: isWide ? _buildWideLayout(palette) : _buildMobileLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    if (_mode == TaskRootMode.myTask) {
      return const MyTaskListScreen(isEmbedded: true);
    }
    return const ProjectListScreen(isEmbedded: true);
  }

  Widget _buildWideLayout(AppThemePalette palette) {
    if (_mode == TaskRootMode.myTask) {
      return Row(
        children: [
          SizedBox(
            width: 420,
            child: MyTaskListScreen(
              isEmbedded: true,
              selectedTaskId: _selectedTaskId,
              onTaskSelected: (id) => setState(() => _selectedTaskId = id),
            ),
          ),
          VerticalDivider(width: 1, color: palette.surfaceVariant),
          if (_selectedTaskId != null)
            Expanded(
              child: TaskDetailScreen(
                key: ValueKey('my-task-$_selectedTaskId'),
                taskId: _selectedTaskId!,
              ),
            )
          else
            const Expanded(child: _EmptyPanel(text: 'Chọn task')),
        ],
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 300,
          child: ProjectListScreen(
            isEmbedded: true,
            selectedProjectId: _selectedProjectId,
            onProjectSelected: (id) => setState(() {
              _selectedProjectId = id;
              _selectedTaskId = null;
            }),
          ),
        ),
        VerticalDivider(width: 1, color: palette.surfaceVariant),
        if (_selectedProjectId != null)
          Expanded(
            child: TaskListScreen(
              key: ValueKey(_selectedProjectId),
              projectId: _selectedProjectId!,
              isEmbedded: true,
              selectedTaskId: _selectedTaskId,
              onTaskSelected: (id) => setState(() => _selectedTaskId = id),
            ),
          )
        else
          const Expanded(child: _EmptyPanel(text: 'Chọn dự án')),
        if (_selectedProjectId != null) ...[
          VerticalDivider(width: 1, color: palette.surfaceVariant),
          if (_selectedTaskId != null)
            Expanded(
              child: TaskDetailScreen(
                key: ValueKey(_selectedTaskId),
                taskId: _selectedTaskId!,
              ),
            )
          else
            const Expanded(child: _EmptyPanel(text: 'Chọn task')),
        ],
      ],
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final String text;
  const _EmptyPanel({required this.text});
  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_outlined, size: 64, color: palette.textHint),
            const SizedBox(height: 16),
            Text(
              text,
              style: TextStyle(color: palette.textSecondary, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
