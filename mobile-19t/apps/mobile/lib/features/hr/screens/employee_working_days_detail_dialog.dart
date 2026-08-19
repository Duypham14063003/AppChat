import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../data/hr_models.dart';

Future<void> showEmployeeWorkingDaysDetail({
  required BuildContext context,
  required EmployeePayrollSummary summary,
  required String employeeName,
}) {
  final size = MediaQuery.sizeOf(context);
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      key: const ValueKey('employee-working-days-detail-dialog'),
      insetPadding: EdgeInsets.all(size.width < 700 ? 8 : 24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: math.min(size.width - 32, 1000),
        height: math.min(size.height - 48, 780),
        child: EmployeeWorkingDaysDetailView(
          summary: summary,
          employeeName: employeeName,
        ),
      ),
    ),
  );
}

class EmployeeWorkingDaysDetailView extends StatefulWidget {
  const EmployeeWorkingDaysDetailView({
    super.key,
    required this.summary,
    required this.employeeName,
    this.embedded = false,
  });

  final EmployeePayrollSummary summary;
  final String employeeName;
  final bool embedded;

  @override
  State<EmployeeWorkingDaysDetailView> createState() =>
      _EmployeeWorkingDaysDetailViewState();
}

class _EmployeeWorkingDaysDetailViewState
    extends State<EmployeeWorkingDaysDetailView> {
  late DateTime _cycleFrom;
  late DateTime _cycleLastDay;
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _initializeCycle();
  }

  @override
  void didUpdateWidget(covariant EmployeeWorkingDaysDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.summary.month != widget.summary.month ||
        oldWidget.summary.userId != widget.summary.userId ||
        oldWidget.summary.cycleFrom != widget.summary.cycleFrom ||
        oldWidget.summary.cycleToExclusive != widget.summary.cycleToExclusive) {
      _initializeCycle();
    }
  }

  void _initializeCycle() {
    _cycleFrom = _parseDate(widget.summary.cycleFrom) ?? DateTime.now();
    final exclusive =
        _parseDate(widget.summary.cycleToExclusive) ??
        _cycleFrom.add(const Duration(days: 1));
    _cycleLastDay = exclusive.subtract(const Duration(days: 1));

    final requestedMonth = _parseDate('${widget.summary.month}-01');
    final countedInRequestedMonth =
        widget.summary.attendanceSessions
            .where((session) => session.counted)
            .map((session) => _parseDate(session.date))
            .whereType<DateTime>()
            .where(
              (date) =>
                  requestedMonth != null && date.month == requestedMonth.month,
            )
            .toList()
          ..sort();
    final allCounted =
        widget.summary.attendanceSessions
            .where((session) => session.counted)
            .map((session) => _parseDate(session.date))
            .whereType<DateTime>()
            .toList()
          ..sort();

    _selectedDay =
        countedInRequestedMonth.firstOrNull ??
        allCounted.firstOrNull ??
        _clampToCycle(requestedMonth ?? _cycleFrom);
    _focusedDay = _selectedDay;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Column(
      children: [
        if (!widget.embedded)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chi tiết ngày công thực tế',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.employeeName} • ${_formatDays(widget.summary.actualWorkingDays ?? 0)} ngày • ${_formatDate(_cycleFrom)}–${_formatDate(_cycleLastDay)}',
                        style: TextStyle(color: palette.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        if (widget.embedded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_formatDays(widget.summary.actualWorkingDays ?? 0)} ngày • ${_formatDate(_cycleFrom)}–${_formatDate(_cycleLastDay)}',
                style: TextStyle(color: palette.textSecondary),
              ),
            ),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _Legend(color: AppColors.online, label: 'Được tính công'),
              _Legend(color: AppColors.warning, label: 'Không được tính'),
              _Legend(color: AppColors.danger, label: 'Có đơn'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Divider(height: 1, color: palette.surfaceVariant),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 760) {
                return Row(
                  children: [
                    SizedBox(width: 390, child: _buildCalendar()),
                    VerticalDivider(width: 1, color: palette.surfaceVariant),
                    Expanded(child: _buildDayDetail()),
                  ],
                );
              }
              return Column(
                children: [
                  SizedBox(height: 360, child: _buildCalendar()),
                  Divider(height: 1, color: palette.surfaceVariant),
                  Expanded(child: _buildDayDetail()),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCalendar() {
    final palette = context.appPalette;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TableCalendar<void>(
        key: const ValueKey('employee-working-days-calendar'),
        firstDay: _cycleFrom,
        lastDay: _cycleLastDay,
        focusedDay: _focusedDay,
        rowHeight: 38,
        daysOfWeekHeight: 26,
        selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
        enabledDayPredicate: _isInsideCycle,
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = _normalize(selectedDay);
            _focusedDay = focusedDay;
          });
        },
        onPageChanged: (focusedDay) => _focusedDay = focusedDay,
        headerStyle: HeaderStyle(
          headerPadding: const EdgeInsets.symmetric(vertical: 4),
          titleCentered: true,
          formatButtonVisible: false,
          titleTextFormatter: (date, _) => 'Tháng ${date.month}/${date.year}',
          titleTextStyle: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          leftChevronIcon: Icon(Icons.chevron_left, color: palette.primary),
          rightChevronIcon: Icon(Icons.chevron_right, color: palette.primary),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: palette.textSecondary, fontSize: 12),
          weekendStyle: TextStyle(color: palette.textHint, fontSize: 12),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: true,
          markersMaxCount: 3,
          selectedDecoration: BoxDecoration(
            color: palette.primary,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: palette.primary.withValues(alpha: 0.25),
            shape: BoxShape.circle,
          ),
          disabledTextStyle: TextStyle(color: palette.textHint),
          defaultTextStyle: TextStyle(color: palette.textPrimary),
          weekendTextStyle: TextStyle(color: palette.textSecondary),
          outsideTextStyle: TextStyle(color: palette.textHint),
        ),
        calendarBuilders: CalendarBuilders<void>(
          markerBuilder: (context, day, _) {
            final sessions = _sessionsFor(day);
            final hasCounted = sessions.any((session) => session.counted);
            final hasExcluded = sessions.any((session) => !session.counted);
            final hasLeave = _ordersFor(day).isNotEmpty;
            if (!hasCounted && !hasExcluded && !hasLeave) {
              return const SizedBox.shrink();
            }
            return Positioned(
              bottom: 5,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasCounted) const _Marker(color: AppColors.online),
                  if (hasExcluded) const _Marker(color: AppColors.warning),
                  if (hasLeave) const _Marker(color: AppColors.danger),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDayDetail() {
    final palette = context.appPalette;
    final sessions = _sessionsFor(_selectedDay);
    final orders = _ordersFor(_selectedDay);
    final counted = sessions.any((session) => session.counted);
    final dayValue = sessions
        .where((session) => session.counted)
        .map((session) => session.dayValue)
        .whereType<double>()
        .firstOrNull;

    return ListView(
      key: const ValueKey('employee-working-days-day-detail'),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _formatFullDate(_selectedDay),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _StatusBadge(
              label: counted
                  ? 'Tính ${_formatDays(dayValue ?? 1)} công'
                  : 'Không tính công',
              color: counted ? AppColors.online : palette.textHint,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionTitle(
          icon: Icons.fingerprint,
          title: 'Chấm công (${sessions.length} phiên)',
        ),
        const SizedBox(height: 8),
        if (sessions.isEmpty)
          const _EmptyMessage(
            message: 'Không có phiên chấm công trong ngày này',
          )
        else
          for (final session in sessions) ...[
            _AttendanceSessionCard(session: session),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 12),
        _SectionTitle(
          icon: Icons.event_note_outlined,
          title: 'Đơn trong ngày (${orders.length})',
        ),
        const SizedBox(height: 8),
        if (orders.isEmpty)
          const _EmptyMessage(message: 'Không có đơn trong ngày này')
        else
          for (final order in orders) ...[
            _LeaveOrderCard(order: order),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 8),
        ExpansionTile(
          key: const ValueKey('employee-working-days-all-orders'),
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text(
            'Tất cả đơn trong chu kỳ (${widget.summary.leaveOrders.length})',
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            if (widget.summary.leaveOrders.isEmpty)
              const _EmptyMessage(message: 'Không có đơn trong chu kỳ')
            else
              for (final order in widget.summary.leaveOrders) ...[
                _LeaveOrderCard(order: order),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ],
    );
  }

  List<EmployeePayrollAttendanceSession> _sessionsFor(DateTime day) {
    final key = _dateKey(day);
    return widget.summary.attendanceSessions
        .where((session) => session.date == key)
        .toList(growable: false);
  }

  List<LeaveRequest> _ordersFor(DateTime day) {
    final normalized = _normalize(day);
    return widget.summary.leaveOrders
        .where((order) {
          final start = _parseDate(order.startDate);
          final end = _parseDate(order.endDate) ?? start;
          if (start == null || end == null) return false;
          return !normalized.isBefore(start) && !normalized.isAfter(end);
        })
        .toList(growable: false);
  }

  DateTime _clampToCycle(DateTime date) {
    if (date.isBefore(_cycleFrom)) return _cycleFrom;
    if (date.isAfter(_cycleLastDay)) return _cycleLastDay;
    return date;
  }

  bool _isInsideCycle(DateTime day) {
    final date = _normalize(day);
    return !date.isBefore(_cycleFrom) && !date.isAfter(_cycleLastDay);
  }
}

class _AttendanceSessionCard extends StatelessWidget {
  const _AttendanceSessionCard({required this.session});

  final EmployeePayrollAttendanceSession session;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final color = session.counted ? AppColors.online : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceVariant.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            session.counted ? Icons.check_circle : Icons.info_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Check-in ${_formatTime(session.checkIn)}  •  Check-out ${_formatTime(session.checkOut)}',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  session.counted
                      ? 'Được tính ${_formatDays(session.dayValue ?? 1)} công thực tế'
                      : _exclusionLabel(session.exclusionReason),
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (session.workedHours != null)
            _StatusBadge(
              label: '${session.workedHours!.toStringAsFixed(2)} giờ',
              color: color,
            ),
        ],
      ),
    );
  }
}

class _LeaveOrderCard extends StatelessWidget {
  const _LeaveOrderCard({required this.order});

  final LeaveRequest order;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final statusColor = _leaveStatusColor(order.status, palette);
    final duration = order.requestedDays == null
        ? ''
        : ' • ${_formatDays(order.requestedDays!)} ngày';
    final halfDay = order.isHalfDay
        ? ' • ${order.halfDayPart == 'morning' ? 'Buổi sáng' : 'Buổi chiều'}'
        : '';
    final time = order.startTime != null && order.endTime != null
        ? ' • ${order.startTime}–${order.endTime}'
        : '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceVariant.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.event_note_outlined, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _leaveTypeLabel(order.type),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${order.startDate} → ${order.endDate}$duration$halfDay$time',
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
                if (order.reason?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    order.reason!,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _StatusBadge(
            label: _leaveStatusLabel(order.status),
            color: statusColor,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Row(
      children: [
        Icon(icon, size: 18, color: palette.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(message, style: TextStyle(color: palette.textHint)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Marker(color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(color: palette.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

DateTime? _parseDate(String value) {
  final parsed = DateTime.tryParse(value);
  return parsed == null
      ? null
      : DateTime(parsed.year, parsed.month, parsed.day);
}

DateTime _normalize(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _formatFullDate(DateTime value) {
  const weekdays = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];
  return '${weekdays[value.weekday - 1]}, ${_formatDate(value)}';
}

DateTime? _toIct(DateTime? value) =>
    value?.toUtc().add(const Duration(hours: 7));

String _formatTime(DateTime? value) {
  final ict = _toIct(value);
  if (ict == null) return '--:--';
  return '${ict.hour.toString().padLeft(2, '0')}:${ict.minute.toString().padLeft(2, '0')}:${ict.second.toString().padLeft(2, '0')}';
}

String _exclusionLabel(String? reason) {
  return switch (reason) {
    'missing_checkout' => 'Không tính: chưa check-out',
    'invalid_checkin' => 'Không tính: check-in không hợp lệ',
    'invalid_checkout' => 'Không tính: check-out không hợp lệ',
    'checkout_before_checkin' => 'Không tính: check-out trước check-in',
    'overnight' => 'Không tính: check-in và check-out khác ngày',
    _ => 'Không được tính vào ngày công thực tế',
  };
}

String _leaveTypeLabel(String type) {
  return switch (type) {
    'annual' => 'Phép năm',
    'sick' => 'Nghỉ ốm',
    'personal' => 'Việc riêng',
    'wfh' => 'WFH',
    'ot' => 'OT',
    _ => type,
  };
}

String _leaveStatusLabel(String? status) {
  return switch (status) {
    'draft' => 'Nháp',
    'submitted' => 'Chờ duyệt',
    'approved' => 'Đã duyệt',
    'rejected' => 'Từ chối',
    'cancelled' => 'Đã hủy',
    _ => status ?? '-',
  };
}

Color _leaveStatusColor(String? status, AppThemePalette palette) {
  return switch (status) {
    'approved' => AppColors.online,
    'submitted' => AppColors.warning,
    'rejected' || 'cancelled' => AppColors.danger,
    _ => palette.textHint,
  };
}

String _formatDays(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);
