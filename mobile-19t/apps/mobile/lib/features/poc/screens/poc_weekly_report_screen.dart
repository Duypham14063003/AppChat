import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../models/poc_models.dart';
import '../providers/poc_providers.dart';
import '../widgets/poc_widgets.dart';

class PocWeeklyReportScreen extends ConsumerStatefulWidget {
  const PocWeeklyReportScreen({super.key, this.initialWeek});
  final DateTime? initialWeek;
  @override
  ConsumerState<PocWeeklyReportScreen> createState() =>
      _PocWeeklyReportScreenState();
}

class _PocWeeklyReportScreenState extends ConsumerState<PocWeeklyReportScreen> {
  late DateTime _week = widget.initialWeek ?? DateTime.now();
  bool _publishing = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pocWeeklyReportProvider(_week));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo PoC tuần'),
        actions: [
          IconButton(
            tooltip: 'Tuần trước',
            onPressed: () =>
                setState(() => _week = _week.subtract(const Duration(days: 7))),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Tuần sau',
            onPressed: () =>
                setState(() => _week = _week.add(const Duration(days: 7))),
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            tooltip: 'Cập nhật thông báo nhóm',
            onPressed: _publishing ? null : _publish,
            icon: _publishing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.publish_outlined),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: OutlinedButton.icon(
            onPressed: () => ref.invalidate(pocWeeklyReportProvider(_week)),
            icon: const Icon(Icons.refresh),
            label: Text('Không tải được báo cáo: $error'),
          ),
        ),
        data: (report) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(pocWeeklyReportProvider(_week));
            await ref.read(pocWeeklyReportProvider(_week).future);
          },
          child: _ReportBody(report: report),
        ),
      ),
    );
  }

  Future<void> _publish() async {
    setState(() => _publishing = true);
    try {
      await ref.read(pocRepositoryProvider).publishWeeklyReport(_week);
      ref.invalidate(pocWeeklyReportProvider(_week));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật thông báo PoC tuần trong nhóm tổng hợp'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể phát hành báo cáo: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});
  final PocWeeklyReport report;
  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
      children: [
        Text(
          'Tuần ${report.isoWeek}/${report.isoYear}',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          '${report.weekStart} - ${report.weekEnd}',
          style: TextStyle(color: palette.textSecondary),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _CountTile(
              label: 'Tổng',
              value: report.total,
              color: palette.primary,
            ),
            ...report.counts.entries.map(
              (item) => _CountTile(
                label: pocStatusLabel(item.key),
                value: item.value,
                color: _statusColor(item.key, palette),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _Header(title: 'Lịch demo', count: report.demos.length),
        if (report.demos.isEmpty)
          const _EmptyLine(text: 'Không có lịch demo trong tuần')
        else
          ...report.demos.map((item) => _DemoTile(item: item)),
        const SizedBox(height: 20),
        _Header(
          title: 'Quá hạn',
          count: report.overdue.length,
          danger: report.overdue.isNotEmpty,
        ),
        if (report.overdue.isEmpty)
          const _EmptyLine(text: 'Không có PoC quá hạn')
        else
          ...report.overdue.map((item) => _DemoTile(item: item, overdue: true)),
        const SizedBox(height: 20),
        _Header(title: 'Năng lực Dev', count: report.capacity.length),
        ...report.capacity.map((item) {
          final allocated = _number(item['allocated_hours']);
          final capacity = _number(item['capacity_hours']);
          final overloaded = item['over_capacity'] == true;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.engineering_outlined,
              color: overloaded ? AppColors.danger : AppColors.info,
            ),
            title: Text('${item['name'] ?? 'Developer'}'),
            subtitle: LinearProgressIndicator(
              value: capacity == 0 ? 0 : (allocated / capacity).clamp(0, 1),
              color: overloaded ? AppColors.danger : AppColors.info,
              backgroundColor: palette.surfaceVariant,
            ),
            trailing: Text(
              '${allocated.toStringAsFixed(1)}/${capacity.toStringAsFixed(0)}h',
              style: TextStyle(
                color: overloaded ? AppColors.danger : palette.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 135,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.count,
    this.danger = false,
  });
  final String title;
  final int count;
  final bool danger;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: danger ? AppColors.danger : null,
            ),
          ),
        ),
        Text('$count'),
      ],
    ),
  );
}

class _DemoTile extends StatelessWidget {
  const _DemoTile({required this.item, this.overdue = false});
  final Map<String, dynamic> item;
  final bool overdue;
  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse('${item['demo_at'] ?? ''}')?.toLocal();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        overdue ? Icons.warning_amber_rounded : Icons.event_outlined,
        color: overdue ? AppColors.danger : AppColors.info,
      ),
      title: Text(
        '${item['code'] ?? 'Chưa có mã'} · ${item['title'] ?? ''}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${item['customer_name'] ?? ''} · ${item['developer_name'] ?? 'Chưa có Dev'}\n${date == null ? '' : DateFormat('HH:mm, dd/MM').format(date)}',
      ),
      trailing: IconButton(
        tooltip: 'Mở PoC',
        icon: const Icon(Icons.chevron_right),
        onPressed: () => context.push('/pocs/${item['id']}'),
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text(
      text,
      style: TextStyle(color: context.appPalette.textSecondary),
    ),
  );
}

double _number(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
Color _statusColor(String status, AppThemePalette palette) => switch (status) {
  'unassigned' => AppColors.warning,
  'ready' => AppColors.online,
  'cancelled' => palette.textHint,
  'demonstrated' => palette.primary,
  _ => AppColors.info,
};
