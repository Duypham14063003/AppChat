import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/hr_models.dart';
import '../providers/hr_providers.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../auth/providers/auth_notifier.dart';

final _timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

String normalizePayrollTimeValue(Object? raw, {String fallback = ''}) {
  final value = raw?.toString().trim() ?? '';
  if (value.isEmpty) return fallback;

  final parts = value.split(':');
  if (parts.length < 2) return fallback;

  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  if (hours == null || minutes == null) return fallback;
  if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) {
    return fallback;
  }

  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
}

String? validatePayrollTimeValue(String value, {required bool allowEmpty}) {
  final normalized = normalizePayrollTimeValue(value);
  if (normalized.isEmpty) {
    return allowEmpty ? null : 'Vui lòng chọn giờ';
  }
  if (!_timePattern.hasMatch(normalized)) {
    return 'Giờ phải đúng định dạng HH:mm';
  }
  return null;
}

TimeOfDay _timeOfDayFromValue(String value, {TimeOfDay? fallback}) {
  final normalized = normalizePayrollTimeValue(value);
  if (normalized.isEmpty) {
    return fallback ?? const TimeOfDay(hour: 8, minute: 0);
  }

  final parts = normalized.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

class PayrollConfigScreen extends ConsumerStatefulWidget {
  const PayrollConfigScreen({super.key});

  @override
  ConsumerState<PayrollConfigScreen> createState() =>
      _PayrollConfigScreenState();
}

class _PayrollConfigScreenState extends ConsumerState<PayrollConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _didRequestWfhAdminConfig = false;
  late TextEditingController _startDayCtrl;
  late TextEditingController _stdHoursCtrl;
  late TextEditingController _stdDaysCtrl;
  late TextEditingController _workStartCtrl;
  late TextEditingController _checkinReminderCtrl;
  late TextEditingController _checkoutReminderCtrl;
  late TextEditingController _autoCheckoutTimeCtrl;
  late TextEditingController _wfhYearCtrl;
  late TextEditingController _wfhDefaultDaysCtrl;
  late TextEditingController _wfhUserDaysCtrl;
  bool _autoCheckoutEnabled = false;
  bool _isWfhDefaultLoading = false;
  bool _isWfhDefaultSaving = false;
  bool _isWfhUserLoading = false;
  bool _isWfhUserSaving = false;
  WfhAdminConfig? _wfhAdminConfig;
  WfhBalance? _selectedUserWfhBalance;
  RewardAdminEmployee? _selectedWfhEmployee;

  @override
  void initState() {
    super.initState();
    _startDayCtrl = TextEditingController();
    _stdHoursCtrl = TextEditingController();
    _stdDaysCtrl = TextEditingController();
    _workStartCtrl = TextEditingController();
    _checkinReminderCtrl = TextEditingController();
    _checkoutReminderCtrl = TextEditingController();
    _autoCheckoutTimeCtrl = TextEditingController();
    _wfhYearCtrl = TextEditingController(text: DateTime.now().year.toString());
    _wfhDefaultDaysCtrl = TextEditingController();
    _wfhUserDaysCtrl = TextEditingController();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await ref.read(payrollConfigProvider.future);
      setState(() {
        _startDayCtrl.text = config['payroll_start_day']?.toString() ?? '1';
        _stdHoursCtrl.text =
            config['standard_hours_per_day']?.toString() ?? '8';
        _stdDaysCtrl.text =
            config['standard_days_per_month']?.toString() ?? '22';
        _workStartCtrl.text = normalizePayrollTimeValue(
          config['work_start_time'],
          fallback: '08:00',
        );
        _checkinReminderCtrl.text = normalizePayrollTimeValue(
          config['checkin_reminder_time'],
        );
        _checkoutReminderCtrl.text = normalizePayrollTimeValue(
          config['checkout_reminder_time'],
        );
        _autoCheckoutEnabled = config['auto_checkout_enabled'] == true;
        _autoCheckoutTimeCtrl.text = normalizePayrollTimeValue(
          config['auto_checkout_time'],
          fallback: '23:59',
        );
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(hrRepositoryProvider);
      final workStartTime = normalizePayrollTimeValue(
        _workStartCtrl.text,
        fallback: '08:00',
      );
      final checkinReminder = normalizePayrollTimeValue(
        _checkinReminderCtrl.text,
      );
      final checkoutReminder = normalizePayrollTimeValue(
        _checkoutReminderCtrl.text,
      );
      final autoCheckoutTime = normalizePayrollTimeValue(
        _autoCheckoutTimeCtrl.text,
        fallback: '23:59',
      );
      await repo.updateConfig({
        'payroll_start_day': int.tryParse(_startDayCtrl.text),
        'standard_hours_per_day': double.tryParse(_stdHoursCtrl.text),
        'standard_days_per_month': int.tryParse(_stdDaysCtrl.text),
        'work_start_time': workStartTime,
        'checkin_reminder_time': checkinReminder.isEmpty
            ? null
            : checkinReminder,
        'checkout_reminder_time': checkoutReminder.isEmpty
            ? null
            : checkoutReminder,
        'auto_checkout_enabled': _autoCheckoutEnabled,
        'auto_checkout_time': autoCheckoutTime,
      });
      _workStartCtrl.text = workStartTime;
      _checkinReminderCtrl.text = checkinReminder;
      _checkoutReminderCtrl.text = checkoutReminder;
      _autoCheckoutTimeCtrl.text = autoCheckoutTime;
      ref.invalidate(payrollConfigProvider);
      if (mounted) {
        showTopSnackBar(context, message: 'Đã lưu cấu hình');
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, message: 'Lỗi: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _selectedWfhYear() =>
      int.tryParse(_wfhYearCtrl.text.trim()) ?? DateTime.now().year;

  Future<void> _loadWfhAdminConfig() async {
    setState(() => _isWfhDefaultLoading = true);
    try {
      final config = await ref.read(hrRepositoryProvider).getAdminWfhConfig(
            year: _selectedWfhYear(),
          );
      if (!mounted) return;
      setState(() {
        _wfhAdminConfig = config;
        _wfhDefaultDaysCtrl.text = config.allocatedDays.toStringAsFixed(
          config.allocatedDays == config.allocatedDays.roundToDouble() ? 0 : 1,
        );
      });
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, message: 'Không tải được quota WFH: $e');
      }
    } finally {
      if (mounted) setState(() => _isWfhDefaultLoading = false);
    }
  }

  Future<void> _saveWfhAdminConfig() async {
    final allocatedDays = double.tryParse(_wfhDefaultDaysCtrl.text.trim());
    if (allocatedDays == null) {
      showTopSnackBar(context, message: 'Quota WFH mặc định không hợp lệ');
      return;
    }

    setState(() => _isWfhDefaultSaving = true);
    try {
      final config = await ref.read(hrRepositoryProvider).updateAdminWfhConfig(
            year: _selectedWfhYear(),
            allocatedDays: allocatedDays,
          );
      if (!mounted) return;
      setState(() => _wfhAdminConfig = config);
      showTopSnackBar(context, message: 'Đã lưu quota WFH mặc định');
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, message: 'Lưu quota WFH thất bại: $e');
      }
    } finally {
      if (mounted) setState(() => _isWfhDefaultSaving = false);
    }
  }

  Future<void> _loadSelectedUserWfhBalance() async {
    final employee = _selectedWfhEmployee;
    if (employee == null) {
      showTopSnackBar(context, message: 'Vui lòng chọn nhân viên');
      return;
    }

    setState(() => _isWfhUserLoading = true);
    try {
      final balance =
          await ref.read(hrRepositoryProvider).getAdminUserWfhBalance(
                userId: employee.id,
                year: _selectedWfhYear(),
              );
      if (!mounted) return;
      setState(() {
        _selectedUserWfhBalance = balance;
        _wfhUserDaysCtrl.text = balance.allocatedDays.toStringAsFixed(
          balance.allocatedDays == balance.allocatedDays.roundToDouble()
              ? 0
              : 1,
        );
      });
    } catch (e) {
      if (mounted) {
        showTopSnackBar(
          context,
          message: 'Không tải được quota WFH nhân viên: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isWfhUserLoading = false);
    }
  }

  Future<void> _saveSelectedUserWfhBalance() async {
    final employee = _selectedWfhEmployee;
    if (employee == null) {
      showTopSnackBar(context, message: 'Vui lòng chọn nhân viên');
      return;
    }

    final allocatedDays = double.tryParse(_wfhUserDaysCtrl.text.trim());
    if (allocatedDays == null) {
      showTopSnackBar(context, message: 'Quota WFH nhân viên không hợp lệ');
      return;
    }

    setState(() => _isWfhUserSaving = true);
    try {
      final balance =
          await ref.read(hrRepositoryProvider).updateAdminUserWfhBalance(
                userId: employee.id,
                year: _selectedWfhYear(),
                allocatedDays: allocatedDays,
              );
      if (!mounted) return;
      setState(() => _selectedUserWfhBalance = balance);
      showTopSnackBar(context, message: 'Đã lưu quota WFH cho nhân viên');
    } catch (e) {
      if (mounted) {
        showTopSnackBar(
          context,
          message: 'Lưu quota WFH nhân viên thất bại: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isWfhUserSaving = false);
    }
  }

  @override
  void dispose() {
    _startDayCtrl.dispose();
    _stdHoursCtrl.dispose();
    _stdDaysCtrl.dispose();
    _workStartCtrl.dispose();
    _checkinReminderCtrl.dispose();
    _checkoutReminderCtrl.dispose();
    _autoCheckoutTimeCtrl.dispose();
    _wfhYearCtrl.dispose();
    _wfhDefaultDaysCtrl.dispose();
    _wfhUserDaysCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final authState = ref.watch(authNotifierProvider);
    final roles = authState.valueOrNull?.user?.roles ?? [];
    final isAdmin = roles.contains('admin');
    final employeesAsync = isAdmin
        ? ref.watch(rewardAdminEmployeesProvider)
        : const AsyncValue<List<RewardAdminEmployee>>.data(
            <RewardAdminEmployee>[],
          );

    if (isAdmin &&
        !_didRequestWfhAdminConfig &&
        !_isWfhDefaultLoading &&
        _wfhAdminConfig == null) {
      _didRequestWfhAdminConfig = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadWfhAdminConfig();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: isAdmin
            ? const Text('Cấu hình lương')
            : const Text('Cài đặt nhắc nhở'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _save,
            icon: Icon(Icons.save, color: palette.primary),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (isAdmin) ...[
                  _field(
                    'Ngày bắt đầu kỳ lương',
                    _startDayCtrl,
                    palette,
                    keyboardType: TextInputType.number,
                  ),
                  _field(
                    'Giờ chuẩn/ngày',
                    _stdHoursCtrl,
                    palette,
                    keyboardType: TextInputType.number,
                  ),
                  _field(
                    'Ngày công chuẩn/tháng',
                    _stdDaysCtrl,
                    palette,
                    keyboardType: TextInputType.number,
                  ),
                  _timeField(
                    label: 'Giờ bắt đầu ca (HH:mm)',
                    ctrl: _workStartCtrl,
                    palette: palette,
                    onTap: () => _pickTimeForController(_workStartCtrl),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: palette.primary.withValues(alpha: 0.05),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: palette.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(Icons.stars_rounded, color: palette.primary),
                      title: Text(
                        'Cấu hình Điểm Thưởng / Hệ Số Nhân',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Chỉnh hệ số nhân role hoặc điểm gốc cho tag Odoo',
                        style: TextStyle(color: palette.textSecondary, fontSize: 12),
                      ),
                      trailing: Icon(Icons.chevron_right, color: palette.primary),
                      onTap: () => context.push('/rewards/admin/configs'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildWfhAdminSection(palette, employeesAsync),
                  const SizedBox(height: 16),
                  Divider(color: palette.surfaceVariant, height: 32),
                ],
                Text(
                  'NHẮC NHỞ',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _timeField(
                  label: 'Nhắc checkin (HH:mm, để trống = tắt)',
                  ctrl: _checkinReminderCtrl,
                  palette: palette,
                  onTap: () => _pickTimeForController(_checkinReminderCtrl),
                  allowEmpty: true,
                  onClear: () => setState(() => _checkinReminderCtrl.clear()),
                ),
                _timeField(
                  label: 'Nhắc checkout (HH:mm, để trống = tắt)',
                  ctrl: _checkoutReminderCtrl,
                  palette: palette,
                  onTap: () => _pickTimeForController(_checkoutReminderCtrl),
                  allowEmpty: true,
                  onClear: () => setState(() => _checkoutReminderCtrl.clear()),
                ),
                SwitchListTile(
                  title: Text(
                    'Tự động checkout',
                    style: TextStyle(color: palette.textPrimary),
                  ),
                  value: _autoCheckoutEnabled,
                  activeThumbColor: palette.primary,
                  onChanged: (v) => setState(() => _autoCheckoutEnabled = v),
                ),
                if (_autoCheckoutEnabled)
                  _timeField(
                    label: 'Giờ auto-checkout (HH:mm)',
                    ctrl: _autoCheckoutTimeCtrl,
                    palette: palette,
                    onTap: () => _pickTimeForController(
                      _autoCheckoutTimeCtrl,
                      fallback: const TimeOfDay(hour: 23, minute: 59),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickTimeForController(
    TextEditingController ctrl, {
    TimeOfDay? fallback,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeOfDayFromValue(ctrl.text, fallback: fallback),
    );
    if (picked == null) return;

    setState(() {
      ctrl.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    });
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    AppThemePalette palette, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        cursorColor: palette.primary,
        style: TextStyle(color: palette.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: palette.textSecondary),
          floatingLabelStyle: TextStyle(color: palette.primary),
        ),
      ),
    );
  }

  Widget _timeField({
    required String label,
    required TextEditingController ctrl,
    required AppThemePalette palette,
    required VoidCallback onTap,
    bool allowEmpty = false,
    VoidCallback? onClear,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        readOnly: true,
        onTap: onTap,
        cursorColor: palette.primary,
        style: TextStyle(color: palette.textPrimary),
        validator: (value) =>
            validatePayrollTimeValue(value ?? '', allowEmpty: allowEmpty),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: palette.textSecondary),
          floatingLabelStyle: TextStyle(color: palette.primary),
          suffixIcon: onClear != null && ctrl.text.isNotEmpty
              ? IconButton(
                  onPressed: onClear,
                  icon: Icon(Icons.close, color: palette.textSecondary),
                )
              : const Icon(Icons.access_time),
        ),
      ),
    );
  }

  Widget _buildWfhAdminSection(
    AppThemePalette palette,
    AsyncValue<List<RewardAdminEmployee>> employeesAsync,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.home_work_outlined, color: palette.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cấu hình quota WFH',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Thiết lập quota mặc định theo năm và override riêng cho từng nhân viên.',
            style: TextStyle(color: palette.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _field(
                  'Năm áp dụng',
                  _wfhYearCtrl,
                  palette,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: _isWfhDefaultLoading || _isWfhUserLoading
                    ? null
                    : () async {
                        await _loadWfhAdminConfig();
                        if (_selectedWfhEmployee != null) {
                          await _loadSelectedUserWfhBalance();
                        }
                      },
                icon: const Icon(Icons.refresh),
                label: const Text('Tải'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Quota mặc định toàn công ty',
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(
                  'Số ngày mặc định',
                  _wfhDefaultDaysCtrl,
                  palette,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _isWfhDefaultSaving ? null : _saveWfhAdminConfig,
                child: _isWfhDefaultSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Lưu'),
              ),
            ],
          ),
          if (_wfhAdminConfig != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _wfhInfoChip(
                  palette,
                  'Năm ${_wfhAdminConfig!.year}',
                  palette.primary,
                ),
                _wfhInfoChip(
                  palette,
                  '${_formatWfhDays(_wfhAdminConfig!.allocatedDays)} ngày mặc định',
                  palette.textPrimary,
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Override theo nhân viên',
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          employeesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text(
              'Không tải được danh sách nhân viên.',
              style: TextStyle(color: palette.textSecondary, fontSize: 12),
            ),
            data: (employees) => DropdownButtonFormField<String>(
              initialValue: _selectedWfhEmployee?.id,
              dropdownColor: palette.card,
              decoration: InputDecoration(
                labelText: 'Nhân viên',
                labelStyle: TextStyle(color: palette.textSecondary),
              ),
              items: employees
                  .map(
                    (employee) => DropdownMenuItem<String>(
                      value: employee.id,
                      child: Text(employee.name),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) return;
                final next = employees.cast<RewardAdminEmployee?>().firstWhere(
                      (employee) => employee?.id == value,
                      orElse: () => null,
                    );
                setState(() {
                  _selectedWfhEmployee = next;
                  _selectedUserWfhBalance = null;
                  _wfhUserDaysCtrl.clear();
                });
                if (next != null) {
                  _loadSelectedUserWfhBalance();
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(
                  'Số ngày riêng',
                  _wfhUserDaysCtrl,
                  palette,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _isWfhUserSaving ? null : _saveSelectedUserWfhBalance,
                child: _isWfhUserSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Lưu'),
              ),
            ],
          ),
          if (_isWfhUserLoading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
          if (_selectedUserWfhBalance != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _wfhInfoChip(
                  palette,
                  'Đã dùng ${_formatWfhDays(_selectedUserWfhBalance!.usedDays)} ngày',
                  palette.textPrimary,
                ),
                _wfhInfoChip(
                  palette,
                  'Còn lại ${_formatWfhDays(_selectedUserWfhBalance!.remainingDays)} ngày',
                  palette.primary,
                ),
                _wfhInfoChip(
                  palette,
                  _selectedUserWfhBalance!.isOverride
                      ? 'Đang override riêng'
                      : 'Đang dùng quota mặc định',
                  _selectedUserWfhBalance!.isOverride
                      ? palette.primary
                      : palette.textSecondary,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _wfhInfoChip(
    AppThemePalette palette,
    String text,
    Color color,
  ) {
    final foreground = color == palette.textPrimary
        ? palette.textPrimary
        : color == palette.textSecondary
            ? palette.textSecondary
            : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatWfhDays(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}
