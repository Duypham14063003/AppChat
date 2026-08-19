import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nineteen_tech_app/core/theme/app_typography.dart';
import 'package:nineteen_tech_app/core/theme/theme_color_presets.dart';
import 'package:nineteen_tech_app/features/auth/providers/auth_notifier.dart';
import 'package:nineteen_tech_app/features/hr/data/hr_models.dart';
import 'package:nineteen_tech_app/features/hr/providers/hr_providers.dart';
import 'package:nineteen_tech_app/shared/widgets/heart_header_badge.dart';

class RewardLeaderboardScreen extends ConsumerStatefulWidget {
  const RewardLeaderboardScreen({super.key});

  static const int _limit = 2;

  static const List<_LeaderboardDepartmentOption> _departmentOptions = [
    _LeaderboardDepartmentOption(
      label: 'Phát triển sản phẩm',
      apiValue: 'Phát triển sản phẩm',
    ),
    _LeaderboardDepartmentOption(
      label: 'Phát triển thương hiệu',
      apiValue: 'Kinh doanh',
    ),
  ];

  @override
  ConsumerState<RewardLeaderboardScreen> createState() =>
      _RewardLeaderboardScreenState();
}

class _RewardLeaderboardScreenState
    extends ConsumerState<RewardLeaderboardScreen> {
  String? _selectedDepartment = 'Kinh doanh';

  @override
  Widget build(BuildContext context) {
    scheduleRewardWalletFreshnessCheck(ref);
    final palette = context.appPalette;
    final now = DateTime.now();
    final previousMonthPeriod = _companyPreviousTopPeriod(now);
    final previousTopAsync = ref.watch(
      rewardsTopPeriodGroupedProvider(previousMonthPeriod),
    );
    final overviewQuery = RewardsOverviewQuery(
      limit: RewardLeaderboardScreen._limit,
      department: _selectedDepartment,
    );
    final overviewAsync = ref.watch(rewardsOverviewProvider(overviewQuery));

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Bảng xếp hạng'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: HeartHeaderBadge(compact: true)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(rewardsOverviewProvider(overviewQuery));
          await ref.read(rewardsOverviewProvider(overviewQuery).future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  children: [
                    _PreviousMonthTopSection(
                      period: previousMonthPeriod,
                      previousTopAsync: previousTopAsync,
                    ),
                    const SizedBox(height: 20),
                    overviewAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, _) => _LeaderboardError(
                        message: '$error',
                        onRetry: () => ref.invalidate(
                          rewardsOverviewProvider(overviewQuery),
                        ),
                      ),
                      data: (overview) {
                        final leaderboard = overview.leaderboard;
                        final topCount = leaderboard.length.clamp(0, 2);
                        final topEntries = leaderboard.take(topCount).toList();

                        return Column(
                          children: [
                            _LeaderboardHero(
                              topEntries: topEntries,
                              selectedDepartment: _selectedDepartment,
                              departmentOptions:
                                  RewardLeaderboardScreen._departmentOptions,
                              onDepartmentChanged: (value) {
                                setState(() {
                                  _selectedDepartment = value;
                                });
                              },
                            ),
                            if (leaderboard.isEmpty) ...[
                              const SizedBox(height: 18),
                              const _LeaderboardEmpty(),
                            ] else ...[
                              const SizedBox(height: 18),
                              for (final entry in leaderboard.skip(
                                topCount,
                              )) ...[
                                _LeaderboardTile(entry: entry),
                                const SizedBox(height: 12),
                              ],
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardHero extends StatelessWidget {
  const _LeaderboardHero({
    required this.topEntries,
    required this.selectedDepartment,
    required this.departmentOptions,
    required this.onDepartmentChanged,
  });

  final List<RewardLeaderboardEntry> topEntries;
  final String? selectedDepartment;
  final List<_LeaderboardDepartmentOption> departmentOptions;
  final ValueChanged<String?> onDepartmentChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final first = topEntries.where((entry) => entry.rank == 1).firstOrNull;
    final second = topEntries.where((entry) => entry.rank == 2).firstOrNull;
    final third = topEntries.where((entry) => entry.rank == 3).firstOrNull;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.card,
            Color.lerp(palette.card, palette.primary, 0.06) ?? palette.card,
            palette.card,
          ],
        ),
        border: Border.all(color: palette.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 560;
              final heading = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Top nhân viên',
                    style: AppTypography.titleLarge.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Bảng xếp hạng theo điểm kinh nghiệm hiện tại',
                    style: AppTypography.bodyMedium.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              );
              final departmentPicker = DropdownButtonFormField<String?>(
                initialValue: selectedDepartment,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Phòng ban',
                  filled: true,
                  fillColor: palette.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                dropdownColor: palette.surface,
                items: departmentOptions
                    .map(
                      (option) => DropdownMenuItem<String?>(
                        value: option.apiValue,
                        child: Text(option.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: onDepartmentChanged,
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    const SizedBox(height: 14),
                    SizedBox(width: double.infinity, child: departmentPicker),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: 16),
                  SizedBox(width: 220, child: departmentPicker),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final entries = [
                second,
                first,
                third,
              ].whereType<RewardLeaderboardEntry>().toList();
              if (constraints.maxWidth < 700) {
                final compactEntries = [
                  first,
                  second,
                  third,
                ].whereType<RewardLeaderboardEntry>().toList();
                return Column(
                  children: [
                    for (final entry in compactEntries) ...[
                      SizedBox(
                        width: double.infinity,
                        child: _TopPerformerCard(entry: entry),
                      ),
                      if (entry != compactEntries.last)
                        const SizedBox(height: 10),
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var index = 0; index < entries.length; index++) ...[
                    Expanded(child: _TopPerformerCard(entry: entries[index])),
                    if (index != entries.length - 1) const SizedBox(width: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LeaderboardDepartmentOption {
  const _LeaderboardDepartmentOption({required this.label, this.apiValue});

  final String label;
  final String? apiValue;
}

class _TopPerformerCard extends StatelessWidget {
  const _TopPerformerCard({required this.entry});

  final RewardLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final accent = _leaderboardRankColor(entry.rank, palette);
    final isFirst = entry.rank == 1;
    return Container(
      height: isFirst ? 236 : 212,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: isFirst
            ? Color.lerp(palette.surface, accent, 0.07)
            : palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: isFirst ? 0.48 : 0.22),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              _LeaderboardAvatar(entry: entry, size: isFirst ? 76 : 64),
              Positioned(
                right: -5,
                bottom: -3,
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.surface, width: 2),
                  ),
                  child: Text(
                    '${entry.rank}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '${formatHeartPoints(entry.rankingPoints)} exp',
            style: AppTypography.titleMedium.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${formatHeartPoints(entry.balance)} điểm khả dụng',
            style: AppTypography.bodySmall.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({required this.entry});

  final RewardLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final accent = _leaderboardRankColor(entry.rank, palette);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.surfaceVariant.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            alignment: Alignment.center,
            child: Text(
              '#${entry.rank}',
              style: AppTypography.titleMedium.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _LeaderboardAvatar(entry: entry, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: AppTypography.titleMedium.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatHeartPoints(entry.rankingPoints),
                style: AppTypography.titleLarge.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'exp',
                style: AppTypography.labelSmall.copyWith(
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Balance: ${formatHeartPoints(entry.balance)}',
                style: AppTypography.bodySmall.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaderboardAvatar extends StatelessWidget {
  const _LeaderboardAvatar({required this.entry, required this.size});

  final RewardLeaderboardEntry entry;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final initials = _leaderboardInitials(entry.name);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.primary.withValues(alpha: 0.12),
        border: Border.all(color: palette.primary.withValues(alpha: 0.16)),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: entry.avatarUrl == null || entry.avatarUrl!.isEmpty
          ? Text(
              initials,
              style: AppTypography.titleMedium.copyWith(
                color: palette.primary,
                fontWeight: FontWeight.w800,
              ),
            )
          : Image.network(
              entry.avatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Text(
                initials,
                style: AppTypography.titleMedium.copyWith(
                  color: palette.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
    );
  }
}

class _PreviousMonthTopSection extends StatelessWidget {
  const _PreviousMonthTopSection({
    required this.period,
    required this.previousTopAsync,
  });

  final String period;
  final AsyncValue<RewardTopPeriodResponse> previousTopAsync;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return previousTopAsync.when(
      loading: () => const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.surfaceVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top tháng trước ($period)',
              style: AppTypography.titleLarge.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Không tải được dữ liệu top tháng trước.',
              style: AppTypography.bodyMedium.copyWith(
                color: palette.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$error',
              style: AppTypography.bodySmall.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
      data: (groups) {
        if (groups.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.surfaceVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top tháng trước ($period)',
                  style: AppTypography.titleLarge.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Chưa có dữ liệu top tháng trước.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: palette.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.surfaceVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top tháng trước ($period)',
                style: AppTypography.titleLarge.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final tech = _TopPeriodGroup(
                    title: 'Kỹ thuật',
                    subtitle: 'QC và Fullstack Developer',
                    entries: groups.tech,
                  );
                  final other = _TopPeriodGroup(
                    title: 'Phát triển thương hiệu',
                    subtitle: 'Các vị trí còn lại',
                    entries: groups.other,
                  );
                  if (constraints.maxWidth < 760) {
                    return Column(
                      children: [tech, const SizedBox(height: 16), other],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: tech),
                      const SizedBox(width: 16),
                      Expanded(child: other),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopPeriodGroup extends StatelessWidget {
  const _TopPeriodGroup({
    required this.title,
    required this.subtitle,
    required this.entries,
  });

  final String title;
  final String subtitle;
  final List<RewardTopPeriodEntry> entries;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.titleMedium.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: AppTypography.bodySmall.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'Chưa có dữ liệu',
                  style: TextStyle(color: palette.textSecondary),
                ),
              ),
            )
          else
            for (var index = 0; index < entries.length; index++) ...[
              _TopPeriodTile(entry: entries[index], rank: index + 1),
              if (index < entries.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _TopPeriodTile extends StatelessWidget {
  const _TopPeriodTile({required this.entry, required this.rank});

  final RewardTopPeriodEntry entry;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final accent = _leaderboardRankColor(rank, palette);
    final displayName = entry.displayName;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.surfaceVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            alignment: Alignment.center,
            child: Text(
              '#$rank',
              style: AppTypography.titleMedium.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.primary.withValues(alpha: 0.12),
              border: Border.all(
                color: palette.primary.withValues(alpha: 0.16),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: entry.avatarUrl == null || entry.avatarUrl!.isEmpty
                ? Text(
                    displayName.characters.take(2).toString().toUpperCase(),
                    style: AppTypography.titleMedium.copyWith(
                      color: palette.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : Image.network(
                    entry.avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Text(
                      displayName.characters.take(2).toString().toUpperCase(),
                      style: AppTypography.titleMedium.copyWith(
                        color: palette.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.period,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatHeartPoints(entry.pointsEarned),
                style: AppTypography.titleLarge.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'exp',
                style: AppTypography.labelSmall.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaderboardError extends StatelessWidget {
  const _LeaderboardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.surfaceVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.emoji_events_outlined, color: palette.primary, size: 28),
          const SizedBox(height: 12),
          Text(
            'Không tải được bảng xếp hạng',
            style: AppTypography.titleMedium.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

class _LeaderboardEmpty extends StatelessWidget {
  const _LeaderboardEmpty();

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.surfaceVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.emoji_events_outlined, color: palette.primary, size: 30),
          const SizedBox(height: 12),
          Text(
            'Chưa có dữ liệu xếp hạng',
            style: AppTypography.titleMedium.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Khi hệ thống có điểm tim của nhân viên, bảng xếp hạng sẽ hiển thị ở đây.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

Color _leaderboardRankColor(int rank, dynamic palette) {
  switch (rank) {
    case 1:
      return const Color(0xFFE0A11B);
    case 2:
      return const Color(0xFF92A0C8);
    case 3:
      return const Color(0xFFC98152);
    case 4:
      return const Color(0xFF8B7355);
    default:
      return palette.primary;
  }
}

String _leaderboardInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'NV';
  if (parts.length == 1) {
    return parts.first.characters.take(2).toString().toUpperCase();
  }
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}

String _companyPreviousTopPeriod(DateTime now) {
  final period = now.day >= 25
      ? DateTime(now.year, now.month)
      : DateTime(now.year, now.month - 1);
  return '${period.year.toString().padLeft(4, '0')}-${period.month.toString().padLeft(2, '0')}';
}
