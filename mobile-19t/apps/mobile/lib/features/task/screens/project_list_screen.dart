import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../providers/task_providers.dart';
import '../models/task_models.dart';

class ProjectListScreen extends ConsumerWidget {
  final bool isEmbedded;
  final int? selectedProjectId;
  final ValueChanged<int>? onProjectSelected;

  const ProjectListScreen({
    super.key,
    this.isEmbedded = false,
    this.selectedProjectId,
    this.onProjectSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appPalette;
    final projectsAsync = ref.watch(projectListProvider);

    return Scaffold(
      appBar: isEmbedded ? null : AppBar(title: const Text('Dự án')),
      body: projectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: palette.textHint),
              const SizedBox(height: 12),
              Text(
                'Không thể tải dự án',
                style: TextStyle(color: palette.textSecondary),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    ref.read(projectListProvider.notifier).refresh(),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
        data: (projects) {
          if (projects.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_open, size: 48, color: palette.textHint),
                  SizedBox(height: 12),
                  Text(
                    'Chưa có dự án nào',
                    style: TextStyle(color: palette.textSecondary),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(projectListProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: projects.length,
              itemBuilder: (context, index) {
                final project = projects[index];
                final isSelected = project.id == selectedProjectId;
                return _ProjectCard(
                  project: project,
                  isSelected: isSelected,
                  onTap: () {
                    if (onProjectSelected != null) {
                      onProjectSelected!(project.id);
                    } else {
                      context.push(
                        '/tasks/projects/${project.id}',
                        extra: project.name,
                      );
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProjectCard({
    required this.project,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: isSelected ? palette.surfaceVariant : palette.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (project.managerName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          project.managerName!,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${project.taskCount}',
                    style: TextStyle(
                      color: palette.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
