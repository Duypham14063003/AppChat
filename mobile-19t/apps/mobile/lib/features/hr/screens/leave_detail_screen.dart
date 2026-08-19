import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/hr_models.dart';
import '../providers/hr_providers.dart';
import '../../auth/providers/auth_notifier.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../hr_role_utils.dart';

class LeaveDetailScreen extends ConsumerWidget {
  final String leaveId;
  final LeaveRequest? leaveData;
  final bool asDialog;

  const LeaveDetailScreen({
    super.key,
    required this.leaveId,
    this.leaveData,
    this.asDialog = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appPalette;
    final leave = leaveData;
    final leaveYear = leave != null
        ? DateTime.tryParse(leave.startDate)?.year ?? DateTime.now().year
        : DateTime.now().year;
    final authState = ref.watch(authNotifierProvider);
    final currentUserId = authState.valueOrNull?.user?.id ?? '';
    final roles = authState.valueOrNull?.user?.roles ?? [];
    final isAdmin = roles.contains('admin');
    final canApproveLeaves = canApproveLeavesForRoles(roles);
    final isSubmitted = leave?.status == 'submitted';
    final isApproved = leave?.status == 'approved';
    final targetWfhUserId =
        leave != null &&
            leave.userId.isNotEmpty &&
            leave.userId != currentUserId &&
            isAdmin
        ? leave.userId
        : null;
    final wfhBalanceAsync = ref.watch(
      userWfhBalanceProvider(
        UserWfhBalanceQuery(year: leaveYear, userId: targetWfhUserId),
      ),
    );

    if (leave == null) {
      return Scaffold(
        backgroundColor: palette.background,
        appBar: asDialog ? null : AppBar(title: const Text('Chi tiết đơn')),
        body: Column(
          children: [
            if (asDialog)
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: palette.surfaceVariant),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.close, color: palette.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Chi tiết đơn',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Center(
                child: Text(
                  'Không có dữ liệu đơn nghỉ',
                  style: TextStyle(color: palette.textSecondary),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final statusColor = _statusColor(leave.status, palette);

    final customHeader = asDialog
        ? Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: palette.surfaceVariant)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.close, color: palette.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                Text(
                  leave.type == 'ot'
                      ? 'Chi tiết đơn OT'
                      : (leave.type == 'wfh'
                            ? 'Chi tiết đơn WFH'
                            : 'Chi tiết đơn nghỉ'),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        : const SizedBox.shrink();

    return Scaffold(
      backgroundColor: palette.background,
      appBar: asDialog
          ? null
          : AppBar(
              title: Text(
                leave.type == 'ot'
                    ? 'Chi tiết đơn OT'
                    : (leave.type == 'wfh'
                          ? 'Chi tiết đơn WFH'
                          : 'Chi tiết đơn nghỉ'),
              ),
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              customHeader,
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (canApproveLeaves &&
                        leave.userName != null &&
                        leave.userName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _row(context, 'Người xin', leave.userName!),
                      ),
                    _buildSummaryHeader(context, leave, statusColor, palette),
                    const SizedBox(height: 20),
                    _sectionTitle(context, 'Thông tin chung'),
                    _sectionCard(context, [
                      _row(context, 'Loại đơn', _typeLabel(leave.type)),
                      _row(context, 'Từ ngày', leave.startDate),
                      _row(context, 'Đến ngày', leave.endDate),
                      if (leave.type == 'wfh')
                        _row(
                          context,
                          'Hình thức WFH',
                          _wfhDurationLabel(leave),
                        ),
                      if (leave.type != 'ot' && leave.type != 'wfh') ...[
                        _row(
                          context,
                          'Nghỉ nửa ngày',
                          leave.isHalfDay ? 'Có' : 'Không',
                        ),
                        if (leave.isHalfDay && leave.halfDayPart != null)
                          _row(
                            context,
                            'Buổi nghỉ',
                            _halfDayLabel(leave.halfDayPart),
                          ),
                      ],
                      if (leave.type == 'ot') ...[
                        if (leave.startTime != null)
                          _row(context, 'Bắt đầu', leave.startTime!),
                        if (leave.endTime != null)
                          _row(context, 'Kết thúc', leave.endTime!),
                        if (leave.otTime != null)
                          _row(
                            context,
                            'Tổng số giờ OT',
                            '${_formatDays(leave.otTime)} giờ',
                          ),
                      ],
                    ]),
                    if (leave.type != 'ot') ...[
                      const SizedBox(height: 16),
                      _sectionTitle(context, 'Tổng số ngày'),
                      _sectionCard(context, [
                        if (leave.requestedDays != null)
                          _row(
                            context,
                            leave.type == 'wfh'
                                ? 'Tổng số ngày WFH'
                                : 'Tổng số ngày xin nghỉ',
                            _formatDays(leave.requestedDays),
                          ),
                        if (leave.type != 'wfh' && leave.paidDays != null)
                          _row(
                            context,
                            'Số ngày nghỉ có lương',
                            _formatDays(leave.paidDays),
                          ),
                        if (leave.type != 'wfh' && leave.unpaidDays != null)
                          _row(
                            context,
                            'Số ngày nghỉ không lương',
                            _formatDays(leave.unpaidDays),
                          ),
                      ]),
                    ],
                    if (leave.type == 'wfh') ...[
                      const SizedBox(height: 16),
                      _sectionTitle(context, 'Quota WFH'),
                      _WfhBalanceInfoCard(
                        balanceAsync: wfhBalanceAsync,
                        palette: palette,
                      ),
                    ],
                    const SizedBox(height: 16),
                    _sectionTitle(context, 'Thông tin khác'),
                    _sectionCard(context, [
                      if (leave.reason != null && leave.reason!.isNotEmpty)
                        _row(context, 'Lý do', leave.reason!),
                      if (leave.rejectReason != null &&
                          leave.rejectReason!.isNotEmpty)
                        _row(context, 'Lý do từ chối', leave.rejectReason!),
                    ]),
                    if (leave.approvedAt != null ||
                        leave.cancelledAt != null) ...[
                      const SizedBox(height: 16),
                      _sectionTitle(context, 'Lịch sử hoạt động'),
                      _sectionCard(context, [
                        if (leave.approvedAt != null) ...[
                          _row(
                            context,
                            'Người duyệt',
                            leave.approverName ?? 'Quản lý',
                          ),
                          _row(
                            context,
                            'Thời gian duyệt',
                            _formatDateTime(leave.approvedAt!),
                          ),
                        ],
                        if (leave.cancelledAt != null) ...[
                          _row(
                            context,
                            'Người hủy đơn',
                            leave.cancellerName ?? 'Quản lý',
                          ),
                          _row(
                            context,
                            'Thời gian hủy',
                            _formatDateTime(leave.cancelledAt!),
                          ),
                          if (leave.cancelReason != null &&
                              leave.cancelReason!.isNotEmpty)
                            _row(context, 'Lý do hủy', leave.cancelReason!),
                        ],
                      ]),
                    ],
                    if (leave.status == 'approved' &&
                        (leave.unpaidDays ?? 0) > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          (leave.paidDays ?? 0) > 0
                              ? 'Đơn đã duyệt nhưng chỉ một phần thời gian là nghỉ có lương.'
                              : 'Đơn đã duyệt dưới dạng nghỉ không lương.',
                          style: TextStyle(color: statusColor),
                        ),
                      ),
                    if (canApproveLeaves && isSubmitted) ...[
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _reject(context, ref),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.danger,
                              ),
                              child: const Text(
                                'Từ chối',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _approve(context, ref),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.online,
                              ),
                              child: const Text(
                                'Duyệt',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (canApproveLeaves && isApproved) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _cancelApprovedLeave(context, ref),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
                          ),
                          icon: const Icon(
                            Icons.cancel_outlined,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Hủy đơn đã duyệt',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final palette = context.appPalette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: palette.textSecondary, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(
    BuildContext context,
    LeaveRequest leave,
    Color statusColor,
    AppThemePalette palette,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _badge(context, _typeLabel(leave.type), palette.primary),
            _badge(context, _statusLabel(leave.status), statusColor),
            if (leave.type == 'ot' && leave.otTime != null && leave.otTime! > 0)
              _badge(
                context,
                '${_formatDays(leave.otTime)} giờ OT',
                palette.primary,
              ),
            if (leave.type != 'ot' &&
                leave.isHalfDay &&
                leave.halfDayPart != null)
              _badge(
                context,
                leave.type == 'wfh'
                    ? _wfhDurationLabel(leave)
                    : _halfDayLabel(leave.halfDayPart),
                AppColors.info,
              ),
            if (leave.type != 'ot' &&
                leave.type != 'wfh' &&
                leave.paidDays != null &&
                leave.paidDays! > 0)
              _badge(
                context,
                '${_formatDays(leave.paidDays)} ngày có lương',
                AppColors.online,
              ),
            if (leave.type != 'ot' &&
                leave.type != 'wfh' &&
                leave.unpaidDays != null &&
                leave.unpaidDays! > 0)
              _badge(
                context,
                '${_formatDays(leave.unpaidDays)} ngày không lương',
                AppColors.warning,
              ),
          ],
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    final palette = context.appPalette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _sectionCard(BuildContext context, List<Widget> children) {
    final palette = context.appPalette;
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.surfaceVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(children: children),
    );
  }

  Widget _badge(BuildContext context, String text, Color color) {
    final palette = context.appPalette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color == palette.primary ? palette.primary : color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(hrRepositoryProvider).approveLeave(leaveId);
      ref.invalidate(leaveListProvider);
      if (context.mounted) {
        showTopSnackBar(context, message: 'Đã duyệt');
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        showTopSnackBar(context, message: 'Lỗi: $e');
      }
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Lý do từ chối'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Nhập lý do...'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Từ chối'),
            ),
          ],
        );
      },
    );
    if (reason == null || reason.isEmpty) return;

    try {
      await ref.read(hrRepositoryProvider).rejectLeave(leaveId, reason);
      ref.invalidate(leaveListProvider);
      if (context.mounted) {
        showTopSnackBar(context, message: 'Đã từ chối');
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        showTopSnackBar(context, message: 'Lỗi: $e');
      }
    }
  }

  Future<void> _cancelApprovedLeave(BuildContext context, WidgetRef ref) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Hủy đơn đã duyệt'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            maxLength: 255,
            decoration: const InputDecoration(
              labelText: 'Lý do hủy',
              hintText: 'Nhập lý do hủy đơn...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Đóng'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) return;
                Navigator.pop(dialogContext, value);
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Xác nhận hủy'),
            ),
          ],
        );
      },
    );
    if (reason == null || reason.trim().isEmpty) return;

    try {
      await ref
          .read(hrRepositoryProvider)
          .cancelApprovedLeave(leaveId, reason.trim());
      ref.invalidate(leaveListProvider);
      ref.invalidate(leaveBalanceProvider);
      ref.invalidate(wfhBalanceProvider);
      ref.invalidate(userWfhBalanceProvider);
      if (context.mounted) {
        showTopSnackBar(context, message: 'Đã hủy đơn và hoàn lại quota');
        Navigator.pop(context);
      }
    } catch (error) {
      if (context.mounted) {
        showTopSnackBar(context, message: 'Lỗi: $error');
      }
    }
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
        return status ?? '—';
    }
  }

  String _halfDayLabel(String? part) {
    switch (part) {
      case 'morning':
        return 'Buổi sáng';
      case 'afternoon':
        return 'Buổi chiều';
      default:
        return 'Nửa ngày';
    }
  }

  String _wfhDurationLabel(LeaveRequest leave) {
    if (!leave.isHalfDay) return 'Cả ngày';
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

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.day}/${local.month}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _WfhBalanceInfoCard extends StatelessWidget {
  const _WfhBalanceInfoCard({
    required this.balanceAsync,
    required this.palette,
  });

  final AsyncValue<WfhBalance> balanceAsync;
  final AppThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.surfaceVariant),
      ),
      child: balanceAsync.when(
        loading: () => Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Đang tải quota WFH...',
                style: TextStyle(color: palette.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
        error: (error, _) => Text(
          'Không tải được quota WFH hiện tại.',
          style: TextStyle(color: palette.textSecondary, fontSize: 12),
        ),
        data: (balance) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _quotaChip('Tổng: ${_formatMetric(balance.allocatedDays)} ngày'),
            _quotaChip('Đã dùng: ${_formatMetric(balance.usedDays)} ngày'),
            _quotaChip('Còn lại: ${_formatMetric(balance.remainingDays)} ngày'),
          ],
        ),
      ),
    );
  }

  Widget _quotaChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: palette.textSecondary, fontSize: 12),
      ),
    );
  }

  String _formatMetric(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}
