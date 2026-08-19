import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_notifier.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../../../shared/widgets/heart_header_badge.dart';
import '../data/hr_models.dart';
import '../hr_role_utils.dart';
import '../providers/hr_providers.dart';

final weeklyScheduleLeavesProvider = FutureProvider<List<LeaveRequest>>((
  ref,
) async {
  final repo = ref.read(hrRepositoryProvider);
  final response = await repo.getLeaves();
  return response.leaves;
});

class WeeklyScheduleScreen extends ConsumerStatefulWidget {
  const WeeklyScheduleScreen({super.key});

  @override
  ConsumerState<WeeklyScheduleScreen> createState() =>
      _WeeklyScheduleScreenState();
}

class _WeeklyScheduleScreenState extends ConsumerState<WeeklyScheduleScreen> {
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now().month;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final authState = ref.watch(authNotifierProvider);
    final roles = authState.valueOrNull?.user?.roles ?? const <String>[];
    final canApproveLeaves = canApproveLeavesForRoles(roles);
    final config = authState.valueOrNull?.payrollStartConfig;
    final now = resolveCurrentPayrollMonth(config ?? 1);
    final leavesAsync = ref.watch(weeklyScheduleLeavesProvider);

    if (!canApproveLeaves) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lịch OFF/WFH')),
        body: const Center(
          child: Text('Bạn không có quyền xem lịch OFF/WFH tổng hợp'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch OFF/WFH'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: HeartHeaderBadge(compact: true)),
          ),
        ],
      ),
      body: leavesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Lỗi: $error')),
        data: (leaves) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(weeklyScheduleLeavesProvider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: palette.surfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 150,
                          child: DropdownButtonFormField<int>(
                            initialValue: _selectedMonth,
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
                                borderSide: BorderSide(
                                  color: palette.surfaceVariant,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: palette.primary),
                              ),
                            ),
                            iconEnabledColor: palette.primary,
                            style: TextStyle(color: palette.textPrimary),
                            items: List.generate(
                              now.month,
                              (index) => DropdownMenuItem<int>(
                                value: index + 1,
                                child: Text('Tháng ${index + 1}'),
                              ),
                            ),
                            onChanged: (month) {
                              if (month == null) return;
                              setState(() => _selectedMonth = month);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _WeeklyLeaveBoard(
                      leaves: leaves,
                      selectedMonth: _selectedMonth,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklyLeaveBoard extends StatefulWidget {
  const _WeeklyLeaveBoard({required this.leaves, required this.selectedMonth});

  final List<LeaveRequest> leaves;
  final int selectedMonth;

  @override
  State<_WeeklyLeaveBoard> createState() => _WeeklyLeaveBoardState();
}

class _WeeklyLeaveBoardState extends State<_WeeklyLeaveBoard> {
  late List<DateTime> _weeks;
  late DateTime _selectedWeekStart;

  @override
  void initState() {
    super.initState();
    _syncWeeks(resetSelection: true);
  }

  @override
  void didUpdateWidget(covariant _WeeklyLeaveBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMonth != widget.selectedMonth) {
      _syncWeeks(resetSelection: true);
      return;
    }
    _syncWeeks(resetSelection: false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final weekDays = List.generate(
      7,
      (index) => _selectedWeekStart.add(Duration(days: index)),
      growable: false,
    );
    final entriesByUser = _buildEntriesByUser();
    final employeeNames = entriesByUser.keys.toList()..sort();
    final currentIndex = _weeks.indexOf(_selectedWeekStart);
    final canGoPrevious = currentIndex > 0;
    final canGoNext = currentIndex >= 0 && currentIndex < _weeks.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tuần ${_formatWeekRange(_selectedWeekStart)}',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _legendChip(context, 'OFF', AppColors.online),
                      _legendChip(context, 'WFH', palette.primary),
                      _legendChip(context, 'Chờ duyệt', AppColors.warning),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Tuần trước',
              onPressed: canGoPrevious ? _selectPreviousWeek : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              tooltip: 'Tuần sau',
              onPressed: canGoNext ? _selectNextWeek : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (employeeNames.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'Không có đơn OFF/WFH chờ duyệt hoặc đã duyệt trong tuần này.',
              style: TextStyle(color: palette.textSecondary, fontSize: 13),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              columnWidths: _buildColumnWidths(),
              defaultVerticalAlignment: TableCellVerticalAlignment.top,
              border: TableBorder.symmetric(
                inside: BorderSide(
                  color: palette.surfaceVariant.withValues(alpha: 0.45),
                ),
              ),
              children: [
                TableRow(
                  children: [
                    _buildHeaderCell(context, 'Nhân viên', isNameColumn: true),
                    for (final day in weekDays)
                      _buildHeaderCell(
                        context,
                        _formatDayHeader(day),
                        isToday: _isSameDate(day, DateTime.now()),
                      ),
                  ],
                ),
                for (final employeeName in employeeNames)
                  TableRow(
                    children: [
                      _buildNameCell(context, employeeName),
                      for (final day in weekDays)
                        _buildDayCell(
                          context,
                          entriesByUser[employeeName]![_dateKey(day)] ??
                              const <_WeeklyLeaveEntry>[],
                        ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }

  void _syncWeeks({required bool resetSelection}) {
    _weeks = _buildWeeksForMonth(widget.selectedMonth);
    final preferredWeek = _resolvePreferredWeek(widget.selectedMonth);
    if (resetSelection || !_weeks.contains(_selectedWeekStart)) {
      _selectedWeekStart = _weeks.contains(preferredWeek)
          ? preferredWeek
          : _weeks.first;
    }
  }

  Map<int, TableColumnWidth> _buildColumnWidths() {
    return <int, TableColumnWidth>{
      0: const FixedColumnWidth(220),
      for (var i = 1; i <= 7; i++) i: const FixedColumnWidth(120),
    };
  }

  List<DateTime> _buildWeeksForMonth(int month) {
    final monthStart = DateTime(DateTime.now().year, month, 1);
    final monthEnd = DateTime(DateTime.now().year, month + 1, 0);
    final firstWeekStart = _startOfWeek(monthStart);
    final weeks = <DateTime>[];
    var cursor = firstWeekStart;
    while (!cursor.isAfter(monthEnd)) {
      weeks.add(cursor);
      cursor = cursor.add(const Duration(days: 7));
    }
    return weeks;
  }

  DateTime _resolvePreferredWeek(int month) {
    final now = DateTime.now();
    final anchor = now.month == month ? now : DateTime(now.year, month, 1);
    return _startOfWeek(anchor);
  }

  DateTime _startOfWeek(DateTime value) {
    final date = DateUtils.dateOnly(value);
    return date.subtract(Duration(days: date.weekday - 1));
  }

  void _selectPreviousWeek() {
    final index = _weeks.indexOf(_selectedWeekStart);
    if (index <= 0) return;
    setState(() => _selectedWeekStart = _weeks[index - 1]);
  }

  void _selectNextWeek() {
    final index = _weeks.indexOf(_selectedWeekStart);
    if (index < 0 || index >= _weeks.length - 1) return;
    setState(() => _selectedWeekStart = _weeks[index + 1]);
  }

  Map<String, Map<String, List<_WeeklyLeaveEntry>>> _buildEntriesByUser() {
    final weekEnd = _selectedWeekStart.add(const Duration(days: 6));
    final result = <String, Map<String, List<_WeeklyLeaveEntry>>>{};

    for (final leave in widget.leaves) {
      if (!_isWeeklyBoardLeave(leave)) continue;

      final start = DateTime.tryParse(leave.startDate);
      final end = DateTime.tryParse(leave.endDate) ?? start;
      if (start == null || end == null) continue;
      if (start.isAfter(weekEnd) || end.isBefore(_selectedWeekStart)) continue;

      final employeeName = (leave.userName?.trim().isNotEmpty ?? false)
          ? leave.userName!.trim()
          : 'Chưa rõ';

      final dayMap = result.putIfAbsent(
        employeeName,
        () => <String, List<_WeeklyLeaveEntry>>{},
      );

      final effectiveStart = start.isBefore(_selectedWeekStart)
          ? _selectedWeekStart
          : start;
      final effectiveEnd = end.isAfter(weekEnd) ? weekEnd : end;

      var cursor = DateUtils.dateOnly(effectiveStart);
      final lastDay = DateUtils.dateOnly(effectiveEnd);
      while (!cursor.isAfter(lastDay)) {
        final key = _dateKey(cursor);
        final entries = dayMap.putIfAbsent(key, () => <_WeeklyLeaveEntry>[]);
        entries.add(_WeeklyLeaveEntry(leave: leave));
        cursor = cursor.add(const Duration(days: 1));
      }
    }

    for (final dayMap in result.values) {
      for (final entries in dayMap.values) {
        entries.sort((a, b) {
          final typeCompare = a.sortOrder.compareTo(b.sortOrder);
          if (typeCompare != 0) return typeCompare;
          return a.label.compareTo(b.label);
        });
      }
    }

    return result;
  }

  bool _isWeeklyBoardLeave(LeaveRequest leave) {
    if (leave.status != 'submitted' && leave.status != 'approved') {
      return false;
    }
    if (leave.type == 'ot') return false;
    return leave.type == 'wfh' ||
        leave.type == 'annual' ||
        leave.type == 'sick' ||
        leave.type == 'personal';
  }

  Widget _legendChip(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildHeaderCell(
    BuildContext context,
    String text, {
    bool isNameColumn = false,
    bool isToday = false,
  }) {
    final palette = context.appPalette;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isToday
            ? palette.primary.withValues(alpha: 0.1)
            : palette.surfaceVariant.withValues(
                alpha: isNameColumn ? 0.45 : 0.25,
              ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isToday ? palette.primary : palette.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildNameCell(BuildContext context, String employeeName) {
    final palette = context.appPalette;
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: palette.surfaceVariant.withValues(alpha: 0.16),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          employeeName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDayCell(BuildContext context, List<_WeeklyLeaveEntry> entries) {
    final palette = context.appPalette;
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: entries.isEmpty
          ? Center(
              child: Text(
                '-',
                style: TextStyle(color: palette.textHint, fontSize: 12),
              ),
            )
          : Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final entry in entries)
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => context.push(
                        '/hr/leaves/${entry.leave.id}',
                        extra: entry.leave,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: entry.color(context).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: entry.color(context).withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          entry.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: entry.color(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  String _formatWeekRange(DateTime weekStart) {
    final end = weekStart.add(const Duration(days: 6));
    return '${_formatDate(weekStart)} - ${_formatDate(end)}';
  }

  String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
  }

  String _formatDayHeader(DateTime value) {
    const labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return '${labels[value.weekday - 1]} ${_formatDate(value)}';
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _dateKey(DateTime value) {
    final date = DateUtils.dateOnly(value);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _WeeklyLeaveEntry {
  const _WeeklyLeaveEntry({required this.leave});

  final LeaveRequest leave;

  int get sortOrder => leave.type == 'wfh' ? 1 : 0;

  String get label {
    final base = leave.type == 'wfh' ? 'WFH' : 'OFF';
    if (leave.status == 'submitted') {
      return '$base?';
    }
    if (!leave.isHalfDay) {
      return base;
    }
    switch (leave.halfDayPart) {
      case 'morning':
        return '$base S';
      case 'afternoon':
        return '$base C';
      default:
        return '$base 1/2';
    }
  }

  Color color(BuildContext context) {
    if (leave.status == 'submitted') {
      return AppColors.warning;
    }
    if (leave.type == 'wfh') {
      return context.appPalette.primary;
    }
    return AppColors.online;
  }
}
