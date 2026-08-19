import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../models/task_models.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final bool isSelected;
  final VoidCallback onTap;

  const TaskCard({
    super.key,
    required this.task,
    this.isSelected = false,
    required this.onTap,
  });

  static const _stageColors = [
    AppColors.textSecondary,
    AppColors.warning,
    AppColors.info,
    AppColors.online,
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Padding(
      padding: EdgeInsets.only(
        left: task.isSubtask ? 28 : 12,
        right: 12,
        top: 4,
        bottom: 4,
      ),
      child: Material(
        color: isSelected ? palette.surfaceVariant : palette.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task.isSubtask) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.subdirectory_arrow_right_rounded,
                        size: 14,
                        color: palette.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          task.parentName == null
                              ? 'Subtask'
                              : 'Subtask của ${task.parentName}',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.name,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (task.priority > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          task.priority,
                          (_) => Icon(
                            Icons.star,
                            size: 14,
                            color: palette.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (task.stage != null) ...[
                      _StageBadge(
                        name: task.stage!.name,
                        stageId: task.stage!.id,
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (task.dateDeadline != null) ...[
                      _DeadlineBadge(deadline: task.dateDeadline!),
                      const SizedBox(width: 8),
                    ],
                    if (task.subtaskCount > 0) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_tree_outlined,
                            size: 13,
                            color: palette.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${task.subtaskCount}',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Spacer(),
                    if (task.assignees.isNotEmpty)
                      _AssigneeAvatars(assignees: task.assignees),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StageBadge extends StatelessWidget {
  final String name;
  final int stageId;
  const _StageBadge({required this.name, required this.stageId});

  @override
  Widget build(BuildContext context) {
    final colorIndex = stageId % TaskCard._stageColors.length;
    final color = TaskCard._stageColors[colorIndex];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DeadlineBadge extends StatelessWidget {
  final String deadline;
  const _DeadlineBadge({required this.deadline});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final date = DateTime.tryParse(deadline);
    if (date == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final diff = date.difference(DateTime(now.year, now.month, now.day)).inDays;
    final Color color;
    if (diff < 0) {
      color = AppColors.danger;
    } else if (diff <= 3) {
      color = AppColors.warning;
    } else {
      color = palette.textSecondary;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          '${date.day}/${date.month}',
          style: TextStyle(color: color, fontSize: 11),
        ),
      ],
    );
  }
}

class _AssigneeAvatars extends StatelessWidget {
  final List<TaskAssignee> assignees;
  const _AssigneeAvatars({required this.assignees});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final shown = assignees.take(3).toList();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final a in shown)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: CircleAvatar(
              radius: 11,
              backgroundColor: palette.surfaceVariant,
              child: Text(
                a.name.isNotEmpty ? a.name[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 10, color: palette.textPrimary),
              ),
            ),
          ),
        if (assignees.length > 3)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              '+${assignees.length - 3}',
              style: TextStyle(fontSize: 10, color: palette.textSecondary),
            ),
          ),
      ],
    );
  }
}
