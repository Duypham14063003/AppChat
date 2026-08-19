import 'package:dio/dio.dart';
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

/// Shows the OT report bottom sheet.
/// If [existingReport] is provided, the sheet is in edit mode.
Future<bool?> showOtReportSheet(
  BuildContext context, {
  DailyReport? existingReport,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _OtReportSheet(existingReport: existingReport),
  );
}

class _OtReportSheet extends ConsumerStatefulWidget {
  const _OtReportSheet({this.existingReport});
  final DailyReport? existingReport;

  @override
  ConsumerState<_OtReportSheet> createState() => _OtReportSheetState();
}

class _OtReportSheetState extends ConsumerState<_OtReportSheet> {
  final _noteController = TextEditingController();
  final List<_OtProjectSelection> _projectSelections = [];
  bool _isSending = false;
  late ReportRole _role;

  bool get _isEditing => widget.existingReport != null;
  bool get _isQc => _role == ReportRole.qc;

  @override
  void initState() {
    super.initState();
    // Resolve role from user profile
    final configRoles =
        ref.read(authNotifierProvider).valueOrNull?.configRoles ?? [];
    final hasQcRole = configRoles.any((r) => r.toLowerCase() == 'qc');
    _role = hasQcRole ? ReportRole.qc : ReportRole.dev;

    if (_isEditing) {
      _prefillFromExisting();
    } else {
      _projectSelections.add(_OtProjectSelection());
    }
  }

  void _prefillFromExisting() {
    final report = widget.existingReport!;
    _noteController.text = report.note ?? '';

    for (final project in report.projects) {
      final sel = _OtProjectSelection(
        projectId: project.projectId,
        projectName: project.projectName,
        selectedTaskIds: project.tasks.map((t) => t.task.id).toSet(),
      );
      // Prefill task states
      for (final t in project.tasks) {
        sel.taskStates[t.task.id] = _OtTaskState(
          task: t.task,
          status: t.status ?? 'done',
          progress: t.progress ?? 50,
          qcStatus: (t.qcFail ?? 0) > 0
              ? 'fail'
              : (t.qcMiss ?? 0) > 0
              ? 'miss'
              : 'done',
          qcNote: t.qcNote ?? '',
        );
      }
      _projectSelections.add(sel);
    }

    if (_projectSelections.isEmpty) {
      _projectSelections.add(_OtProjectSelection());
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _addProject() {
    setState(() => _projectSelections.add(_OtProjectSelection()));
  }

  void _removeProject(int index) {
    if (_projectSelections.length <= 1) return;
    setState(() => _projectSelections.removeAt(index));
  }

  Future<void> _submit() async {
    final validProjects = <DailyReportProject>[];

    for (final sel in _projectSelections) {
      if (sel.projectId == null || sel.selectedTaskIds.isEmpty) continue;

      // Validate tags and assignees for selected tasks
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

      final reportTasks = <DailyReportTask>[];
      for (final taskId in sel.selectedTaskIds) {
        final taskState = sel.taskStates[taskId];
        if (taskState == null) continue;

        if (_isQc) {
          // Validate QC note for miss/fail
          if (taskState.qcStatus != 'done' && taskState.qcNote.trim().isEmpty) {
            if (!mounted) return;
            showTopSnackBar(
              context,
              message: 'Vui lòng nhập lý do cho task "${taskState.task.name}"',
              backgroundColor: AppColors.warning,
            );
            return;
          }

          reportTasks.add(
            DailyReportTask(
              task: taskState.task,
              qcDone: taskState.qcStatus == 'done' ? 1 : 0,
              qcMiss: taskState.qcStatus == 'miss' ? 1 : 0,
              qcFail: taskState.qcStatus == 'fail' ? 1 : 0,
              qcNote: taskState.qcNote,
            ),
          );
        } else {
          reportTasks.add(
            DailyReportTask(
              task: taskState.task,
              status: taskState.status,
              progress: taskState.status == 'doing' ? taskState.progress : null,
            ),
          );
        }
      }

      if (reportTasks.isEmpty) continue;

      validProjects.add(
        DailyReportProject(
          projectId: sel.projectId!,
          projectName: sel.projectName ?? '',
          tasks: reportTasks,
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
          reportType: 'ot',
          reportRole: _role,
          projects: validProjects,
          note: _noteController.text,
        );
      } else {
        await notifier.submit(
          reportType: 'ot',
          reportRole: _role,
          projects: validProjects,
          note: _noteController.text,
        );
      }

      if (!mounted) return;
      showTopSnackBar(
        context,
        message: _isEditing
            ? 'Đã cập nhật báo cáo OT ngoài giờ!'
            : 'Đã gửi báo cáo OT ngoài giờ!',
        backgroundColor: AppColors.online,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      String errorMsg = e.toString();
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map<String, dynamic>) {
          final message = data['message']?.toString();
          if (message != null && message.isNotEmpty) {
            errorMsg = message;
          } else {
            final errorDetail = data['error']?.toString();
            if (errorDetail != null && errorDetail.isNotEmpty) {
              errorMsg = errorDetail;
            }
          }
        } else {
          errorMsg = e.message ?? errorMsg;
        }
      }
      showTopSnackBar(
        context,
        message: 'Gửi báo cáo thất bại: $errorMsg',
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
                  _isEditing
                      ? 'Sửa báo cáo OT ngoài giờ'
                      : 'Báo cáo OT ngoài giờ (Tối)',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _isQc
                        ? const Color(0xFF8B5CF6).withOpacity(0.15)
                        : palette.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _role.label,
                    style: TextStyle(
                      color: _isQc ? const Color(0xFF8B5CF6) : palette.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
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
                const SizedBox(height: 8),
                // Project sections
                for (int i = 0; i < _projectSelections.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  _OtProjectTaskSelector(
                    key: ValueKey('ot_proj_$i'),
                    index: i,
                    selection: _projectSelections[i],
                    isQc: _isQc,
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
                            _isEditing ? 'Cập nhật báo cáo' : 'Gửi báo cáo OT',
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

class _OtProjectSelection {
  int? projectId;
  String? projectName;
  final Set<int> selectedTaskIds;
  List<Task> loadedTasks;
  final Map<int, _OtTaskState> taskStates;

  _OtProjectSelection({
    this.projectId,
    this.projectName,
    Set<int>? selectedTaskIds,
  }) : selectedTaskIds = selectedTaskIds ?? {},
       loadedTasks = [],
       taskStates = {};
}

class _OtTaskState {
  final Task task;
  String status; // 'done' | 'doing'
  int progress; // 50
  String qcStatus; // 'done' | 'miss' | 'fail'
  String qcNote;

  _OtTaskState({
    required this.task,
    this.status = 'done',
    this.progress = 50,
    this.qcStatus = 'done',
    this.qcNote = '',
  });
}

class _OtProjectTaskSelector extends ConsumerStatefulWidget {
  const _OtProjectTaskSelector({
    super.key,
    required this.index,
    required this.selection,
    required this.isQc,
    required this.palette,
    required this.canRemove,
    required this.usedProjectIds,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _OtProjectSelection selection;
  final bool isQc;
  final AppThemePalette palette;
  final bool canRemove;
  final Set<int> usedProjectIds;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  ConsumerState<_OtProjectTaskSelector> createState() =>
      _OtProjectTaskSelectorState();
}

class _OtProjectTaskSelectorState
    extends ConsumerState<_OtProjectTaskSelector> {
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
                    sel.taskStates.clear();
                  });
                  widget.onChanged();
                },
              );
            },
          ),
          if (sel.projectId != null) ...[
            const SizedBox(height: 12),
            _OtTaskCheckboxList(
              projectId: sel.projectId!,
              selectedIds: sel.selectedTaskIds,
              loadedTasks: sel.loadedTasks,
              taskStates: sel.taskStates,
              isQc: widget.isQc,
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

class _OtTaskCheckboxList extends ConsumerStatefulWidget {
  const _OtTaskCheckboxList({
    required this.projectId,
    required this.selectedIds,
    required this.loadedTasks,
    required this.taskStates,
    required this.isQc,
    required this.palette,
    required this.onTasksLoaded,
    required this.onChanged,
  });

  final int projectId;
  final Set<int> selectedIds;
  final List<Task> loadedTasks;
  final Map<int, _OtTaskState> taskStates;
  final bool isQc;
  final AppThemePalette palette;
  final void Function(List<Task>) onTasksLoaded;
  final VoidCallback onChanged;

  @override
  ConsumerState<_OtTaskCheckboxList> createState() =>
      _OtTaskCheckboxListState();
}

class _OtTaskCheckboxListState extends ConsumerState<_OtTaskCheckboxList> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedStage;
  bool _showSelectedOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Task> _filterTasks(List<Task> tasks) {
    var filtered = tasks;
    if (_selectedStage != null) {
      filtered = filtered
          .where(
            (t) =>
                t.stage != null &&
                t.stage!.name.toUpperCase() == _selectedStage!.toUpperCase(),
          )
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where((t) => t.name.toLowerCase().contains(query))
          .toList();
    }
    return filtered;
  }

  List<String> _extractStages(List<Task> tasks) {
    final stages = <String>{};
    for (final task in tasks) {
      if (task.stage != null && task.stage!.name.isNotEmpty) {
        stages.add(task.stage!.name.toUpperCase());
      }
    }
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

  Color _stageColor(String stageName) {
    switch (stageName.toUpperCase()) {
      case 'BACKLOG':
        return Colors.blueGrey;
      case 'MUST':
        return Colors.orange;
      case 'CODING':
        return Colors.blue;
      case 'STAGING':
        return Colors.amber;
      case 'PRODUCTION':
        return Colors.purple;
      case 'COMPLETED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(projectTaskListProvider(widget.projectId));
    final tagsAsync = ref.watch(taskTagsProvider);
    final palette = widget.palette;

    return tasksAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Text(
        'Lỗi tải tasks: $e',
        style: const TextStyle(color: AppColors.danger),
      ),
      data: (tasks) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final taskIds = tasks.map((task) => task.id).toSet();
          final removedIds = widget.selectedIds.difference(taskIds);
          if (removedIds.isNotEmpty) {
            widget.selectedIds.removeAll(removedIds);
            for (final taskId in removedIds) {
              widget.taskStates.remove(taskId);
            }
            widget.onChanged();
          }
          widget.onTasksLoaded(tasks);
        });

        if (tasks.isEmpty) {
          return Text(
            'Chưa có task nào trong dự án',
            style: TextStyle(color: palette.textSecondary),
          );
        }

        final stages = _extractStages(tasks);
        final filteredTasks = _filterTasks(tasks);
        final selectedTasks = tasks
            .where((task) => widget.selectedIds.contains(task.id))
            .toList(growable: false);
        final allTags = tagsAsync.valueOrNull ?? [];
        final tagMap = {for (final tag in allTags) tag.id: tag.name};

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (selectedTasks.isNotEmpty)
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
                                : 'Xem ${selectedTasks.length} task đã chọn',
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
                  contentPadding: EdgeInsets.zero,
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
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            if (stages.length > 1) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 30,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _OtStageChip(
                      label: 'Tất cả',
                      isSelected: _selectedStage == null,
                      palette: palette,
                      onTap: () => setState(() => _selectedStage = null),
                    ),
                    for (final stage in stages) ...[
                      const SizedBox(width: 6),
                      _OtStageChip(
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
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Row(
                children: [
                  Text(
                    'Danh sách tasks (Đã chọn: ${selectedTasks.length} task):',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
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
            const SizedBox(height: 4),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount:
                  (_showSelectedOnly ? selectedTasks : filteredTasks).length,
              itemBuilder: (ctx, idx) {
                final task = (_showSelectedOnly
                    ? selectedTasks
                    : filteredTasks)[idx];
                final isSelected = widget.selectedIds.contains(task.id);
                final taskState = widget.taskStates[task.id];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
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
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (task.isSubtask) ...[
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
                            const SizedBox(height: 4),
                          ],
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (task.stage != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _stageColor(
                                      task.stage!.name,
                                    ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    task.stage!.name,
                                    style: TextStyle(
                                      color: _stageColor(task.stage!.name),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              if (task.assignees.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.person_outline,
                                      size: 12,
                                      color: palette.textSecondary,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      task.assignees
                                          .map((a) => a.name)
                                          .join(', '),
                                      style: TextStyle(
                                        color: palette.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          if (task.tagIds.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.label_outline,
                                  size: 12,
                                  color: palette.textSecondary,
                                ),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    task.tagIds
                                        .map((id) => tagMap[id] ?? 'Tag #$id')
                                        .join(', '),
                                    style: TextStyle(
                                      color: palette.textSecondary,
                                      fontSize: 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (task.assignees.isEmpty ||
                              task.tagIds.isEmpty) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.1),
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
                        ],
                      ),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            widget.selectedIds.add(task.id);
                            widget.taskStates[task.id] = _OtTaskState(
                              task: task,
                            );
                          } else {
                            widget.selectedIds.remove(task.id);
                            widget.taskStates.remove(task.id);
                          }
                        });
                        widget.onChanged();
                      },
                    ),
                    // If checked, display task status updater immediately below it
                    if (isSelected && taskState != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 38, bottom: 12),
                        child: widget.isQc
                            ? _OtQcTaskControls(
                                taskState: taskState,
                                palette: palette,
                                onChanged: widget.onChanged,
                              )
                            : _OtDevTaskControls(
                                taskState: taskState,
                                palette: palette,
                                onChanged: widget.onChanged,
                              ),
                      ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _OtStageChip extends StatelessWidget {
  const _OtStageChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? palette.primary.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? palette.primary : palette.surfaceVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? palette.primary : palette.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _OtDevTaskControls extends StatefulWidget {
  const _OtDevTaskControls({
    required this.taskState,
    required this.palette,
    required this.onChanged,
  });

  final _OtTaskState taskState;
  final AppThemePalette palette;
  final VoidCallback onChanged;

  @override
  State<_OtDevTaskControls> createState() => _OtDevTaskControlsState();
}

class _OtDevTaskControlsState extends State<_OtDevTaskControls> {
  @override
  Widget build(BuildContext context) {
    final taskState = widget.taskState;
    final isDone = taskState.status == 'done';
    final palette = widget.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _OtStatusChip(
              label: 'Done',
              isSelected: isDone,
              selectedColor: AppColors.online,
              palette: palette,
              onTap: () {
                setState(() => taskState.status = 'done');
                widget.onChanged();
              },
            ),
            const SizedBox(width: 8),
            _OtStatusChip(
              label: 'Doing',
              isSelected: !isDone,
              selectedColor: AppColors.warning,
              palette: palette,
              onTap: () {
                setState(() => taskState.status = 'doing');
                widget.onChanged();
              },
            ),
            if (!isDone) ...[
              const SizedBox(width: 12),
              Text(
                '${taskState.progress}%',
                style: const TextStyle(
                  color: AppColors.warning,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        if (!isDone)
          Slider(
            value: taskState.progress.toDouble(),
            min: 10,
            max: 90,
            divisions: 8,
            activeColor: AppColors.warning,
            inactiveColor: palette.surfaceVariant,
            label: '${taskState.progress}%',
            onChanged: (v) {
              setState(() => taskState.progress = v.round());
              widget.onChanged();
            },
          ),
      ],
    );
  }
}

class _OtQcTaskControls extends StatefulWidget {
  const _OtQcTaskControls({
    required this.taskState,
    required this.palette,
    required this.onChanged,
  });

  final _OtTaskState taskState;
  final AppThemePalette palette;
  final VoidCallback onChanged;

  @override
  State<_OtQcTaskControls> createState() => _OtQcTaskControlsState();
}

class _OtQcTaskControlsState extends State<_OtQcTaskControls> {
  @override
  Widget build(BuildContext context) {
    final taskState = widget.taskState;
    final palette = widget.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _OtStatusChip(
              label: 'Done',
              isSelected: taskState.qcStatus == 'done',
              selectedColor: AppColors.online,
              palette: palette,
              onTap: () {
                setState(() {
                  taskState.qcStatus = 'done';
                  taskState.qcNote = '';
                });
                widget.onChanged();
              },
            ),
            const SizedBox(width: 8),
            _OtStatusChip(
              label: 'Miss',
              isSelected: taskState.qcStatus == 'miss',
              selectedColor: AppColors.warning,
              palette: palette,
              onTap: () {
                setState(() => taskState.qcStatus = 'miss');
                widget.onChanged();
              },
            ),
            const SizedBox(width: 8),
            _OtStatusChip(
              label: 'Fail',
              isSelected: taskState.qcStatus == 'fail',
              selectedColor: AppColors.danger,
              palette: palette,
              onTap: () {
                setState(() => taskState.qcStatus = 'fail');
                widget.onChanged();
              },
            ),
          ],
        ),
        if (taskState.qcStatus != 'done') ...[
          const SizedBox(height: 8),
          TextFormField(
            initialValue: taskState.qcNote,
            onChanged: (val) {
              taskState.qcNote = val;
              widget.onChanged();
            },
            maxLines: 2,
            style: TextStyle(color: palette.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Lý do miss/fail...',
              hintStyle: TextStyle(
                color: palette.textSecondary.withOpacity(0.6),
                fontSize: 12,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: palette.surfaceVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: palette.surfaceVariant),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _OtStatusChip extends StatelessWidget {
  const _OtStatusChip({
    required this.label,
    required this.isSelected,
    required this.selectedColor,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color selectedColor;
  final AppThemePalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? selectedColor : palette.surfaceVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? selectedColor : palette.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
