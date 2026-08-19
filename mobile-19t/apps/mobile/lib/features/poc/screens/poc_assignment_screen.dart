import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../../chat/data/user_repository.dart';
import '../../chat/providers/chat_providers.dart';
import '../models/poc_models.dart';
import '../providers/poc_providers.dart';

class PocAssignmentScreen extends ConsumerStatefulWidget {
  const PocAssignmentScreen({super.key, required this.pocId});
  final String pocId;

  @override
  ConsumerState<PocAssignmentScreen> createState() =>
      _PocAssignmentScreenState();
}

class _PocAssignmentScreenState extends ConsumerState<PocAssignmentScreen> {
  final _hours = TextEditingController(text: '8');
  final _search = TextEditingController();
  DateTime _plannedStart = DateTime.now();
  DateTime _demoAt = DateTime.now().add(const Duration(days: 3));
  String? _developerId;
  Future<List<UserContact>>? _usersFuture;
  bool _initialized = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _usersFuture = ref
        .read(userRepositoryProvider)
        .getUsers(limit: 100)
        .then((value) => value.users);
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _hours.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(pocDetailProvider(widget.pocId));
    return Scaffold(
      appBar: AppBar(title: const Text('Phân công PoC')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LoadError(
          message: '$error',
          onRetry: () => ref.invalidate(pocDetailProvider(widget.pocId)),
        ),
        data: (poc) {
          _initialize(poc);
          return FutureBuilder<List<UserContact>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _LoadError(
                  message: '${snapshot.error}',
                  onRetry: () => setState(() {
                    _usersFuture = ref
                        .read(userRepositoryProvider)
                        .getUsers(limit: 100)
                        .then((value) => value.users);
                  }),
                );
              }
              return _body(poc, snapshot.data ?? const []);
            },
          );
        },
      ),
    );
  }

  void _initialize(PocRecord poc) {
    if (_initialized) return;
    _initialized = true;
    _developerId = poc.developerUserId;
    _plannedStart = poc.plannedStartAt ?? DateTime.now();
    _demoAt = poc.demoAt;
    if (poc.estimatedHours != null) {
      _hours.text = poc.estimatedHours!.toStringAsFixed(1);
    }
  }

  Widget _body(PocRecord poc, List<UserContact> users) {
    final palette = context.appPalette;
    final estimate = double.tryParse(_hours.text.replaceAll(',', '.'));
    final canPreview =
        estimate != null && estimate > 0 && _plannedStart.isBefore(_demoAt);
    final preview = canPreview
        ? ref.watch(
            pocCapacityPreviewProvider((
              plannedStart: _plannedStart,
              demoAt: _demoAt,
              estimatedHours: estimate,
              excludePocId: poc.id,
            )),
          )
        : null;
    final normalizedSearch = _search.text.trim().toLowerCase();
    final visibleUsers = users
        .where(
          (user) =>
              normalizedSearch.isEmpty ||
              user.name.toLowerCase().contains(normalizedSearch) ||
              user.email.toLowerCase().contains(normalizedSearch),
        )
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          poc.code ?? poc.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: palette.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (poc.developerUser != null) ...[
          const SizedBox(height: 4),
          Text(
            'Dev hiện tại: ${poc.developerUser!.name}',
            style: TextStyle(color: palette.textSecondary),
          ),
        ],
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final fields = [
              _PlanDateField(
                label: 'Bắt đầu dự kiến',
                value: _plannedStart,
                onChanged: (value) => setState(() => _plannedStart = value),
              ),
              _PlanDateField(
                label: 'Lịch demo / hạn PoC',
                value: _demoAt,
                onChanged: (value) => setState(() => _demoAt = value),
              ),
              TextField(
                controller: _hours,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Số giờ dự kiến',
                  suffixText: 'giờ',
                  prefixIcon: Icon(Icons.schedule_outlined),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ];
            if (constraints.maxWidth < 720) {
              return Column(
                children: [
                  fields[0],
                  const SizedBox(height: 12),
                  fields[1],
                  const SizedBox(height: 12),
                  fields[2],
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: fields[0]),
                const SizedBox(width: 12),
                Expanded(child: fields[1]),
                const SizedBox(width: 12),
                Expanded(child: fields[2]),
              ],
            );
          },
        ),
        if (_plannedStart.compareTo(_demoAt) >= 0) ...[
          const SizedBox(height: 8),
          const Text(
            'Ngày bắt đầu phải trước lịch demo.',
            style: TextStyle(color: AppColors.danger),
          ),
        ],
        const SizedBox(height: 18),
        TextField(
          controller: _search,
          decoration: const InputDecoration(
            labelText: 'Tìm Dev',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 10),
        if (preview?.isLoading == true)
          const LinearProgressIndicator()
        else if (preview?.hasError == true)
          Text(
            'Không tải được dữ liệu năng lực: ${preview!.error}',
            style: const TextStyle(color: AppColors.danger),
          ),
        const SizedBox(height: 6),
        ...visibleUsers.map((user) {
          final capacity = preview?.valueOrNull?.developers
              .where((item) => item.userId == user.id)
              .firstOrNull;
          return _DeveloperChoice(
            user: user,
            capacity: capacity,
            selected: _developerId == user.id,
            onSelected: () => setState(() => _developerId = user.id),
          );
        }),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _saving || !canPreview || _developerId == null
              ? null
              : () => _submit(poc, preview?.valueOrNull),
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.person_add_alt_1_outlined),
          label: Text(
            poc.developerUserId == null ? 'Phân công' : 'Cập nhật phân công',
          ),
        ),
      ],
    );
  }

  Future<void> _submit(PocRecord poc, PocCapacityWeek? preview) async {
    final selected = preview?.developers
        .where((item) => item.userId == _developerId)
        .firstOrNull;
    if (selected?.overCapacity == true || selected?.hasOverlap == true) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Xác nhận cảnh báo tải'),
          content: Text(
            selected!.overCapacity
                ? 'Dev được chọn sẽ vượt 40 giờ trong tuần. Vẫn tiếp tục phân công?'
                : 'Dev được chọn có lịch PoC trùng nhau. Vẫn tiếp tục phân công?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Xem lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Vẫn phân công'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(pocRepositoryProvider).assign(poc.id, {
        'version': poc.version,
        'developer_user_id': _developerId,
        'planned_start_at': _plannedStart.toUtc().toIso8601String(),
        'estimated_hours': double.parse(_hours.text.replaceAll(',', '.')),
        'demo_at': _demoAt.toUtc().toIso8601String(),
      });
      invalidatePocData(ref, poc.id);
      if (mounted) context.pop();
    } on PocConflict catch (conflict) {
      if (mounted) await _showConflict(conflict);
    } catch (error) {
      if (mounted) _message('Không thể phân công: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showConflict(PocConflict conflict) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PoC đã được cập nhật'),
        content: Text(
          '${conflict.message}\n\nBản nháp của bạn vẫn được giữ. Hãy xem dữ liệu mới rồi xác nhận lại.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.invalidate(pocDetailProvider(widget.pocId));
            },
            child: const Text('Tải dữ liệu mới'),
          ),
        ],
      ),
    );
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

class _DeveloperChoice extends StatelessWidget {
  const _DeveloperChoice({
    required this.user,
    required this.capacity,
    required this.selected,
    required this.onSelected,
  });
  final UserContact user;
  final PocCapacityDeveloper? capacity;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final warning =
        capacity?.overCapacity == true || capacity?.hasOverlap == true;
    final projected = capacity?.projectedHours ?? capacity?.allocatedHours;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? palette.primary : palette.surfaceVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        onTap: onSelected,
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: selected ? palette.primary : palette.textSecondary,
        ),
        title: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          capacity == null
              ? user.email
              : '${capacity!.allocatedHours.toStringAsFixed(1)} → ${projected!.toStringAsFixed(1)} / ${capacity!.capacityHours.toStringAsFixed(0)} giờ',
        ),
        trailing: warning
            ? const Tooltip(
                message: 'Trùng lịch hoặc vượt tải',
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                ),
              )
            : const Icon(Icons.check_circle_outline, color: AppColors.online),
      ),
    );
  }
}

class _PlanDateField extends StatelessWidget {
  const _PlanDateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () async {
      final date = await showDatePicker(
        context: context,
        initialDate: value,
        firstDate: DateTime.now().subtract(const Duration(days: 30)),
        lastDate: DateTime.now().add(const Duration(days: 730)),
      );
      if (date == null || !context.mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(value),
      );
      if (time != null) {
        onChanged(
          DateTime(date.year, date.month, date.day, time.hour, time.minute),
        );
      }
    },
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.event_outlined),
      ),
      child: Text(DateFormat('HH:mm, dd/MM/yyyy').format(value)),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Thử lại'),
        ),
      ],
    ),
  );
}
