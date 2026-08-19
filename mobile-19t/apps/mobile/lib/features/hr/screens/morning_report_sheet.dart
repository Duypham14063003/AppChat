import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../task/models/task_models.dart';
import '../../task/providers/task_providers.dart';
import '../../auth/providers/auth_notifier.dart';
import '../data/daily_report_models.dart';
import '../providers/daily_report_providers.dart';

/// Shows the morning report bottom sheet.
/// If [existingReport] is provided, the sheet is in edit mode.
Future<bool?> showMorningReportSheet(
  BuildContext context, {
  DailyReport? existingReport,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MorningReportSheet(existingReport: existingReport),
  );
}

class _MorningReportSheet extends ConsumerStatefulWidget {
  const _MorningReportSheet({this.existingReport});
  final DailyReport? existingReport;

  @override
  ConsumerState<_MorningReportSheet> createState() =>
      _MorningReportSheetState();
}

class _MorningReportSheetState extends ConsumerState<_MorningReportSheet> {
  final _noteController = TextEditingController();
  final List<_ProjectSelection> _projectSelections = [];
  bool _isSending = false;
  ReportRole _selectedRole = ReportRole.dev;

  bool get _isEditing => widget.existingReport != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _prefillFromExisting();
    } else {
      _projectSelections.add(_ProjectSelection());
      final configRoles =
          ref.read(authNotifierProvider).valueOrNull?.configRoles ?? [];
      final hasQcRole = configRoles.any((r) => r.toLowerCase() == 'qc');
      if (hasQcRole) {
        _selectedRole = ReportRole.qc;
      } else {
        _selectedRole = ReportRole.dev;
      }
    }
  }

  void _prefillFromExisting() {
    final report = widget.existingReport!;
    _noteController.text = report.note ?? '';

    // Override existing role with actual user profile role
    final configRoles =
        ref.read(authNotifierProvider).valueOrNull?.configRoles ?? [];
    final hasQcRole = configRoles.any((r) => r.toLowerCase() == 'qc');
    if (hasQcRole) {
      _selectedRole = ReportRole.qc;
    } else {
      _selectedRole = ReportRole.dev;
    }

    for (final project in report.projects) {
      _projectSelections.add(
        _ProjectSelection(
          projectId: project.projectId,
          projectName: project.projectName,
          selectedTaskIds: project.tasks.map((t) => t.task.id).toSet(),
        ),
      );
    }
    if (_projectSelections.isEmpty) {
      _projectSelections.add(_ProjectSelection());
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _addProject() {
    setState(() => _projectSelections.add(_ProjectSelection()));
  }

  void _removeProject(int index) {
    if (_projectSelections.length <= 1) return;
    setState(() => _projectSelections.removeAt(index));
  }

  Future<void> _submit() async {
    // Validate: at least one project with at least one task
    final validProjects = <DailyReportProject>[];
    for (final sel in _projectSelections) {
      if (sel.projectId == null || sel.selectedTaskIds.isEmpty) continue;

      final invalidTasks = sel.loadedTasks
          .where(
            (t) =>
                sel.selectedTaskIds.contains(t.id) &&
                (t.assignees.isEmpty || t.tagIds.isEmpty),
          )
          .toList();
      if (invalidTasks.isNotEmpty) {
        if (!mounted) return;
        showTopSnackBar(
          context,
          message:
              'Không thể báo cáo task thiếu người phụ trách hoặc tag: ${invalidTasks.first.name}',
          backgroundColor: AppColors.danger,
        );
        return;
      }

      final tasks = sel.loadedTasks
          .where((t) => sel.selectedTaskIds.contains(t.id))
          .map((t) => DailyReportTask(task: t))
          .toList();
      if (tasks.isEmpty) continue;
      validProjects.add(
        DailyReportProject(
          projectId: sel.projectId!,
          projectName: sel.projectName ?? '',
          tasks: tasks,
        ),
      );
    }

    if (validProjects.isEmpty) {
      if (!mounted) return;
      showTopSnackBar(
        context,
        message: 'Vui lòng chọn ít nhất 1 task để báo cáo',
        backgroundColor: AppColors.warning,
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      final notifier = ref.read(todayReportsProvider.notifier);
      if (_isEditing) {
        await notifier.updateReport(
          reportId: widget.existingReport!.id,
          reportType: 'morning',
          reportRole: _selectedRole,
          projects: validProjects,
          note: _noteController.text,
        );
      } else {
        await notifier.submit(
          reportType: 'morning',
          reportRole: _selectedRole,
          projects: validProjects,
          note: _noteController.text,
        );
      }
      if (!mounted) return;
      showTopSnackBar(
        context,
        message: _isEditing
            ? 'Đã cập nhật báo cáo sáng!'
            : 'Đã gửi báo cáo sáng!',
        backgroundColor: AppColors.online,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      showTopSnackBar(
        context,
        message: 'Gửi báo cáo thất bại: $e',
        backgroundColor: AppColors.danger,
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: palette.surfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  _isEditing ? 'Sửa báo cáo sáng' : 'Báo cáo công việc sáng',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Scrollable content
          Flexible(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
              shrinkWrap: true,
              children: [
                // Role toggle removed, role is auto-detected from user profile.
                const SizedBox(height: 16),
                // Project sections
                for (int i = 0; i < _projectSelections.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  _ProjectTaskSelector(
                    key: ValueKey('proj_$i'),
                    index: i,
                    selection: _projectSelections[i],
                    palette: palette,
                    canRemove: _projectSelections.length > 1,
                    usedProjectIds: _projectSelections
                        .where((s) => s != _projectSelections[i])
                        .map((s) => s.projectId)
                        .whereType<int>()
                        .toSet(),
                    onChanged: () => setState(() {}),
                    onRemove: () => _removeProject(i),
                  ),
                ],
                const SizedBox(height: 12),
                // Add project button
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _addProject,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Thêm dự án'),
                  ),
                ),
                const SizedBox(height: 16),
                // Note
                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  style: TextStyle(color: palette.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Ghi chú (tuỳ chọn)',
                    labelStyle: TextStyle(color: palette.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: palette.surfaceVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: palette.surfaceVariant),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Submit button
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSending ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.online,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isEditing ? 'Cập nhật báo cáo' : 'Gửi báo cáo',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Holds selection state for one project in the report
class _ProjectSelection {
  int? projectId;
  String? projectName;
  final Set<int> selectedTaskIds;
  List<Task> loadedTasks;

  _ProjectSelection({
    this.projectId,
    this.projectName,
    Set<int>? selectedTaskIds,
  }) : selectedTaskIds = selectedTaskIds ?? {},
       loadedTasks = [];
}

class _ProjectTaskSelector extends ConsumerStatefulWidget {
  const _ProjectTaskSelector({
    super.key,
    required this.index,
    required this.selection,
    required this.palette,
    required this.canRemove,
    required this.usedProjectIds,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _ProjectSelection selection;
  final AppThemePalette palette;
  final bool canRemove;
  final Set<int> usedProjectIds;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  ConsumerState<_ProjectTaskSelector> createState() =>
      _ProjectTaskSelectorState();
}

class _ProjectTaskSelectorState extends ConsumerState<_ProjectTaskSelector> {
  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectListProvider);
    final sel = widget.selection;
    final palette = widget.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.surfaceVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Icon(Icons.folder_outlined, size: 18, color: palette.primary),
              const SizedBox(width: 8),
              Text(
                'Dự án ${widget.index + 1}',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (widget.canRemove)
                IconButton(
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.danger,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    maxWidth: 32,
                    maxHeight: 32,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Project dropdown
          projectsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(
              'Lỗi tải dự án: $e',
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
            data: (projects) {
              final available = projects
                  .where(
                    (p) =>
                        !widget.usedProjectIds.contains(p.id) ||
                        p.id == sel.projectId,
                  )
                  .toList();
              return DropdownButtonFormField<int>(
                value: sel.projectId,
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: palette.surfaceVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: palette.surfaceVariant),
                  ),
                ),
                dropdownColor: palette.card,
                style: TextStyle(color: palette.textPrimary, fontSize: 14),
                hint: Text(
                  'Chọn dự án',
                  style: TextStyle(color: palette.textSecondary),
                ),
                items: available
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  final project = available.firstWhere((p) => p.id == id);
                  setState(() {
                    sel.projectId = id;
                    sel.projectName = project.name;
                    sel.selectedTaskIds.clear();
                    sel.loadedTasks = [];
                  });
                  widget.onChanged();
                },
              );
            },
          ),
          // Tasks list
          if (sel.projectId != null) ...[
            const SizedBox(height: 12),
            _TaskCheckboxList(
              projectId: sel.projectId!,
              selectedIds: sel.selectedTaskIds,
              loadedTasks: sel.loadedTasks,
              palette: palette,
              onTasksLoaded: (tasks) => sel.loadedTasks = tasks,
              onChanged: widget.onChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class _TaskCheckboxList extends ConsumerStatefulWidget {
  const _TaskCheckboxList({
    required this.projectId,
    required this.selectedIds,
    required this.loadedTasks,
    required this.palette,
    required this.onTasksLoaded,
    required this.onChanged,
  });

  final int projectId;
  final Set<int> selectedIds;
  final List<Task> loadedTasks;
  final AppThemePalette palette;
  final void Function(List<Task>) onTasksLoaded;
  final VoidCallback onChanged;

  @override
  ConsumerState<_TaskCheckboxList> createState() => _TaskCheckboxListState();
}

class _TaskCheckboxListState extends ConsumerState<_TaskCheckboxList> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedStage; // null = tất cả
  bool _showSelectedOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Task> _filterTasks(List<Task> tasks) {
    var filtered = tasks;

    // Filter by stage
    if (_selectedStage != null) {
      filtered = filtered
          .where(
            (t) =>
                t.stage != null &&
                t.stage!.name.toUpperCase() == _selectedStage!.toUpperCase(),
          )
          .toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where((t) => t.name.toLowerCase().contains(query))
          .toList();
    }

    return filtered;
  }

  /// Extract unique stage names from tasks
  List<String> _extractStages(List<Task> tasks) {
    final stages = <String>{};
    for (final task in tasks) {
      if (task.stage != null && task.stage!.name.isNotEmpty) {
        stages.add(task.stage!.name.toUpperCase());
      }
    }
    // Sort by common order
    const order = [
      'BACKLOG',
      'MUST',
      'CODING',
      'STAGING',
      'PRODUCTION',
      'COMPLETED',
    ];
    final sorted = stages.toList()
      ..sort((a, b) {
        final ia = order.indexOf(a);
        final ib = order.indexOf(b);
        if (ia == -1 && ib == -1) return a.compareTo(b);
        if (ia == -1) return 1;
        if (ib == -1) return -1;
        return ia.compareTo(ib);
      });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(projectTaskListProvider(widget.projectId));
    final palette = widget.palette;

    return tasksAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Text(
        'Lỗi tải tasks: $e',
        style: const TextStyle(color: AppColors.danger, fontSize: 13),
      ),
      data: (tasks) {
        // Cache loaded tasks for serialization
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final taskIds = tasks.map((task) => task.id).toSet();
          final removedIds = widget.selectedIds.difference(taskIds);
          if (removedIds.isNotEmpty) {
            widget.selectedIds.removeAll(removedIds);
            widget.onChanged();
          }
          widget.onTasksLoaded(tasks);
        });

        if (tasks.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Chưa có task nào trong dự án',
              style: TextStyle(color: palette.textSecondary, fontSize: 13),
            ),
          );
        }

        final stages = _extractStages(tasks);
        final filteredTasks = _filterTasks(tasks);
        final selectedTasks = tasks
            .where((task) => widget.selectedIds.contains(task.id))
            .toList(growable: false);
        final selectedCount = selectedTasks.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (selectedCount > 0)
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ActionChip(
                          avatar: Icon(
                            _showSelectedOnly
                                ? Icons.checklist_rtl
                                : Icons.visibility_outlined,
                            size: 16,
                            color: palette.primary,
                          ),
                          label: Text(
                            _showSelectedOnly
                                ? 'Đang xem task đã chọn'
                                : 'Xem $selectedCount task đã chọn',
                            style: TextStyle(
                              color: palette.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: palette.primary.withValues(
                            alpha: 0.10,
                          ),
                          side: BorderSide(
                            color: palette.primary.withValues(alpha: 0.25),
                          ),
                          onPressed: () {
                            setState(() {
                              _showSelectedOnly = !_showSelectedOnly;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                IconButton(
                  tooltip: 'Làm mới task',
                  onPressed: () async {
                    await ref
                        .read(
                          projectTaskListProvider(widget.projectId).notifier,
                        )
                        .refresh();
                  },
                  icon: Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color: palette.primary,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (_showSelectedOnly && selectedTasks.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: palette.primary.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Task đã chọn',
                      style: TextStyle(
                        color: palette.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final task in selectedTasks) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.check_circle,
                              size: 14,
                              color: palette.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              task.name,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (task != selectedTasks.last) const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            // Search field
            SizedBox(
              height: 38,
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: palette.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Tìm task...',
                  hintStyle: TextStyle(
                    color: palette.textSecondary.withOpacity(0.6),
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: palette.textSecondary,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: palette.textSecondary,
                          ),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  isDense: true,
                  filled: true,
                  fillColor: palette.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: palette.surfaceVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: palette.surfaceVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: palette.primary, width: 1.5),
                  ),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            // Stage filter chips
            if (stages.length > 1) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 30,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _StageChip(
                      label: 'Tất cả',
                      isSelected: _selectedStage == null,
                      palette: palette,
                      onTap: () => setState(() => _selectedStage = null),
                    ),
                    for (final stage in stages) ...[
                      const SizedBox(width: 6),
                      _StageChip(
                        label: stage,
                        isSelected:
                            _selectedStage?.toUpperCase() ==
                            stage.toUpperCase(),
                        palette: palette,
                        onTap: () => setState(
                          () => _selectedStage = _selectedStage == stage
                              ? null
                              : stage,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            // Selected count + result info
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Row(
                children: [
                  Text(
                    'Đã chọn: $selectedCount',
                    style: TextStyle(
                      color: palette.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (_searchQuery.isNotEmpty || _selectedStage != null)
                    Text(
                      '${filteredTasks.length}/${tasks.length} tasks',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            // Task list
            if ((_showSelectedOnly ? selectedTasks : filteredTasks).isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _showSelectedOnly
                      ? 'Chưa có task nào được chọn'
                      : 'Không tìm thấy task phù hợp',
                  style: TextStyle(color: palette.textSecondary, fontSize: 13),
                ),
              )
            else
              ...(_showSelectedOnly ? selectedTasks : filteredTasks).map((
                task,
              ) {
                final isSelected = widget.selectedIds.contains(task.id);
                return CheckboxListTile(
                  value: isSelected,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: palette.primary,
                  title: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (task.isSubtask) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.subdirectory_arrow_right_rounded,
                            size: 15,
                            color: palette.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          task.name,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  subtitle:
                      (task.isSubtask ||
                          task.stage != null ||
                          task.assignees.isEmpty ||
                          task.tagIds.isEmpty)
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (task.isSubtask)
                              Text(
                                task.parentName == null
                                    ? 'Subtask'
                                    : 'Subtask của ${task.parentName}',
                                style: TextStyle(
                                  color: palette.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (task.stage != null)
                              Text(
                                task.stage!.name,
                                style: TextStyle(
                                  color: _stageColor(task.stage!.name),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (task.assignees.isEmpty || task.tagIds.isEmpty)
                              Container(
                                margin: EdgeInsets.only(
                                  top: task.stage != null || task.isSubtask
                                      ? 4
                                      : 0,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Thiếu người phụ trách hoặc tag',
                                  style: TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        )
                      : null,
                  onChanged: (checked) {
                    if (checked == true) {
                      widget.selectedIds.add(task.id);
                    } else {
                      widget.selectedIds.remove(task.id);
                    }
                    widget.onChanged();
                  },
                );
              }),
          ],
        );
      },
    );
  }

  Color _stageColor(String stageName) {
    switch (stageName.toUpperCase()) {
      case 'BACKLOG':
        return Colors.blueGrey;
      case 'MUST':
        return Colors.orange;
      case 'CODING':
        return Colors.blue;
      case 'STAGING':
        return Colors.purple;
      case 'PRODUCTION':
        return Colors.teal;
      case 'COMPLETED':
        return AppColors.online;
      default:
        return widget.palette.textSecondary;
    }
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({
    required this.label,
    required this.isSelected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final AppThemePalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _chipColor(label);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : palette.surfaceVariant,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : palette.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Color _chipColor(String label) {
    switch (label.toUpperCase()) {
      case 'BACKLOG':
        return Colors.blueGrey;
      case 'MUST':
        return Colors.orange;
      case 'CODING':
        return Colors.blue;
      case 'STAGING':
        return Colors.purple;
      case 'PRODUCTION':
        return Colors.teal;
      case 'COMPLETED':
        return AppColors.online;
      default:
        return palette.primary;
    }
  }
}

class _RoleToggle extends StatelessWidget {
  const _RoleToggle({
    required this.selected,
    required this.palette,
    required this.onChanged,
  });

  final ReportRole selected;
  final AppThemePalette palette;
  final ValueChanged<ReportRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Vai trò:',
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        for (final role in ReportRole.values) ...[
          if (role != ReportRole.values.first) const SizedBox(width: 8),
          _RoleChip(
            label: role.label,
            isSelected: selected == role,
            palette: palette,
            onTap: () => onChanged(role),
          ),
        ],
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.isSelected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final AppThemePalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? palette.primary.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? palette.primary : palette.surfaceVariant,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? palette.primary : palette.textSecondary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
