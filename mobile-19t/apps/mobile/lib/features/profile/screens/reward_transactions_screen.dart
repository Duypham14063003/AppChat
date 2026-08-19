import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nineteen_tech_app/core/theme/app_typography.dart';
import 'package:nineteen_tech_app/core/theme/theme_color_presets.dart';
import 'package:nineteen_tech_app/features/hr/data/hr_models.dart';
import 'package:nineteen_tech_app/features/hr/providers/hr_providers.dart';
import 'package:nineteen_tech_app/shared/widgets/heart_header_badge.dart';

class RewardTransactionsScreen extends ConsumerWidget {
  const RewardTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appPalette;
    final transactionsAsync = ref.watch(myRewardTransactionsProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Lịch sử tim'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: HeartHeaderBadge(compact: true)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myRewardTransactionsProvider);
          await ref.read(myRewardTransactionsProvider.future);
        },
        child: transactionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _RewardTransactionsError(
            message: '$error',
            onRetry: () => ref.invalidate(myRewardTransactionsProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const _RewardTransactionsEmpty();
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _RewardTransactionCard(item: items[index]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _RewardTransactionCard extends StatelessWidget {
  const _RewardTransactionCard({required this.item});

  final RewardTransaction item;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final meta = _rewardTransactionMeta(item.type);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: meta.color.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: meta.color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            // width: 48,
            // height: 48,
            // decoration: BoxDecoration(
            //   shape: BoxShape.circle,
            //   color: meta.color.withValues(alpha: 0.14),
            // ),
            // alignment: Alignment.center,
            // child: Icon(meta.icon, color: meta.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meta.label,
                            style: AppTypography.titleMedium.copyWith(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatRewardDateTime(item.createdAt),
                            style: AppTypography.bodySmall.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${formatHeartPoints(item.points)}',
                      style: AppTypography.titleLarge.copyWith(
                        color: meta.color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if ((item.note ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    item.note!.trim(),
                    style: AppTypography.bodyMedium.copyWith(
                      color: palette.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  // padding: const EdgeInsets.symmetric(
                  //   horizontal: 0,
                  //   vertical: 10,
                  // ),
                 
                  child: Row(
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        size: 16,
                        color: palette.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Số dư sau giao dịch: ${formatHeartPoints(item.balanceAfter)} tym',
                        style: AppTypography.labelMedium.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardTransactionsError extends StatelessWidget {
  const _RewardTransactionsError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.surfaceVariant),
          ),
          child: Column(
            children: [
              Icon(Icons.history_toggle_off_rounded, color: palette.primary),
              const SizedBox(height: 12),
              Text(
                'Không tải được lịch sử tim',
                textAlign: TextAlign.center,
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
        ),
      ],
    );
  }
}

class _RewardTransactionsEmpty extends StatelessWidget {
  const _RewardTransactionsEmpty();

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.surfaceVariant),
          ),
          child: Column(
            children: [
              Icon(Icons.favorite_border_rounded, color: palette.primary),
              const SizedBox(height: 12),
              Text(
                'Chưa có giao dịch tym',
                style: AppTypography.titleMedium.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Khi bạn nhận hoặc dùng tym, lịch sử sẽ hiện ở đây.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RewardTransactionMeta {
  const _RewardTransactionMeta({
    required this.label,
    required this.sign,
    required this.color,
    required this.icon,
  });

  final String label;
  final String sign;
  final Color color;
  final IconData icon;
}

_RewardTransactionMeta _rewardTransactionMeta(String type) {
  switch (type.trim().toLowerCase()) {
    case 'earn':
      return const _RewardTransactionMeta(
        label: 'Nhận tym',
        sign: '+',
        color: Color(0xFF29B36A),
        icon: Icons.south_west_rounded,
      );
    case 'spend':
      return const _RewardTransactionMeta(
        label: 'Dùng tym',
        sign: '-',
        color: Color(0xFFE0A11B),
        icon: Icons.north_east_rounded,
      );
    case 'adjust':
      return const _RewardTransactionMeta(
        label: 'Điều chỉnh tym',
        sign: '+',
        color: Color(0xFF3BA1FF),
        icon: Icons.tune_rounded,
      );
    default:
      return const _RewardTransactionMeta(
        label: 'Giao dịch tym',
        sign: '',
        color: Color(0xFF8A8F98),
        icon: Icons.receipt_long_rounded,
      );
  }
}

String _formatRewardDateTime(DateTime? value) {
  if (value == null) return 'Không rõ thời gian';
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/$year • $hour:$minute';
}
