import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../models/poc_models.dart';
import '../providers/poc_providers.dart';
import '../widgets/poc_widgets.dart';

class PocDetailScreen extends ConsumerWidget {
  const PocDetailScreen({super.key, required this.pocId});
  final String pocId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pocDetailProvider(pocId));
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết PoC')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: OutlinedButton.icon(
            onPressed: () => ref.invalidate(pocDetailProvider(pocId)),
            icon: const Icon(Icons.refresh),
            label: Text('Không tải được PoC: $error'),
          ),
        ),
        data: (poc) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(pocDetailProvider(pocId));
            await ref.read(pocDetailProvider(pocId).future);
          },
          child: _PocDetailContent(poc: poc),
        ),
      ),
    );
  }
}

class _PocDetailContent extends ConsumerWidget {
  const _PocDetailContent({required this.poc});
  final PocRecord poc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appPalette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    poc.code ?? 'Chưa phân công',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${poc.customerName} · ${poc.title}',
                    style: TextStyle(color: palette.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            PocStatusBadge(poc: poc),
          ],
        ),
        if (poc.overdue || poc.demoSoon) ...[
          const SizedBox(height: 12),
          _AttentionBanner(poc: poc),
        ],
        const SizedBox(height: 20),
        _LifecycleProgress(status: poc.status),
        const SizedBox(height: 20),
        _Section(
          title: 'Yêu cầu',
          child: Text(
            poc.requirement,
            style: TextStyle(color: palette.textPrimary),
          ),
        ),
        _Section(
          title: 'Kế hoạch',
          child: LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 18,
              runSpacing: 14,
              children: [
                _DetailValue(
                  icon: Icons.person_outline,
                  label: 'Sale',
                  value: poc.saleUser?.name ?? 'Chưa rõ',
                ),
                _DetailValue(
                  icon: Icons.engineering_outlined,
                  label: 'Dev chính',
                  value: poc.developerUser?.name ?? 'Chưa phân công',
                ),
                _DetailValue(
                  icon: Icons.play_circle_outline,
                  label: 'Bắt đầu',
                  value: _formatDate(poc.plannedStartAt),
                ),
                _DetailValue(
                  icon: Icons.schedule_outlined,
                  label: 'Ước tính',
                  value: poc.estimatedHours == null
                      ? 'Chưa có'
                      : '${poc.estimatedHours!.toStringAsFixed(1)} giờ',
                ),
                _DetailValue(
                  icon: Icons.event_outlined,
                  label: 'Demo / hạn PoC',
                  value: _formatDate(poc.demoAt),
                ),
                _DetailValue(
                  icon: Icons.category_outlined,
                  label: 'Loại',
                  value: pocProductLabel(poc.productType),
                ),
              ],
            ),
          ),
        ),
        if (poc.outcome != null)
          _Section(
            title: 'Kết quả demo',
            child: Text(_outcomeLabel(poc.outcome!)),
          ),
        if (poc.pocUrl != null || poc.referenceLinks.isNotEmpty)
          _Section(
            title: 'Liên kết',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (poc.pocUrl != null)
                  ActionChip(
                    avatar: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Mở bản PoC'),
                    onPressed: () => launchUrl(Uri.parse(poc.pocUrl!)),
                  ),
                ...poc.referenceLinks.indexed.map(
                  (item) => ActionChip(
                    avatar: const Icon(Icons.link, size: 16),
                    label: Text('Tài liệu ${item.$1 + 1}'),
                    onPressed: () => launchUrl(Uri.parse(item.$2)),
                  ),
                ),
              ],
            ),
          ),
        _Section(
          title: 'Thao tác',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _actions(context, ref),
          ),
        ),
        _Section(
          title: 'Lịch sử',
          child: poc.history.isEmpty
              ? Text(
                  'Chưa có lịch sử',
                  style: TextStyle(color: palette.textSecondary),
                )
              : Column(
                  children: poc.history
                      .map((event) => _HistoryTile(event: event))
                      .toList(growable: false),
                ),
        ),
      ],
    );
  }

  List<Widget> _actions(BuildContext context, WidgetRef ref) {
    final actions = <Widget>[];
    if (!['demonstrated', 'cancelled'].contains(poc.status)) {
      actions.add(
        FilledButton.tonalIcon(
          onPressed: () => context.push('/pocs/${poc.id}/assign'),
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: Text(
            poc.developerUserId == null ? 'Phân công' : 'Đổi phân công',
          ),
        ),
      );
      actions.add(
        OutlinedButton.icon(
          onPressed: () => _updateLink(context, ref),
          icon: const Icon(Icons.link_outlined),
          label: const Text('Cập nhật link'),
        ),
      );
    }
    if (poc.status == 'assigned') {
      actions.add(
        _statusButton(context, ref, 'in_progress', 'Bắt đầu', Icons.play_arrow),
      );
    }
    if (poc.status == 'in_progress') {
      actions.add(
        _statusButton(
          context,
          ref,
          'ready',
          'Đánh dấu sẵn sàng',
          Icons.check_circle_outline,
        ),
      );
    }
    if (poc.status == 'ready') {
      actions.add(
        FilledButton.icon(
          onPressed: () => _recordDemo(context, ref),
          icon: const Icon(Icons.present_to_all_outlined),
          label: const Text('Ghi nhận demo'),
        ),
      );
    }
    if (!['demonstrated', 'cancelled'].contains(poc.status)) {
      actions.add(
        OutlinedButton.icon(
          onPressed: () => _cancel(context, ref),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Hủy PoC'),
        ),
      );
    }
    if (poc.workingConversationId != null) {
      actions.add(
        OutlinedButton.icon(
          onPressed: () => context.push('/chat/${poc.workingConversationId}'),
          icon: const Icon(Icons.forum_outlined),
          label: const Text('Mở chat'),
        ),
      );
    }
    return actions;
  }

  Widget _statusButton(
    BuildContext context,
    WidgetRef ref,
    String status,
    String label,
    IconData icon,
  ) => FilledButton.icon(
    onPressed: () =>
        _transition(context, ref, {'version': poc.version, 'status': status}),
    icon: Icon(icon),
    label: Text(label),
  );

  Future<void> _transition(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> data,
  ) async {
    try {
      await ref.read(pocRepositoryProvider).transition(poc.id, data);
      invalidatePocData(ref, poc.id);
    } on PocConflict catch (conflict) {
      if (context.mounted) await _conflictDialog(context, ref, conflict);
    } catch (error) {
      if (context.mounted) _message(context, 'Không thể cập nhật: $error');
    }
  }

  Future<void> _recordDemo(BuildContext context, WidgetRef ref) async {
    final outcome = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Kết quả demo'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'completed'),
            child: const Text('Hoàn tất'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'revision_required'),
            child: const Text('Cần chỉnh sửa'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'not_proceeding'),
            child: const Text('Không tiếp tục'),
          ),
        ],
      ),
    );
    if (outcome == null || !context.mounted) return;
    if (outcome == 'revision_required') {
      final plan = await showDialog<_RevisionPlan>(
        context: context,
        builder: (context) => _RevisionDialog(poc: poc),
      );
      if (plan == null || !context.mounted) return;
      await _transition(context, ref, {
        'version': poc.version,
        'status': 'demonstrated',
        'outcome': outcome,
        'planned_start_at': plan.start.toUtc().toIso8601String(),
        'demo_at': plan.demo.toUtc().toIso8601String(),
        'estimated_hours': plan.hours,
      });
      return;
    }
    await _transition(context, ref, {
      'version': poc.version,
      'status': 'demonstrated',
      'outcome': outcome,
    });
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy PoC'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Lý do hủy'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty || !context.mounted) return;
    await _transition(context, ref, {
      'version': poc.version,
      'status': 'cancelled',
      'cancel_reason': reason,
    });
  }

  Future<void> _updateLink(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: poc.pocUrl ?? '');
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Link bản PoC'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'URL',
            hintText: 'https://...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              final uri = Uri.tryParse(value);
              if (value.isEmpty ||
                  uri == null ||
                  !uri.hasScheme ||
                  !uri.hasAuthority) {
                return;
              }
              Navigator.pop(context, value);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (url == null || !context.mounted) return;
    try {
      await ref.read(pocRepositoryProvider).updatePlan(poc.id, {
        'version': poc.version,
        'poc_url': url,
      });
      invalidatePocData(ref, poc.id);
    } on PocConflict catch (conflict) {
      if (context.mounted) await _conflictDialog(context, ref, conflict);
    } catch (error) {
      if (context.mounted) _message(context, 'Không thể cập nhật link: $error');
    }
  }

  Future<void> _conflictDialog(
    BuildContext context,
    WidgetRef ref,
    PocConflict conflict,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dữ liệu đã thay đổi'),
        content: Text(
          '${conflict.message}\nVui lòng xem bản mới trước khi thao tác lại.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tải lại'),
          ),
        ],
      ),
    );
    ref.invalidate(pocDetailProvider(poc.id));
  }

  void _message(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _DetailValue extends StatelessWidget {
  const _DetailValue({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return SizedBox(
      width: 210,
      child: Row(
        children: [
          Icon(icon, size: 18, color: palette.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: palette.textSecondary, fontSize: 11),
                ),
                Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionBanner extends StatelessWidget {
  const _AttentionBanner({required this.poc});
  final PocRecord poc;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: (poc.overdue ? AppColors.danger : AppColors.warning).withValues(
        alpha: 0.1,
      ),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      children: [
        Icon(
          Icons.warning_amber_rounded,
          color: poc.overdue ? AppColors.danger : AppColors.warning,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            poc.overdue
                ? 'PoC đã quá lịch demo.'
                : 'Lịch demo diễn ra trong 24 giờ tới.',
          ),
        ),
      ],
    ),
  );
}

class _LifecycleProgress extends StatelessWidget {
  const _LifecycleProgress({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    const steps = [
      'unassigned',
      'assigned',
      'in_progress',
      'ready',
      'demonstrated',
    ];
    final current = steps.indexOf(status);
    return Row(
      children: steps.indexed
          .map((entry) {
            final active = current >= entry.$1;
            return Expanded(
              child: Column(
                children: [
                  Icon(
                    active ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 20,
                    color: active
                        ? AppColors.online
                        : context.appPalette.textHint,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pocStatusLabel(entry.$2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.event});
  final PocHistoryEvent event;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    leading: const Icon(Icons.history, size: 20),
    title: Text(_historyLabel(event.eventType)),
    subtitle: Text(
      '${event.actorName ?? 'Hệ thống'} · ${_formatDate(event.createdAt)}',
    ),
  );
}

class _RevisionPlan {
  const _RevisionPlan(this.start, this.demo, this.hours);
  final DateTime start;
  final DateTime demo;
  final double hours;
}

class _RevisionDialog extends StatefulWidget {
  const _RevisionDialog({required this.poc});
  final PocRecord poc;
  @override
  State<_RevisionDialog> createState() => _RevisionDialogState();
}

class _RevisionDialogState extends State<_RevisionDialog> {
  late DateTime start = DateTime.now();
  late DateTime demo = DateTime.now().add(const Duration(days: 2));
  late final hours = TextEditingController(
    text: (widget.poc.estimatedHours ?? 8).toStringAsFixed(1),
  );
  @override
  void dispose() {
    hours.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Kế hoạch chỉnh sửa'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DialogDate(
          label: 'Bắt đầu',
          value: start,
          onChanged: (value) => setState(() => start = value),
        ),
        const SizedBox(height: 10),
        _DialogDate(
          label: 'Demo mới',
          value: demo,
          onChanged: (value) => setState(() => demo = value),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: hours,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Số giờ chỉnh sửa'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
      FilledButton(
        onPressed: () {
          final value = double.tryParse(hours.text.replaceAll(',', '.'));
          if (value == null ||
              value <= 0 ||
              !demo.isAfter(start) ||
              !demo.isAfter(DateTime.now())) {
            return;
          }
          Navigator.pop(context, _RevisionPlan(start, demo, value));
        },
        child: const Text('Xác nhận'),
      ),
    ],
  );
}

class _DialogDate extends StatelessWidget {
  const _DialogDate({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(_formatDate(value)),
    trailing: const Icon(Icons.edit_calendar_outlined),
    onTap: () async {
      final date = await showDatePicker(
        context: context,
        initialDate: value,
        firstDate: DateTime.now(),
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
  );
}

String _formatDate(DateTime? value) =>
    value == null ? 'Chưa có' : DateFormat('HH:mm, dd/MM/yyyy').format(value);
String _outcomeLabel(String value) => switch (value) {
  'completed' => 'Hoàn tất',
  'revision_required' => 'Cần chỉnh sửa',
  'not_proceeding' => 'Không tiếp tục',
  _ => value,
};
String _historyLabel(String value) => switch (value) {
  'created' => 'Tạo yêu cầu PoC',
  'assigned' => 'Phân công Dev',
  'reassigned' => 'Đổi Dev phụ trách',
  'plan_updated' => 'Cập nhật kế hoạch',
  'status_in_progress' => 'Bắt đầu thực hiện',
  'status_ready' => 'Sẵn sàng demo',
  'status_demonstrated' => 'Ghi nhận demo',
  'revision_required' => 'Yêu cầu chỉnh sửa',
  'status_cancelled' => 'Hủy PoC',
  _ => value.replaceAll('_', ' '),
};
