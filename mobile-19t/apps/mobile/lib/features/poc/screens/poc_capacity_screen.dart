import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../../hr/data/hr_models.dart';
import '../models/poc_models.dart';
import '../providers/poc_providers.dart';

class PocCapacityScreen extends ConsumerStatefulWidget {
  const PocCapacityScreen({super.key, this.initialWeek});
  final DateTime? initialWeek;

  @override
  ConsumerState<PocCapacityScreen> createState() => _PocCapacityScreenState();
}

class _PocCapacityScreenState extends ConsumerState<PocCapacityScreen> {
  late DateTime _week = widget.initialWeek ?? DateTime.now();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pocCapacityProvider(_week));
    final approvedLeaves =
        ref.watch(pocApprovedLeavesProvider(_week)).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Năng lực PoC'),
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
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: OutlinedButton.icon(
            onPressed: () => ref.invalidate(pocCapacityProvider(_week)),
            icon: const Icon(Icons.refresh),
            label: Text('Không tải được năng lực: $error'),
          ),
        ),
        data: (capacity) => LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 768
              ? _WideCapacity(
                  capacity: capacity,
                  approvedLeaves: approvedLeaves,
                )
              : _NarrowCapacity(
                  capacity: capacity,
                  approvedLeaves: approvedLeaves,
                ),
        ),
      ),
    );
  }
}

class _WideCapacity extends StatelessWidget {
  const _WideCapacity({required this.capacity, required this.approvedLeaves});
  final PocCapacityWeek capacity;
  final List<LeaveRequest> approvedLeaves;

  @override
  Widget build(BuildContext context) {
    final dates = capacity.dates.take(5).toList(growable: false);
    return Column(
      children: [
        _WeekHeader(capacity: capacity),
        Container(
          height: 44,
          color: context.appPalette.surfaceVariant,
          child: Row(
            children: [
              const SizedBox(
                width: 220,
                child: Center(child: Text('Developer')),
              ),
              ...dates.map(
                (date) => Expanded(
                  child: Center(
                    child: Text(_dayLabel(date), textAlign: TextAlign.center),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: capacity.developers.isEmpty
              ? const Center(child: Text('Chưa có dữ liệu Dev'))
              : ListView.builder(
                  itemCount: capacity.developers.length,
                  itemExtent: 82,
                  itemBuilder: (context, index) {
                    final developer = capacity.developers[index];
                    final leaveCount = _leavesFor(
                      approvedLeaves,
                      developer.userId,
                    ).length;
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: context.appPalette.surfaceVariant,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 220,
                            child: _DeveloperSummary(
                              developer: developer,
                              leaveCount: leaveCount,
                            ),
                          ),
                          ...dates.map((date) {
                            final hours = developer.dailyLoad[date] ?? 0;
                            final overloaded = hours > 8;
                            final labels = _pocLabelsForDate(
                              developer.pocs,
                              date,
                            );
                            return Expanded(
                              child: Container(
                                height: double.infinity,
                                margin: const EdgeInsets.all(5),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color:
                                      (overloaded
                                              ? AppColors.danger
                                              : AppColors.info)
                                          .withValues(
                                            alpha: hours == 0 ? 0.03 : 0.1,
                                          ),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: overloaded
                                        ? AppColors.danger
                                        : context.appPalette.surfaceVariant,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      hours == 0
                                          ? '–'
                                          : '${hours.toStringAsFixed(1)}h',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: overloaded
                                            ? AppColors.danger
                                            : context.appPalette.textPrimary,
                                      ),
                                    ),
                                    if (labels.isNotEmpty)
                                      Text(
                                        labels.join(' · '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color:
                                              context.appPalette.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _NarrowCapacity extends StatelessWidget {
  const _NarrowCapacity({required this.capacity, required this.approvedLeaves});
  final PocCapacityWeek capacity;
  final List<LeaveRequest> approvedLeaves;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      _WeekHeader(capacity: capacity),
      Expanded(
        child: capacity.developers.isEmpty
            ? const Center(child: Text('Chưa có dữ liệu Dev'))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                itemCount: capacity.developers.length,
                itemBuilder: (context, index) {
                  final developer = capacity.developers[index];
                  final leaves = _leavesFor(approvedLeaves, developer.userId);
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: context.appPalette.surfaceVariant,
                      ),
                    ),
                    child: ExpansionTile(
                      title: _DeveloperSummary(
                        developer: developer,
                        leaveCount: leaves.length,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      children: [
                        ...capacity.dates
                            .take(5)
                            .map(
                              (date) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(_dayLabel(date)),
                                trailing: Text(
                                  '${(developer.dailyLoad[date] ?? 0).toStringAsFixed(1)} giờ',
                                ),
                              ),
                            ),
                        ...developer.pocs.map(
                          (poc) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.science_outlined,
                              size: 18,
                            ),
                            title: Text(
                              (poc['code'] ?? poc['title'] ?? 'PoC').toString(),
                            ),
                            subtitle: Text(
                              '${poc['title'] ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        ...leaves.map(
                          (leave) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.beach_access_outlined,
                              size: 18,
                              color: AppColors.warning,
                            ),
                            title: const Text('Nghỉ đã duyệt'),
                            subtitle: Text(
                              '${leave.startDate} - ${leave.endDate}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    ],
  );
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.capacity});
  final PocCapacityWeek capacity;
  @override
  Widget build(BuildContext context) {
    final overloaded = capacity.developers
        .where((item) => item.overCapacity)
        .length;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Tuần ${capacity.isoWeek}/${capacity.isoYear}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (overloaded > 0)
            Text(
              '$overloaded Dev vượt tải',
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _DeveloperSummary extends StatelessWidget {
  const _DeveloperSummary({required this.developer, this.leaveCount = 0});
  final PocCapacityDeveloper developer;
  final int leaveCount;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    child: Row(
      children: [
        CircleAvatar(
          radius: 18,
          child: Text(
            developer.name.isEmpty ? '?' : developer.name[0].toUpperCase(),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                developer.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${developer.allocatedHours.toStringAsFixed(1)} / ${developer.capacityHours.toStringAsFixed(0)} giờ',
                style: TextStyle(
                  fontSize: 12,
                  color: developer.overCapacity
                      ? AppColors.danger
                      : context.appPalette.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (developer.hasOverlap)
          const Tooltip(
            message: 'Có PoC trùng lịch',
            child: Icon(
              Icons.content_copy_outlined,
              size: 18,
              color: AppColors.warning,
            ),
          ),
        if (leaveCount > 0)
          Tooltip(
            message: '$leaveCount đơn nghỉ đã duyệt trong kỳ',
            child: const Icon(
              Icons.beach_access_outlined,
              size: 18,
              color: AppColors.warning,
            ),
          ),
      ],
    ),
  );
}

String _dayLabel(String raw) {
  final date = DateTime.tryParse(raw);
  return date == null ? raw : DateFormat('EEE\ndd/MM').format(date);
}

List<LeaveRequest> _leavesFor(List<LeaveRequest> leaves, String userId) =>
    leaves.where((leave) => leave.userId == userId).toList(growable: false);

List<String> _pocLabelsForDate(List<Map<String, dynamic>> pocs, String date) =>
    pocs
        .where((poc) {
          final start = DateTime.tryParse(
            '${poc['planned_start_at'] ?? ''}',
          )?.toLocal();
          final end = DateTime.tryParse('${poc['demo_at'] ?? ''}')?.toLocal();
          if (start == null || end == null) return false;
          final target = DateTime.tryParse(date);
          if (target == null) return false;
          final dayStart = DateTime(target.year, target.month, target.day);
          final dayEnd = dayStart.add(const Duration(days: 1));
          return start.isBefore(dayEnd) && end.isAfter(dayStart);
        })
        .map((poc) => (poc['code'] ?? poc['title'] ?? 'PoC').toString())
        .toList(growable: false);
