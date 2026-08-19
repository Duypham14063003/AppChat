import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../data/hr_models.dart';
import '../providers/hr_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_color_presets.dart';

String attendanceHistoryLeaveDetailRoute(String leaveId) =>
    '/hr/leaves/$leaveId';

class AttendanceHistoryScreen extends ConsumerStatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  ConsumerState<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState
    extends ConsumerState<AttendanceHistoryScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  String get _monthKey =>
      '${_focusedDay.year}-${_focusedDay.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final calendarAsync = ref.watch(attendanceCalendarProvider(_monthKey));
    final isWide = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử chấm công')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: isWide
              ? Row(
                  children: [
                    // Calendar on left
                    SizedBox(width: 380, child: _buildCalendar(calendarAsync)),
                    VerticalDivider(width: 1, color: palette.surfaceVariant),
                    // List on right
                    Expanded(child: _buildList(calendarAsync, isWide)),
                  ],
                )
              : Column(
                  children: [
                    _buildCalendar(calendarAsync),
                    Divider(color: palette.surfaceVariant),
                    Expanded(child: _buildList(calendarAsync, isWide)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCalendar(AsyncValue<AttendanceCalendarData> calendarAsync) {
    final palette = context.appPalette;
    return calendarAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (data) {
        final attendanceDays = _buildAttendanceDays(data.attendanceRecords);
        final leaveDays = _buildLeaveDays(data.leaveRecords);

        return TableCalendar(
          firstDay: DateTime(2025, 1, 1),
          lastDay: DateTime(2027, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selected, focused) => setState(() {
            _selectedDay = selected;
            _focusedDay = focused;
          }),
          onPageChanged: (focused) => setState(() => _focusedDay = focused),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: palette.primary.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: palette.primary,
              shape: BoxShape.circle,
            ),
            defaultTextStyle: TextStyle(color: palette.textPrimary),
            weekendTextStyle: TextStyle(color: palette.textSecondary),
            outsideTextStyle: TextStyle(color: palette.textHint),
            markersMaxCount: 2,
            markerDecoration: const BoxDecoration(color: Colors.transparent),
          ),
          headerStyle: HeaderStyle(
            titleCentered: true,
            formatButtonVisible: false,
            titleTextStyle: TextStyle(color: palette.textPrimary, fontSize: 16),
            leftChevronIcon: Icon(Icons.chevron_left, color: palette.primary),
            rightChevronIcon: Icon(Icons.chevron_right, color: palette.primary),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(color: palette.textSecondary, fontSize: 12),
            weekendStyle: TextStyle(color: palette.textHint, fontSize: 12),
          ),
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) {
              final dayKey = _normalizeDate(day);
              final hasAttendance = attendanceDays.contains(dayKey);
              final hasLeave = leaveDays.contains(dayKey);
              if (!hasAttendance && !hasLeave) return const SizedBox.shrink();

              return Positioned(
                right: 6,
                bottom: 6,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasAttendance) _buildMarker(AppColors.online),
                    if (hasAttendance && hasLeave) const SizedBox(width: 3),
                    if (hasLeave) _buildMarker(AppColors.danger),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildList(
    AsyncValue<AttendanceCalendarData> calendarAsync,
    bool isWide,
  ) {
    final palette = context.appPalette;
    return calendarAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (data) {
        final entries = _buildDayEntries(data);

        if (entries.isEmpty) {
          return Center(
            child: Text(
              'Không có dữ liệu',
              style: TextStyle(color: palette.textSecondary),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: entries.length,
          separatorBuilder: (_, index) =>
              Divider(height: 1, color: palette.surfaceVariant),
          itemBuilder: (_, i) {
            return _buildEntryTile(entries[i], isWide);
          },
        );
      },
    );
  }

  String _fmt(DateTime? dt) => dt == null
      ? '--:--'
      : '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  double _parseNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  Set<DateTime> _buildAttendanceDays(List<dynamic> records) {
    return records
        .map(
          (record) => DateTime.tryParse(
            record['checkin_at']?.toString() ?? '',
          )?.toLocal(),
        )
        .whereType<DateTime>()
        .map(_normalizeDate)
        .toSet();
  }

  Set<DateTime> _buildLeaveDays(List<LeaveRequest> leaves) {
    final days = <DateTime>{};
    for (final leave in leaves) {
      final start = DateTime.tryParse(leave.startDate);
      final end = DateTime.tryParse(leave.endDate);
      if (start == null) continue;

      final lastDay = end ?? start;
      var cursor = DateTime(start.year, start.month, start.day);
      final normalizedEnd = DateTime(lastDay.year, lastDay.month, lastDay.day);

      while (!cursor.isAfter(normalizedEnd)) {
        days.add(cursor);
        cursor = cursor.add(const Duration(days: 1));
      }
    }
    return days;
  }

  DateTime _normalizeDate(DateTime day) =>
      DateTime(day.year, day.month, day.day);

  List<_DayEntry> _buildDayEntries(AttendanceCalendarData data) {
    final selectedDay = _selectedDay;
    final entries = <_DayEntry>[];

    for (final record in data.attendanceRecords) {
      final checkin = DateTime.tryParse(
        record['checkin_at']?.toString() ?? '',
      )?.toLocal();
      if (selectedDay != null &&
          (checkin == null || !isSameDay(checkin, selectedDay))) {
        continue;
      }

      entries.add(
        _DayEntry.attendance(
          date: checkin,
          data: record as Map<String, dynamic>,
        ),
      );
    }

    for (final leave in data.leaveRecords) {
      final selectedDate = selectedDay;
      if (selectedDate != null && !_leaveCoversDay(leave, selectedDate)) {
        continue;
      }

      entries.add(_DayEntry.leave(date: selectedDate, data: leave));
    }

    entries.sort((a, b) {
      final aDate = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return entries;
  }

  bool _leaveCoversDay(LeaveRequest leave, DateTime day) {
    final start = DateTime.tryParse(leave.startDate);
    final end = DateTime.tryParse(leave.endDate) ?? start;
    if (start == null || end == null) return false;

    final normalizedDay = _normalizeDate(day);
    final normalizedStart = _normalizeDate(start);
    final normalizedEnd = _normalizeDate(end);
    return !normalizedDay.isBefore(normalizedStart) &&
        !normalizedDay.isAfter(normalizedEnd);
  }

  Widget _buildEntryTile(_DayEntry entry, bool isWide) {
    final palette = context.appPalette;
    if (entry.type == _DayEntryType.leave) {
      final leave = entry.data as LeaveRequest;
      final typeLabels = {
        'annual': 'Phép năm',
        'sick': 'Nghỉ ốm',
        'personal': 'Việc riêng',
        'ot': 'OT',
      };
      final statusLabels = {
        'draft': 'Nháp',
        'submitted': 'Chờ duyệt',
        'approved': 'Đã duyệt',
        'rejected': 'Từ chối',
        'cancelled': 'Đã hủy',
      };
      final statusColors = {
        'draft': palette.textHint,
        'submitted': AppColors.warning,
        'approved': AppColors.online,
        'rejected': AppColors.danger,
        'cancelled': AppColors.danger,
      };

      final startDate = DateTime.tryParse(leave.startDate);
      final endDate = DateTime.tryParse(leave.endDate);

      return ListTile(
        key: ValueKey('attendance-history-leave-${leave.id}'),
        dense: !isWide,
        onTap: () => context.push(
          attendanceHistoryLeaveDetailRoute(leave.id),
          extra: leave,
        ),
        leading: const Icon(
          Icons.event_busy,
          color: AppColors.danger,
          size: 20,
        ),
        title: Text(
          typeLabels[leave.type] ?? 'Nghỉ phép',
          style: TextStyle(color: palette.textPrimary),
        ),
        subtitle: Text(
          '${_fmtDate(startDate)} → ${_fmtDate(endDate ?? startDate)}',
          style: TextStyle(color: palette.textSecondary, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (statusColors[leave.status] ?? AppColors.danger)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusLabels[leave.status] ?? 'Nghỉ phép',
                style: TextStyle(
                  color: statusColors[leave.status] ?? AppColors.danger,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: palette.textHint, size: 18),
          ],
        ),
      );
    }

    final r = entry.data as Map<String, dynamic>;
    final checkin = DateTime.tryParse(
      r['checkin_at']?.toString() ?? '',
    )?.toLocal();
    final checkout = r['checkout_at'] != null
        ? DateTime.tryParse(r['checkout_at'].toString())?.toLocal()
        : null;
    return ListTile(
      key: ValueKey(
        'attendance-history-attendance-${checkin?.millisecondsSinceEpoch ?? 'unknown'}',
      ),
      dense: !isWide,
      leading: Icon(
        checkout != null ? Icons.check_circle : Icons.radio_button_checked,
        color: checkout != null ? AppColors.online : AppColors.warning,
        size: 20,
      ),
      title: Text(
        checkin != null ? _fmtDate(checkin) : '-',
        style: TextStyle(color: palette.textPrimary),
      ),
      subtitle: Text(
        'In: ${_fmt(checkin)} | Out: ${_fmt(checkout)} | ${r['total_hours'] ?? '-'}h',
        style: TextStyle(color: palette.textSecondary, fontSize: 12),
      ),
      trailing: _parseNum(r['ot_hours']) > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'OT ${r['ot_hours']}h',
                style: const TextStyle(color: AppColors.warning, fontSize: 12),
              ),
            )
          : null,
    );
  }

  String _fmtDate(DateTime? dt) =>
      dt == null ? '-' : '${dt.day}/${dt.month}/${dt.year}';

  Widget _buildMarker(Color color) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

enum _DayEntryType { attendance, leave }

class _DayEntry {
  final _DayEntryType type;
  final DateTime? date;
  final Object data;

  const _DayEntry._({
    required this.type,
    required this.date,
    required this.data,
  });

  factory _DayEntry.attendance({
    required DateTime? date,
    required Map<String, dynamic> data,
  }) {
    return _DayEntry._(type: _DayEntryType.attendance, date: date, data: data);
  }

  factory _DayEntry.leave({
    required DateTime? date,
    required LeaveRequest data,
  }) {
    return _DayEntry._(type: _DayEntryType.leave, date: date, data: data);
  }
}
