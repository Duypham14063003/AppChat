import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/hr_models.dart';
import '../providers/hr_providers.dart';
import '../../auth/providers/auth_notifier.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../../../shared/widgets/heart_header_badge.dart';
import '../hr_role_utils.dart';
import 'leave_create_screen.dart';
import 'leave_detail_screen.dart';
import 'employee_working_days_detail_dialog.dart';

class LeaveListScreen extends ConsumerStatefulWidget {
  const LeaveListScreen({super.key});

  @override
  ConsumerState<LeaveListScreen> createState() => _LeaveListScreenState();
}

class _LeaveListScreenState extends ConsumerState<LeaveListScreen> {
  bool _isExportingPayroll = false;

  static const _tabs = ['Tất cả', 'Chờ duyệt', 'Đã duyệt', 'Từ chối', 'Đã hủy'];
  static const _filters = [
    null,
    'submitted',
    'approved',
    'rejected',
    'cancelled',
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final leavesAsync = ref.watch(leaveListProvider);
    final selectedMonth = ref.watch(leaveListProvider.notifier).selectedMonth;
    final selectedYear = ref.watch(leaveListProvider.notifier).selectedYear;
    final selectedEmployeeId = ref
        .watch(leaveListProvider.notifier)
        .selectedEmployeeId;
    final authState = ref.watch(authNotifierProvider);
    final roles = authState.valueOrNull?.user?.roles ?? [];
    final isAdmin = roles.contains('admin');
    final canApproveLeaves = canApproveLeavesForRoles(roles);
    final employeeOptionsAsync = canApproveLeaves
        ? ref.watch(leaveEmployeeOptionsProvider)
        : const AsyncValue<List<HrEmployeeSummary>>.data([]);
    HrEmployeeSummary? selectedEmployee;
    if (selectedEmployeeId != null) {
      for (final employee in employeeOptionsAsync.valueOrNull ?? const []) {
        if (employee.id == selectedEmployeeId) {
          selectedEmployee = employee;
          break;
        }
      }
    }
    final payrollMonth = _formatPayrollMonth(selectedYear, selectedMonth);
    final employeeSummaryAsync = selectedEmployeeId == null
        ? null
        : ref.watch(
            employeePayrollSummaryProvider(
              EmployeePayrollSummaryQuery(
                month: payrollMonth,
                userId: selectedEmployeeId,
              ),
            ),
          );
    final config = authState.valueOrNull?.payrollStartConfig;
    final currentPayrollMonth = resolveCurrentPayrollMonth(config ?? 1);
    final isWide = MediaQuery.of(context).size.width >= 768;

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Xem Đơn'),
          actions: [
            if (canManageEmployeesForRoles(roles))
              IconButton(
                icon: const Icon(Icons.badge_outlined),
                tooltip: 'Quản lý nhân sự',
                onPressed: () => context.push('/employees'),
              ),
            if (canApproveLeaves)
              IconButton(
                key: const ValueKey('leave-list-export-payroll'),
                icon: _isExportingPayroll
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                tooltip: 'Xuất bảng lương (.xlsx)',
                onPressed: _isExportingPayroll
                    ? null
                    : () => _exportPayrollWorkbook(
                        currentPayrollMonth.year,
                        selectedMonth,
                      ),
              ),
            if (canApproveLeaves)
              IconButton(
                icon: const Icon(Icons.calendar_view_week_outlined),
                tooltip: 'Lịch OFF/WFH',
                onPressed: () => context.push('/hr/weekly-schedule'),
              ),
            if (isAdmin)
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Cấu hình HR',
                onPressed: () => context.push('/hr/config'),
              ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(child: HeartHeaderBadge(compact: true)),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            labelColor: palette.primary,
            unselectedLabelColor: palette.textSecondary,
            indicatorColor: palette.primary,
            dividerColor: palette.surfaceVariant.withValues(alpha: 0.55),
            tabs: _tabs.map((t) => Tab(text: t)).toList(),
            onTap: (i) =>
                ref.read(leaveListProvider.notifier).setFilter(_filters[i]),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: palette.primary,
          onPressed: () {
            if (isWide) {
              showDialog(
                context: context,
                builder: (dialogCtx) => Dialog(
                  backgroundColor: palette.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const SizedBox(
                    width: 540,
                    height: 680,
                    child: LeaveCreateScreen(asDialog: true),
                  ),
                ),
              );
            } else {
              context.push('/hr/leaves/create');
            }
          },
          child: Icon(
            Icons.add,
            color: palette.isLight ? Colors.white : palette.background,
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isWide ? 24 : 12,
                    12,
                    isWide ? 24 : 12,
                    4,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            'Tháng',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: selectedMonth,
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
                                  borderSide: BorderSide(
                                    color: palette.primary,
                                  ),
                                ),
                              ),
                              iconEnabledColor: palette.primary,
                              style: TextStyle(color: palette.textPrimary),
                              items: List.generate(
                                currentPayrollMonth.month,
                                (index) => DropdownMenuItem<int>(
                                  value: index + 1,
                                  child: Text('Tháng ${index + 1}'),
                                ),
                              ),
                              onChanged: (month) {
                                if (month != null) {
                                  ref
                                      .read(leaveListProvider.notifier)
                                      .setMonth(month);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (canApproveLeaves) ...[
                        Builder(
                          builder: (context) {
                            final employees =
                                employeeOptionsAsync.valueOrNull ??
                                const <HrEmployeeSummary>[];
                            final duplicateNameCounts = <String, int>{};
                            for (final employee in employees) {
                              final key = employee.name.trim().toLowerCase();
                              duplicateNameCounts[key] =
                                  (duplicateNameCounts[key] ?? 0) + 1;
                            }

                            return Row(
                              children: [
                                Text(
                                  'Nhân viên',
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String?>(
                                    key: ValueKey(selectedEmployeeId),
                                    initialValue: selectedEmployeeId,
                                    dropdownColor: palette.card,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: palette.card,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
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
                                        borderSide: BorderSide(
                                          color: palette.primary,
                                        ),
                                      ),
                                    ),
                                    iconEnabledColor: palette.primary,
                                    style: TextStyle(
                                      color: palette.textPrimary,
                                    ),
                                    items: [
                                      const DropdownMenuItem(
                                        value: null,
                                        child: Text('Tất cả nhân viên'),
                                      ),
                                      ...employees.map(
                                        (employee) => DropdownMenuItem(
                                          value: employee.id,
                                          child: Text(
                                            _employeeOptionLabel(
                                              employee,
                                              duplicateNameCounts,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: employeeOptionsAsync.hasValue
                                        ? (value) {
                                            ref
                                                .read(
                                                  leaveListProvider.notifier,
                                                )
                                                .setSelectedEmployeeId(value);
                                          }
                                        : null,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        if (employeeOptionsAsync.isLoading)
                          const LinearProgressIndicator(minHeight: 2)
                        else if (employeeOptionsAsync.hasError)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () =>
                                  ref.invalidate(leaveEmployeeOptionsProvider),
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Tải lại danh sách nhân viên'),
                            ),
                          )
                        else if ((employeeOptionsAsync.valueOrNull ?? const [])
                            .isEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Không có nhân viên trong danh bạ',
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          _TypeFilterChip(
                            label: 'Tất cả',
                            isSelected:
                                ref
                                    .watch(leaveListProvider.notifier)
                                    .typeFilter ==
                                null,
                            onSelected: () => ref
                                .read(leaveListProvider.notifier)
                                .setTypeFilter(null),
                          ),
                          const SizedBox(width: 8),
                          _TypeFilterChip(
                            label: 'Nghỉ phép',
                            isSelected:
                                ref
                                    .watch(leaveListProvider.notifier)
                                    .typeFilter ==
                                'leave',
                            onSelected: () => ref
                                .read(leaveListProvider.notifier)
                                .setTypeFilter('leave'),
                          ),
                          const SizedBox(width: 8),
                          _TypeFilterChip(
                            label: 'OT',
                            isSelected:
                                ref
                                    .watch(leaveListProvider.notifier)
                                    .typeFilter ==
                                'ot',
                            onSelected: () => ref
                                .read(leaveListProvider.notifier)
                                .setTypeFilter('ot'),
                          ),
                          const SizedBox(width: 8),
                          _TypeFilterChip(
                            label: 'WFH',
                            isSelected:
                                ref
                                    .watch(leaveListProvider.notifier)
                                    .typeFilter ==
                                'wfh',
                            onSelected: () => ref
                                .read(leaveListProvider.notifier)
                                .setTypeFilter('wfh'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: leavesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Lỗi: $e')),
                    data: (response) {
                      final leaves = response.leaves;
                      final otHours = response.otHours;
                      final leaveDays = response.leaveDays;
                      final wfhDays = response.wfhDays;
                      final summaryItems = <Widget>[
                        if (otHours > 0)
                          _SummaryMetric(
                            label: 'Tổng giờ OT',
                            value: '${otHours.toStringAsFixed(1)} giờ',
                            valueColor: palette.primary,
                          ),
                        if (leaveDays > 0)
                          _SummaryMetric(
                            label: 'Tổng ngày nghỉ',
                            value: '${_formatSummaryDays(leaveDays)} ngày',
                            valueColor: AppColors.online,
                          ),
                        if (wfhDays > 0)
                          _SummaryMetric(
                            label: 'Tổng WFH',
                            value: '${_formatSummaryDays(wfhDays)} ngày',
                            valueColor: palette.primary,
                          ),
                        if (employeeSummaryAsync != null)
                          _buildWorkingDaysMetric(
                            employeeSummaryAsync,
                            palette.primary,
                            selectedEmployee?.name ?? 'Nhân viên',
                          ),
                      ];

                      return RefreshIndicator(
                        onRefresh: () async {
                          await ref.read(leaveListProvider.notifier).refresh();
                          if (selectedEmployeeId != null) {
                            ref.invalidate(
                              employeePayrollSummaryProvider(
                                EmployeePayrollSummaryQuery(
                                  month: payrollMonth,
                                  userId: selectedEmployeeId,
                                ),
                              ),
                            );
                          }
                        },
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.only(bottom: isWide ? 24 : 16),
                          children: [
                            if (summaryItems.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  4,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: palette.primary.withValues(
                                      alpha: 0.05,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: palette.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                  ),
                                  child: _SummaryMetricsLayout(
                                    items: summaryItems,
                                  ),
                                ),
                              ),
                            if (leaves.isEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  32,
                                  16,
                                  48,
                                ),
                                child: Center(
                                  child: Text(
                                    selectedEmployeeId == null
                                        ? 'Không có đơn trong tháng $selectedMonth'
                                        : 'Không tìm thấy đơn phù hợp',
                                    style: TextStyle(
                                      color: palette.textSecondary,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isWide ? 24 : 12,
                                  vertical: 12,
                                ),
                                child: Column(
                                  children: [
                                    for (final leave in leaves)
                                      _LeaveCard(
                                        leave: leave,
                                        onTap: () {
                                          if (isWide) {
                                            showDialog(
                                              context: context,
                                              builder: (dialogCtx) => Dialog(
                                                backgroundColor:
                                                    palette.surface,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: SizedBox(
                                                  width: 540,
                                                  height: 680,
                                                  child: LeaveDetailScreen(
                                                    leaveId: leave.id,
                                                    leaveData: leave,
                                                    asDialog: true,
                                                  ),
                                                ),
                                              ),
                                            );
                                          } else {
                                            context.push(
                                              '/hr/leaves/${leave.id}',
                                              extra: leave,
                                            );
                                          }
                                        },
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportPayrollWorkbook(int year, int month) async {
    if (_isExportingPayroll) return;

    setState(() => _isExportingPayroll = true);
    final exportMonth = _formatPayrollMonth(year, month);

    try {
      final workbook = await ref
          .read(hrRepositoryProvider)
          .exportPayrollWorkbook(month: exportMonth);
      await ref.read(payrollExportFileServiceProvider).save(workbook);

      if (!mounted) return;
      showTopSnackBar(context, message: 'Đã xuất file ${workbook.filename}.');
    } on DioException catch (error) {
      if (!mounted) return;
      showTopSnackBar(
        context,
        message: _extractExportErrorMessage(error),
        backgroundColor: Colors.redAccent,
      );
    } catch (_) {
      if (!mounted) return;
      showTopSnackBar(
        context,
        message: 'Không thể xuất file bảng lương.',
        backgroundColor: Colors.redAccent,
      );
    } finally {
      if (mounted) {
        setState(() => _isExportingPayroll = false);
      }
    }
  }

  Widget _buildWorkingDaysMetric(
    AsyncValue<EmployeePayrollSummary> summaryAsync,
    Color primaryColor,
    String employeeName,
  ) {
    return summaryAsync.when(
      loading: () => _SummaryMetric(
        label: 'Ngày công thực tế',
        value: 'Đang tải...',
        valueColor: primaryColor,
      ),
      error: (_, _) => const _SummaryMetric(
        label: 'Ngày công thực tế',
        value: 'Không tải được',
        valueColor: AppColors.warning,
      ),
      data: (summary) {
        return switch (summary.attendanceStatus) {
          AttendanceDataStatus.available => _SummaryMetric(
            key: const ValueKey('leave-list-actual-working-days'),
            label: 'Ngày công thực tế',
            value: '${_formatSummaryDays(summary.actualWorkingDays ?? 0)} ngày',
            valueColor: primaryColor,
            onTap: () => showEmployeeWorkingDaysDetail(
              context: context,
              summary: summary,
              employeeName: employeeName,
            ),
          ),
          AttendanceDataStatus.unmapped => const _SummaryMetric(
            label: 'Ngày công thực tế',
            value: 'Chưa liên kết Odoo',
            valueColor: AppColors.warning,
          ),
          AttendanceDataStatus.unavailable => const _SummaryMetric(
            label: 'Ngày công thực tế',
            value: 'Không có dữ liệu',
            valueColor: AppColors.warning,
          ),
        };
      },
    );
  }
}

String _formatPayrollMonth(int year, int month) {
  return '$year-${month.toString().padLeft(2, '0')}';
}

String _extractExportErrorMessage(DioException error) {
  final responseData = error.response?.data;
  if (responseData is Map<String, dynamic>) {
    final message = responseData['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message;
    }
  }

  return 'Không thể xuất file bảng lương.';
}

String _employeeOptionLabel(
  HrEmployeeSummary employee,
  Map<String, int> duplicateNameCounts,
) {
  final name = employee.name.trim().isEmpty ? employee.email : employee.name;
  final normalizedName = employee.name.trim().toLowerCase();
  final duplicateSuffix = (duplicateNameCounts[normalizedName] ?? 0) > 1
      ? ' • ${employee.email}'
      : '';
  final inactiveSuffix = employee.isActive ? '' : ' (đã nghỉ)';
  return '$name$duplicateSuffix$inactiveSuffix';
}

class _SummaryMetricsLayout extends StatelessWidget {
  const _SummaryMetricsLayout({required this.items});

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final requestedColumns = constraints.maxWidth >= 560 ? items.length : 2;
        final columns = requestedColumns.clamp(1, items.length);
        const spacing = 12.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items) SizedBox(width: itemWidth, child: item),
          ],
        );
      },
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    super.key,
    // required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
    this.onTap,
  });

  // final Widget icon;
  final String label;
  final String value;
  final Color valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 3),
              Icon(Icons.open_in_new, size: 12, color: palette.textSecondary),
            ],
          ],
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: '$label, $value, xem chi tiết',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: content,
        ),
      ),
    );
  }
}

class _TypeFilterChip extends StatelessWidget {
  const _TypeFilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? palette.primary : palette.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? palette.primary : palette.surfaceVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : palette.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

String _formatSummaryDays(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

class _LeaveCard extends StatelessWidget {
  final LeaveRequest leave;
  final VoidCallback onTap;

  const _LeaveCard({required this.leave, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final statusColor = _statusColor(leave.status, palette);
    final showRequestedDays = (leave.requestedDays ?? 0) > 0;
    final showPaidDays = (leave.paidDays ?? 0) > 0;
    final showUnpaidDays = (leave.unpaidDays ?? 0) > 0;
    final showOtTime = leave.type == 'ot' && (leave.otTime ?? 0) > 0;
    final showWfhDuration = leave.type == 'wfh';
    final showInfoChips =
        showWfhDuration ||
        leave.isHalfDay ||
        showRequestedDays ||
        showPaidDays ||
        showUnpaidDays ||
        showOtTime;

    return Card(
      color: palette.card,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _typeLabel(leave.type),
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (leave.userName != null &&
                            leave.userName!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              leave.userName!,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _statusBadge(context, leave.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _subtitleText(leave),
                style: TextStyle(color: palette.textSecondary, fontSize: 12),
              ),
              if (showInfoChips) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (showWfhDuration)
                      _infoChip(
                        context,
                        _wfhDurationLabel(leave),
                        palette.primary,
                      ),
                    if (leave.isHalfDay && leave.type != 'wfh')
                      _infoChip(
                        context,
                        _halfDayLabel(leave.halfDayPart),
                        palette.primary,
                      ),
                    if (showRequestedDays)
                      _infoChip(
                        context,
                        leave.type == 'wfh'
                            ? '${_formatDays(leave.requestedDays)} ngày WFH'
                            : '${_formatDays(leave.requestedDays)} ngày xin nghỉ',
                        palette.textSecondary,
                      ),
                    if (showOtTime)
                      _infoChip(
                        context,
                        '${_formatDays(leave.otTime)} giờ OT',
                        palette.primary,
                      ),
                    if (showPaidDays)
                      _infoChip(
                        context,
                        '${_formatDays(leave.paidDays)} ngày có lương',
                        AppColors.online,
                      ),
                    if (showUnpaidDays)
                      _infoChip(
                        context,
                        '${_formatDays(leave.unpaidDays)} ngày không lương',
                        AppColors.warning,
                      ),
                  ],
                ),
              ],
              if (leave.type != 'wfh' &&
                  leave.status == 'approved' &&
                  (leave.unpaidDays ?? 0) > 0 &&
                  (leave.paidDays ?? 0) > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Đơn đã duyệt nhưng có phần nghỉ không lương.',
                  style: TextStyle(color: statusColor, fontSize: 12),
                ),
              ],
              if (leave.type != 'wfh' &&
                  leave.status == 'approved' &&
                  (leave.unpaidDays ?? 0) > 0 &&
                  (leave.paidDays ?? 0) == 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Đơn đã duyệt dưới dạng nghỉ không lương.',
                  style: TextStyle(color: statusColor, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(BuildContext context, String? status) {
    final palette = context.appPalette;
    final color = _statusColor(status, palette);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }

  Widget _infoChip(BuildContext context, String text, Color color) {
    final palette = context.appPalette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color == palette.textSecondary ? palette.textSecondary : color,
          fontSize: 12,
        ),
      ),
    );
  }

  String _subtitleText(LeaveRequest leave) {
    final dateRange = '${leave.startDate} → ${leave.endDate}';
    if (leave.type == 'ot' &&
        leave.startTime != null &&
        leave.endTime != null) {
      return '$dateRange • ${leave.startTime} - ${leave.endTime}';
    }
    return dateRange;
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'annual':
        return 'Phép năm';
      case 'sick':
        return 'Nghỉ ốm';
      case 'personal':
        return 'Việc riêng';
      case 'wfh':
        return 'WFH';
      case 'ot':
        return 'OT';
      default:
        return type;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'draft':
        return 'Nháp';
      case 'submitted':
        return 'Chờ duyệt';
      case 'approved':
        return 'Đã duyệt';
      case 'rejected':
        return 'Từ chối';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status ?? '';
    }
  }

  String _halfDayLabel(String? part) {
    switch (part) {
      case 'morning':
        return 'Nửa ngày • Buổi sáng';
      case 'afternoon':
        return 'Nửa ngày • Buổi chiều';
      default:
        return 'Nửa ngày';
    }
  }

  String _wfhDurationLabel(LeaveRequest leave) {
    if (!leave.isHalfDay) {
      return 'Cả ngày';
    }
    switch (leave.halfDayPart) {
      case 'morning':
        return 'Nửa buổi sáng';
      case 'afternoon':
        return 'Nửa buổi chiều';
      default:
        return 'Nửa buổi';
    }
  }

  Color _statusColor(String? status, AppThemePalette palette) {
    switch (status) {
      case 'draft':
        return palette.textHint;
      case 'submitted':
        return AppColors.warning;
      case 'approved':
        return AppColors.online;
      case 'rejected':
        return AppColors.danger;
      case 'cancelled':
        return AppColors.danger;
      default:
        return palette.textHint;
    }
  }

  String _formatDays(double? value) {
    if (value == null) return '0';
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}
