import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../models/task_models.dart';
import '../providers/task_providers.dart';
import '../widgets/task_card.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends ConsumerStatefulWidget {
  final int projectId;
  final String? projectName;
  final bool isEmbedded;
  final int? selectedTaskId;
  final ValueChanged<int>? onTaskSelected;

  const TaskListScreen({
    super.key,
    required this.projectId,
    this.projectName,
    this.isEmbedded = false,
    this.selectedTaskId,
    this.onTaskSelected,
  });

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  TaskStageName? _selectedStage;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final tasksAsync = ref.watch(projectTaskListProvider(widget.projectId));

    return Scaffold(
      appBar: widget.isEmbedded
          ? null
          : AppBar(title: Text(widget.projectName ?? 'Tasks')),
      body: Column(
        children: [
          // Filter chips row
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: const Text('Tất cả'),
                    selected: _selectedStage == null,
                    selectedColor: palette.primary.withValues(alpha: 0.15),
                    checkmarkColor: palette.primary,
                    onSelected: (_) => _onStageFilter(null),
                  ),
                ),
                for (final stage in TaskStageName.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(stage.label),
                      selected: _selectedStage == stage,
                      selectedColor: palette.primary.withValues(alpha: 0.15),
                      checkmarkColor: palette.primary,
                      onSelected: (_) => _onStageFilter(stage),
                    ),
                  ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.sort, color: palette.textSecondary),
                  onSelected: _onSort,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'deadline', child: Text('Deadline')),
                    PopupMenuItem(value: 'priority', child: Text('Ưu tiên')),
                    PopupMenuItem(
                      value: 'assignee',
                      child: Text('Người thực hiện'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Task list
          Expanded(
            child: tasksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: palette.textHint,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Không thể tải tasks',
                      style: TextStyle(color: palette.textSecondary),
                    ),
                    TextButton(
                      onPressed: () => ref
                          .read(
                            projectTaskListProvider(widget.projectId).notifier,
                          )
                          .refresh(),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
              data: (tasks) {
                if (tasks.isEmpty) {
                  return Center(
                    child: Text(
                      'Chưa có task nào',
                      style: TextStyle(color: palette.textSecondary),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref
                      .read(projectTaskListProvider(widget.projectId).notifier)
                      .refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return TaskCard(
                        task: task,
                        isSelected: task.id == widget.selectedTaskId,
                        onTap: () {
                          if (widget.onTaskSelected != null) {
                            widget.onTaskSelected!(task.id);
                          } else {
                            final isWide =
                                MediaQuery.of(context).size.width >= 768;
                            if (isWide) {
                              showDialog(
                                context: context,
                                builder: (dialogCtx) => Dialog(
                                  backgroundColor: palette.surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: SizedBox(
                                    width: 640,
                                    height: 800,
                                    child: TaskDetailScreen(
                                      taskId: task.id,
                                      asDialog: true,
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              context.push('/tasks/${task.id}');
                            }
                          }
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _onStageFilter(TaskStageName? stage) {
    setState(() => _selectedStage = stage);
    ref
        .read(projectTaskListProvider(widget.projectId).notifier)
        .setFilter(stageName: stage?.apiValue);
  }

  void _onSort(String sort) {
    ref.read(projectTaskListProvider(widget.projectId).notifier).setSort(sort);
  }
}
