import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/hr_models.dart';
import '../providers/hr_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../../../core/utils/snackbar_utils.dart';

String? validateLeaveRequestInput({
  required String type,
  required bool isHalfDay,
  required DateTime startDate,
  required DateTime endDate,
  String? halfDayPart,
  TimeOfDay? startTime,
  TimeOfDay? endTime,
}) {
  final isOt = type == 'ot';
  if (isOt && startTime != null && endTime != null) {
    final startDateTime = combineDateAndTime(startDate, startTime);
    final endDateTime = combineDateAndTime(endDate, endTime);
    if (!endDateTime.isAfter(startDateTime)) {
      return 'Giờ kết thúc phải sau giờ bắt đầu';
    }
  }

  if (!isOt && isHalfDay && (halfDayPart == null || halfDayPart.isEmpty)) {
    return 'Vui lòng chọn buổi áp dụng';
  }

  if (!isOt && isHalfDay && !_isSameDate(startDate, endDate)) {
    return type == 'wfh'
        ? 'WFH nửa buổi chỉ được phép trong cùng 1 ngày'
        : 'Nghỉ nửa ngày chỉ được phép trong cùng 1 ngày';
  }

  return null;
}

double calculateOtHours({
  required DateTime startDate,
  required DateTime endDate,
  required TimeOfDay startTime,
  required TimeOfDay endTime,
}) {
  final startDateTime = combineDateAndTime(startDate, startTime);
  final endDateTime = combineDateAndTime(endDate, endTime);
  if (!endDateTime.isAfter(startDateTime)) return 0;
  return endDateTime.difference(startDateTime).inMinutes / 60.0;
}

String formatLeaveBalanceDays(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

String buildLeaveBalanceMessage(LeaveBalance balance) {
  if (balance.employmentStatus == 'probation') {
    return 'Bạn là nhân viên thử việc, nghỉ phép sẽ không tính lương';
  }

  if (balance.employmentStatus == 'official' &&
      balance.hasRemainingPaidLeave &&
      balance.remainingPaidDays > 0) {
    return 'Bạn còn ${formatLeaveBalanceDays(balance.remainingPaidDays)} ngày nghỉ có lương trong năm ${balance.year}';
  }

  if (balance.employmentStatus == 'official' &&
      !balance.hasRemainingPaidLeave) {
    return 'Bạn đã dùng hết phép có lương trong năm ${balance.year}';
  }

  if (!balance.isPaidLeaveEligible) {
    return 'Không có thông tin phép có lương khả dụng trong năm ${balance.year}';
  }

  return 'Bạn còn ${formatLeaveBalanceDays(balance.remainingPaidDays)} ngày nghỉ có lương trong năm ${balance.year}';
}

class LeaveCreateScreen extends ConsumerStatefulWidget {
  final bool asDialog;

  const LeaveCreateScreen({super.key, this.asDialog = false});

  @override
  ConsumerState<LeaveCreateScreen> createState() => _LeaveCreateScreenState();
}

class _LeaveCreateScreenState extends ConsumerState<LeaveCreateScreen> {
  String _requestKind = 'leave';
  String _type = 'annual';
  bool _isHalfDay = false;
  String? _halfDayPart;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 21, minute: 0);
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  bool get _isOt => _requestKind == 'ot';
  bool get _isWfh => _requestKind == 'wfh';
  bool get _isLeave => _requestKind == 'leave';
  bool get _supportsHalfDay => !_isOt;
  String get _effectiveType => _isOt ? 'ot' : (_isWfh ? 'wfh' : _type);

  /// Auto-calculate total OT hours from one continuous OT window.
  double get _calculatedOtHours {
    return calculateOtHours(
      startDate: _startDate,
      endDate: _endDate,
      startTime: _startTime,
      endTime: _endTime,
    );
  }

  String get _formattedOtHours {
    final h = _calculatedOtHours;
    if (h == h.roundToDouble()) return h.toStringAsFixed(0);
    return h.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate) || _isHalfDay) {
          _endDate = _startDate;
        }
      } else {
        _endDate = _isHalfDay ? _startDate : picked;
      }
    });
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _submit({bool asDraft = false}) async {
    final validationError = _validateForm();
    if (validationError != null) {
      _showMessage(validationError, isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(hrRepositoryProvider);
      final created = await repo.createLeave({
        'type': _effectiveType,
        'start_date': _formatDate(_startDate),
        'end_date': _formatDate(_endDate),
        if (_isOt) 'start_time': _formatTime(_startTime),
        if (_isOt) 'end_time': _formatTime(_endTime),
        if (_isOt) 'ot_time': _calculatedOtHours,
        if (!_isOt) 'is_half_day': _isHalfDay,
        if (!_isOt && _isHalfDay && _halfDayPart != null)
          'half_day_part': _halfDayPart,
        'reason': _reasonController.text.trim().isEmpty
            ? null
            : _reasonController.text.trim(),
      });

      if (!asDraft) {
        await repo.submitLeave(created.id);
      }

      ref.invalidate(leaveListProvider);
      if (mounted) context.pop();
    } on DioException catch (e) {
      _showMessage(_extractErrorMessage(e), isError: true);
    } catch (e) {
      _showMessage('Lỗi: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _validateForm() {
    return validateLeaveRequestInput(
      type: _effectiveType,
      isHalfDay: _isHalfDay,
      startDate: _startDate,
      endDate: _endDate,
      halfDayPart: _halfDayPart,
      startTime: _startTime,
      endTime: _endTime,
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    showTopSnackBar(
      context,
      message: message,
      backgroundColor: isError ? AppColors.danger : null,
    );
  }

  String _extractErrorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message']?.toString();
      if (message != null && message.isNotEmpty) return message;

      final errorDetail = data['error']?.toString();
      if (errorDetail != null && errorDetail.isNotEmpty) return errorDetail;
    }

    return error.message ?? 'Không thể gửi đơn. Vui lòng thử lại.';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final now = DateTime.now();
    final leaveBalanceAsync = ref.watch(
      leaveBalanceProvider(LeaveBalanceQuery(year: now.year)),
    );
    final wfhBalanceAsync = ref.watch(
      wfhBalanceProvider(LeaveBalanceQuery(year: now.year)),
    );

    final customHeader = widget.asDialog
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
                  'Tạo đơn',
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
      appBar: widget.asDialog
          ? null
          : AppBar(
              title: Text('Tạo đơn', style: TextStyle(color: palette.textPrimary)),
              iconTheme: IconThemeData(color: palette.textPrimary),
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              customHeader,
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Loại đơn',
                      style: TextStyle(color: palette.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'leave',
                          label: Text('OFF'),
                        ),
                        ButtonSegment(value: 'wfh', label: Text('WFH')),
                        ButtonSegment(value: 'ot', label: Text('OT')),
                      ],
                      selected: {_requestKind},
                      multiSelectionEnabled: false,
                      onSelectionChanged: (v) {
                        setState(() {
                          _requestKind = v.first;
                          if (_isOt) {
                            _type = 'ot';
                            _isHalfDay = false;
                            _halfDayPart = null;
                          } else if (_isWfh) {
                            _type = 'wfh';
                            if (_isHalfDay) {
                              _endDate = _startDate;
                            }
                          } else {
                            if (_type == 'ot' || _type == 'wfh') {
                              _type = 'annual';
                            }
                            if (_isHalfDay) {
                              _endDate = _startDate;
                            }
                          }
                        });
                      },
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: palette.primary.withValues(
                          alpha: 0.18,
                        ),
                        selectedForegroundColor: palette.textPrimary,
                        foregroundColor: palette.textPrimary,
                        side: BorderSide(color: palette.surfaceVariant),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    // const SizedBox(height: 16),
                    // _policyCard(palette, employmentStatus),
                    if (_isLeave) ...[
                      const SizedBox(height: 12),
                      LeaveBalanceInfoCard(
                        balanceAsync: leaveBalanceAsync,
                        palette: palette,
                      ),
                    ],
                    if (_isWfh) ...[
                      const SizedBox(height: 12),
                      WfhBalanceInfoCard(
                        balanceAsync: wfhBalanceAsync,
                        palette: palette,
                      ),
                    ],
                    if (_isLeave) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Loại nghỉ phép',
                        style: TextStyle(color: palette.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _type == 'ot' || _type == 'wfh'
                            ? 'annual'
                            : _type,
                        dropdownColor: palette.card,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: palette.card,
                          hintStyle: TextStyle(color: palette.textHint),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: palette.surfaceVariant),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: palette.primary),
                          ),
                        ),
                        iconEnabledColor: palette.textSecondary,
                        style: TextStyle(color: palette.textPrimary),
                        items: const [
                          DropdownMenuItem(value: 'annual', child: Text('Phép năm')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _type = value);
                        },
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _dateTile(
                            'Từ ngày',
                            _startDate,
                            () => _pickDate(true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _dateTile(
                            'Đến ngày',
                            _endDate,
                            () => _pickDate(false),
                          ),
                        ),
                      ],
                    ),
                    if (_supportsHalfDay) ...[
                      const SizedBox(height: 20),
                      Text(
                        _isWfh ? 'Thời lượng WFH' : 'Thời lượng nghỉ',
                        style: TextStyle(color: palette.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('Cả ngày')),
                          ButtonSegment(value: true, label: Text('Nửa ngày')),
                        ],
                        selected: {_isHalfDay},
                        multiSelectionEnabled: false,
                        onSelectionChanged: (value) {
                          setState(() {
                            _isHalfDay = value.first;
                            if (_isHalfDay) {
                              _endDate = _startDate;
                              _halfDayPart ??= 'morning';
                            } else {
                              _halfDayPart = null;
                            }
                          });
                        },
                        style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: palette.primary.withValues(
                            alpha: 0.18,
                          ),
                          selectedForegroundColor: palette.textPrimary,
                          foregroundColor: palette.textPrimary,
                          side: BorderSide(color: palette.surfaceVariant),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      if (_isHalfDay) ...[
                        const SizedBox(height: 16),
                        Text(
                          _isWfh ? 'WFH nửa buổi' : 'Nghỉ nửa ngày',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'morning', label: Text('Buổi sáng')),
                            ButtonSegment(
                              value: 'afternoon',
                              label: Text('Buổi chiều'),
                            ),
                          ],
                          selected: {_halfDayPart ?? 'morning'},
                          multiSelectionEnabled: false,
                          onSelectionChanged: (value) {
                            setState(() => _halfDayPart = value.first);
                          },
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: palette.primary.withValues(
                              alpha: 0.18,
                            ),
                            selectedForegroundColor: palette.textPrimary,
                            foregroundColor: palette.textPrimary,
                            side: BorderSide(color: palette.surfaceVariant),
                            // bordeRadius is not working for some reason, applying manually in segments
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ],
                    if (_isOt) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _timeTile(
                              'Bắt đầu',
                              _startTime,
                              () => _pickTime(true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _timeTile(
                              'Kết thúc',
                              _endTime,
                              () => _pickTime(false),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_isOt) ...[
                      const SizedBox(height: 20),
                      InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Tổng thời gian OT (giờ)',
                          labelStyle: TextStyle(color: palette.textSecondary),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: palette.surfaceVariant),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: palette.primary),
                          ),
                          filled: true,
                          fillColor: palette.card,
                        ),
                        child: Text(
                          _calculatedOtHours > 0
                              ? '$_formattedOtHours giờ'
                              : 'Vui lòng chọn giờ hợp lệ',
                          style: TextStyle(
                            color: _calculatedOtHours > 0
                                ? palette.textPrimary
                                : palette.textHint,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    TextField(
                      controller: _reasonController,
                      maxLines: 3,
                      style: TextStyle(color: palette.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Lý do',
                        hintStyle: TextStyle(color: palette.textHint),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: palette.surfaceVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: palette.primary),
                        ),
                        filled: true,
                        fillColor: palette.card,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => _submit(asDraft: true),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: palette.primaryDark),
                              foregroundColor: palette.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Lưu nháp',
                              style: TextStyle(color: palette.primary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : () => _submit(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: palette.primary,
                              foregroundColor: palette.background,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Gửi duyệt'),
                          ),
                        ),
                      ],
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

  Widget _dateTile(String label, DateTime date, VoidCallback onTap) {
    final palette = context.appPalette;
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: palette.textSecondary),
          filled: true,
          fillColor: palette.card,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: palette.surfaceVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: palette.primary),
          ),
        ),
        child: Text(
          '${date.day}/${date.month}/${date.year}',
          style: TextStyle(color: palette.textPrimary),
        ),
      ),
    );
  }

  Widget _timeTile(String label, TimeOfDay time, VoidCallback onTap) {
    final palette = context.appPalette;
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: palette.textSecondary),
          filled: true,
          fillColor: palette.card,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: palette.surfaceVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: palette.primary),
          ),
        ),
        child: Text(
          _formatTime(time),
          style: TextStyle(color: palette.textPrimary),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) => date.toIso8601String().substring(0, 10);

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

DateTime combineDateAndTime(DateTime date, TimeOfDay time) => DateTime(
  date.year,
  date.month,
  date.day,
  time.hour,
  time.minute,
);

class LeaveBalanceInfoCard extends StatelessWidget {
  const LeaveBalanceInfoCard({
    super.key,
    required this.balanceAsync,
    required this.palette,
  });

  final AsyncValue<LeaveBalance> balanceAsync;
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
                'Đang tải số phép có lương còn lại...',
                style: TextStyle(color: palette.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
        error: (error, _) => Text(
          'Không tải được số phép có lương còn lại.',
          style: TextStyle(color: palette.textSecondary, fontSize: 12),
        ),
        data: (balance) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Phép năm ${balance.year}',
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              buildLeaveBalanceMessage(balance),
              style: TextStyle(color: palette.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _balanceChip(
                  'Được cấp: ${formatLeaveBalanceDays(balance.allocatedDays)} ngày',
                ),
                _balanceChip(
                  'Đã dùng: ${formatLeaveBalanceDays(balance.usedPaidDays)} ngày',
                ),
                _balanceChip(
                  'Còn lại: ${formatLeaveBalanceDays(balance.remainingPaidDays)} ngày',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceChip(String text) {
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
}

class WfhBalanceInfoCard extends StatelessWidget {
  const WfhBalanceInfoCard({
    super.key,
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
        data: (balance) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quota WFH ${balance.year}',
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _balanceChip(
                  'Tổng: ${formatLeaveBalanceDays(balance.allocatedDays)} ngày',
                ),
                _balanceChip(
                  'Đã dùng: ${formatLeaveBalanceDays(balance.usedDays)} ngày',
                ),
                _balanceChip(
                  'Còn lại: ${formatLeaveBalanceDays(balance.remainingDays)} ngày',
                ),
              ],
            ),
            if (balance.isOverride) ...[
              const SizedBox(height: 10),
              Text(
                'Quota này đang dùng cấu hình riêng do admin thiết lập.',
                style: TextStyle(color: palette.textSecondary, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _balanceChip(String text) {
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
}

bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
