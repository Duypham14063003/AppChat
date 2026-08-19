import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../data/daily_report_models.dart';
import '../providers/daily_report_providers.dart';

/// Shows the evening report bottom sheet.
/// [morningReport] is the morning report to base the evening report on.
/// If [existingReport] is provided, the sheet is in edit mode.
Future<bool?> showEveningReportSheet(
  BuildContext context, {
  required DailyReport morningReport,
  DailyReport? existingReport,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EveningReportSheet(
      morningReport: morningReport,
      existingReport: existingReport,
    ),
  );
}

class _EveningReportSheet extends ConsumerStatefulWidget {
  const _EveningReportSheet({
    required this.morningReport,
    this.existingReport,
  });

  final DailyReport morningReport;
  final DailyReport? existingReport;

  @override
  ConsumerState<_EveningReportSheet> createState() =>
      _EveningReportSheetState();
}

class _EveningReportSheetState extends ConsumerState<_EveningReportSheet> {
  final _noteController = TextEditingController();
  late List<_EveningProjectState> _projects;
  late ReportRole _role;
  bool _isSending = false;

  bool get _isEditing => widget.existingReport != null;
  bool get _isQc => _role == ReportRole.qc;

  @override
  void initState() {
    super.initState();
    _role = widget.morningReport.reportRole;
    _initializeFromMorning();
  }

  void _initializeFromMorning() {
    final evening = widget.existingReport;
    _noteController.text = evening?.note ?? '';

    _projects = widget.morningReport.projects.map((morningProject) {
      DailyReportProject? eveningProject;
      if (evening != null) {
        try {
          eveningProject = evening.projects
              .firstWhere((p) => p.projectId == morningProject.projectId);
        } catch (_) {}
      }

      return _EveningProjectState(
        projectId: morningProject.projectId,
        projectName: morningProject.projectName,
        tasks: morningProject.tasks.map((morningTask) {
          DailyReportTask? eveningTask;
          if (eveningProject != null) {
            try {
              eveningTask = eveningProject.tasks
                  .firstWhere((t) => t.task.id == morningTask.task.id);
            } catch (_) {}
          }

          return _EveningTaskState(
            task: morningTask,
            // Dev fields
            status: eveningTask?.status ?? 'done',
            progress: eveningTask?.progress ?? 50,
            // QC fields
            qcStatus: (eveningTask?.qcFail ?? 0) > 0 
                ? 'fail' 
                : (eveningTask?.qcMiss ?? 0) > 0 
                    ? 'miss' 
                    : 'done',
            qcNote: eveningTask?.qcNote ?? '',
          );
        }).toList(),
      );
    }).toList();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final projects = _projects.map((proj) {
      return DailyReportProject(
        projectId: proj.projectId,
        projectName: proj.projectName,
        tasks: proj.tasks.map((ts) {
          if (_isQc) {
            return ts.task.copyWith(
              qcDone: ts.qcStatus == 'done' ? 1 : 0,
              qcMiss: ts.qcStatus == 'miss' ? 1 : 0,
              qcFail: ts.qcStatus == 'fail' ? 1 : 0,
              qcNote: ts.qcNote,
            );
          }
          return ts.task.copyWith(
            status: ts.status,
            progress: ts.status == 'doing' ? ts.progress : null,
          );
        }).toList(),
      );
    }).toList();

    if (_isQc) {
      for (final proj in _projects) {
        for (final ts in proj.tasks) {
          if (ts.qcStatus != 'done' && ts.qcNote.trim().isEmpty) {
            if (!mounted) return;
            showTopSnackBar(
              context,
              message: 'Vui lòng nhập lý do cho task "${ts.task.task.name}"',
              backgroundColor: AppColors.warning,
            );
            return;
          }
        }
      }
    }

    setState(() => _isSending = true);
    try {
      final notifier = ref.read(todayReportsProvider.notifier);
      if (_isEditing) {
        await notifier.updateReport(
          reportId: widget.existingReport!.id,
          reportType: 'evening',
          reportRole: _role,
          projects: projects,
          note: _noteController.text,
        );
      } else {
        await notifier.submit(
          reportType: 'evening',
          reportRole: _role,
          projects: projects,
          note: _noteController.text,
        );
      }
      if (!mounted) return;
      showTopSnackBar(
        context,
        message: _isEditing
            ? 'Đã cập nhật báo cáo cuối ngày!'
            : 'Đã gửi báo cáo cuối ngày!',
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
                  _isEditing
                      ? 'Sửa báo cáo cuối ngày'
                      : 'Báo cáo kết thúc ngày',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                // Role badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isQc
                        ? const Color(0xFF8B5CF6).withOpacity(0.15)
                        : palette.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _role.label,
                    style: TextStyle(
                      color: _isQc
                          ? const Color(0xFF8B5CF6)
                          : palette.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Flexible(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
              shrinkWrap: true,
              children: [
                for (int i = 0; i < _projects.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  _EveningProjectSection(
                    project: _projects[i],
                    isQc: _isQc,
                    palette: palette,
                    onChanged: () => setState(() {}),
                  ),
                ],
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
                // Submit
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

// ─── State classes ─────────────────────────────────────────────────────────

class _EveningProjectState {
  final int projectId;
  final String projectName;
  final List<_EveningTaskState> tasks;

  _EveningProjectState({
    required this.projectId,
    required this.projectName,
    required this.tasks,
  });
}

class _EveningTaskState {
  final DailyReportTask task;
  // Dev fields
  String status;
  int progress;
  // QC fields
  String qcStatus;
  String qcNote;

  _EveningTaskState({
    required this.task,
    this.status = 'done',
    this.progress = 50,
    this.qcStatus = 'done',
    this.qcNote = '',
  });
}

// ─── Project section ───────────────────────────────────────────────────────

class _EveningProjectSection extends StatelessWidget {
  const _EveningProjectSection({
    required this.project,
    required this.isQc,
    required this.palette,
    required this.onChanged,
  });

  final _EveningProjectState project;
  final bool isQc;
  final AppThemePalette palette;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
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
              Expanded(
                child: Text(
                  project.projectName,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < project.tasks.length; i++) ...[
            if (i > 0) Divider(color: palette.surfaceVariant, height: 16),
            if (isQc)
              _QcTaskTile(
                taskState: project.tasks[i],
                palette: palette,
                onChanged: onChanged,
              )
            else
              _DevTaskTile(
                taskState: project.tasks[i],
                palette: palette,
                onChanged: onChanged,
              ),
          ],
        ],
      ),
    );
  }
}

// ─── Dev task tile (Done/Doing + %) ────────────────────────────────────────

class _DevTaskTile extends StatelessWidget {
  const _DevTaskTile({
    required this.taskState,
    required this.palette,
    required this.onChanged,
  });

  final _EveningTaskState taskState;
  final AppThemePalette palette;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final task = taskState.task.task;
    final isDone = taskState.status == 'done';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TaskNameRow(task: task, emoji: isDone ? '✅' : '🔄', palette: palette),
        const SizedBox(height: 8),
        Row(
          children: [
            _StatusChip(
              label: 'Done',
              isSelected: isDone,
              selectedColor: AppColors.online,
              palette: palette,
              onTap: () {
                taskState.status = 'done';
                onChanged();
              },
            ),
            const SizedBox(width: 10),
            _StatusChip(
              label: 'Doing',
              isSelected: !isDone,
              selectedColor: AppColors.warning,
              palette: palette,
              onTap: () {
                taskState.status = 'doing';
                onChanged();
              },
            ),
            if (!isDone) ...[
              const SizedBox(width: 12),
              Text(
                '${taskState.progress}%',
                style: const TextStyle(
                  color: AppColors.warning,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
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
              taskState.progress = v.round();
              onChanged();
            },
          ),
      ],
    );
  }
}

// ─── QC task tile (qc_done, qc_miss, qc_fail) ─────────────────────────────

class _QcTaskTile extends StatelessWidget {
  const _QcTaskTile({
    required this.taskState,
    required this.palette,
    required this.onChanged,
  });

  final _EveningTaskState taskState;
  final AppThemePalette palette;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final task = taskState.task.task;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TaskNameRow(task: task, emoji: '🔍', palette: palette),
        const SizedBox(height: 10),
        Row(
          children: [
            _StatusChip(
              label: 'Done',
              isSelected: taskState.qcStatus == 'done',
              selectedColor: AppColors.online,
              palette: palette,
              onTap: () {
                taskState.qcStatus = 'done';
                taskState.qcNote = '';
                onChanged();
              },
            ),
            const SizedBox(width: 10),
            _StatusChip(
              label: 'Miss',
              isSelected: taskState.qcStatus == 'miss',
              selectedColor: AppColors.warning,
              palette: palette,
              onTap: () {
                taskState.qcStatus = 'miss';
                onChanged();
              },
            ),
            const SizedBox(width: 10),
            _StatusChip(
              label: 'Fail',
              isSelected: taskState.qcStatus == 'fail',
              selectedColor: AppColors.danger,
              palette: palette,
              onTap: () {
                taskState.qcStatus = 'fail';
                onChanged();
              },
            ),
          ],
        ),
        if (taskState.qcStatus != 'done') ...[
          const SizedBox(height: 10),
          TextFormField(
            initialValue: taskState.qcNote,
            onChanged: (val) {
              taskState.qcNote = val;
            },
            maxLines: 2,
            style: TextStyle(color: palette.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Lý do miss/fail...',
              hintStyle: TextStyle(
                color: palette.textSecondary.withOpacity(0.6),
                fontSize: 13,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
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
                borderSide: BorderSide(color: AppColors.warning, width: 1.5),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Shared widgets ────────────────────────────────────────────────────────

class _TaskNameRow extends StatelessWidget {
  const _TaskNameRow({
    required this.task,
    required this.emoji,
    required this.palette,
  });

  final dynamic task; // Task model
  final String emoji;
  final AppThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.name as String,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (task.stage != null)
                Text(
                  task.stage!.name as String,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? selectedColor : palette.surfaceVariant,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? selectedColor : palette.textSecondary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
