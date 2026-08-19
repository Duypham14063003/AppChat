import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nineteen_tech_app/core/theme/app_typography.dart';
import 'package:nineteen_tech_app/core/theme/theme_color_presets.dart';
import 'package:nineteen_tech_app/core/utils/snackbar_utils.dart';
import 'package:nineteen_tech_app/features/auth/providers/auth_notifier.dart';
import 'package:nineteen_tech_app/features/hr/data/hr_models.dart';
import 'package:nineteen_tech_app/features/hr/providers/hr_providers.dart';
import 'package:nineteen_tech_app/shared/widgets/heart_header_badge.dart';

class RewardShopScreen extends ConsumerWidget {
  const RewardShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    scheduleRewardWalletFreshnessCheck(ref);
    final palette = context.appPalette;
    final catalogAsync = ref.watch(rewardCatalogProvider);
    final points = ref.watch(authNotifierProvider).valueOrNull?.points ?? 0;
    final isWide = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Cửa hàng'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: HeartHeaderBadge(compact: true)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(rewardCatalogProvider);
          await ref.read(rewardCatalogProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            isWide ? 28 : 16,
            16,
            isWide ? 28 : 16,
            28,
          ),
          children: [
            _RewardShopHero(
              points: points,
              isWide: isWide,
              onHistoryPressed: () => _showRewardHistorySheet(context),
            ),
            const SizedBox(height: 18),
            catalogAsync.when(
              loading: () => const _RewardShopLoading(),
              error: (error, _) => _RewardShopError(
                message: '$error',
                onRetry: () => ref.invalidate(rewardCatalogProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const _RewardShopEmpty();
                }

                return _RewardCatalogSection(
                  items: items,
                  points: points,
                  isWide: isWide,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardShopHero extends StatelessWidget {
  const _RewardShopHero({
    required this.points,
    required this.isWide,
    required this.onHistoryPressed,
  });

  final int points;
  final bool isWide;
  final VoidCallback onHistoryPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    const pink = Color(0xFFFF5B7F);
    final heroTextColor = palette.textPrimary;
    final chipBackgroundColor = palette.surface;
    final chipBorderColor = palette.surfaceVariant;

    return Container(
      // padding: EdgeInsets.all(isWide ? 28 : 20),
      decoration: BoxDecoration(
        // borderRadius: BorderRadius.circular(24),
        // gradient: LinearGradient(
        //   begin: Alignment.topLeft,
        //   end: Alignment.bottomRight,
        //   colors: [
        //     accent,
        //     Color.lerp(accent, pink, 0.7) ?? pink,
        //   ],
        // ),
        // boxShadow: [
        //   BoxShadow(
        //     color: accent.withValues(alpha: 0.3),
        //     blurRadius: 24,
        //     offset: const Offset(0, 10),
        //   ),
        // ],
      ),
      child: Row(
        // crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              // crossAxisAlignment: CrossAxisAlignment.start,r
              children: [
                Container(
                  // padding: const EdgeInsets.symmetric(
                  //   // horizontal: 14,
                  //   // vertical: 6,
                  // ),
                  // decoration: BoxDecoration(
                  //   color: Colors.white.withValues(alpha: 0.2),
                  //   borderRadius: BorderRadius.circular(999),
                  // ),
                  // child: Text(
                  //   'REWARD ARCADE',
                  //   style: AppTypography.labelMedium.copyWith(
                  //     color: Colors.white,
                  //     fontWeight: FontWeight.w800,
                  //     letterSpacing: 1.0,
                  //   ),
                  // ),
                ),
                // const SizedBox(height: 16),
                // Text(
                //   'Săn quà\nđỉnh cao',
                //   style: AppTypography.headlineMedium.copyWith(
                //     color: heroTextColor,
                //     fontWeight: FontWeight.w900,
                //     height: 1.1,
                //   ),
                // ),
                // const SizedBox(height: 10),
                // Text(
                //   'Dùng tym đổi lấy món đồ yêu thích của bạn ngay hôm nay!',
                //   style: AppTypography.bodyMedium.copyWith(
                //     color: heroSubtextColor,
                //     height: 1.4,
                //   ),
                // ),
                // const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _HeroStatChip(
                      icon: Icons.favorite_rounded,
                      color: pink,
                      label: '${formatHeartPoints(points)} tym',
                      textColor: heroTextColor,
                      backgroundColor: chipBackgroundColor,
                      borderColor: chipBorderColor,
                    ),
                    _HeroActionChip(
                      icon: Icons.history_rounded,
                      label: 'Lịch sử',
                      onTap: onHistoryPressed,
                      textColor: heroTextColor,
                      backgroundColor: chipBackgroundColor,
                      borderColor: chipBorderColor,
                      accent: palette.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Container(
          //   width: isWide ? 130 : 100,
          //   height: isWide ? 130 : 100,
          //   decoration: BoxDecoration(
          //     shape: BoxShape.circle,
          //     color: Colors.white.withValues(alpha: 0.1),
          //     border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          //   ),
          //   child: Stack(
          //     alignment: Alignment.center,
          //     children: [
          //       Icon(
          //         Icons.redeem_rounded,
          //         size: isWide ? 60 : 48,
          //         color: Colors.white.withValues(alpha: 0.9),
          //       ),
          //       Positioned(
          //         top: isWide ? 20 : 12,
          //         right: isWide ? 20 : 12,
          //         child: Icon(
          //           Icons.auto_awesome,
          //           size: isWide ? 24 : 18,
          //           color: Colors.amber,
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  const _HeroStatChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final IconData icon;
  final Color color;
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroActionChip extends StatelessWidget {
  const _HeroActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardCatalogSection extends StatefulWidget {
  const _RewardCatalogSection({
    required this.items,
    required this.points,
    required this.isWide,
  });

  final List<RewardAdminItem> items;
  final int points;
  final bool isWide;

  @override
  State<_RewardCatalogSection> createState() => _RewardCatalogSectionState();
}

class _RewardCatalogSectionState extends State<_RewardCatalogSection> {
  int _currentPage = 1;
  final int _itemsPerPage = 12;

  @override
  void didUpdateWidget(covariant _RewardCatalogSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length) {
      if (mounted) setState(() => _currentPage = 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = (width - 32) ~/ 160;
    if (crossAxisCount < 2) crossAxisCount = 2;

    final totalItems = widget.items.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    var endIndex = startIndex + _itemsPerPage;
    if (endIndex > totalItems) endIndex = totalItems;

    final currentItems = widget.items.sublist(startIndex, endIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Phòng trưng bày quà',
              style: AppTypography.titleLarge.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              '${widget.items.length} vật phẩm',
              style: AppTypography.bodyMedium.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: currentItems.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.65, // Adjust for new card layout
          ),
          itemBuilder: (context, index) {
            final item = currentItems[index];
            return _RewardCatalogCard(item: item, points: widget.points);
          },
        ),
        if (totalPages > 1) ...[
          const SizedBox(height: 24),
          _PaginationControls(
            currentPage: _currentPage,
            totalPages: totalPages,
            onPageChanged: (page) {
              setState(() => _currentPage = page);
            },
            palette: palette,
          ),
        ],
      ],
    );
  }
}

class _PaginationControls extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;
  final AppThemePalette palette;

  const _PaginationControls({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: currentPage > 1
              ? () => onPageChanged(currentPage - 1)
              : null,
          icon: const Icon(Icons.chevron_left),
          color: palette.primary,
          disabledColor: palette.textHint,
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.surfaceVariant),
          ),
          child: Text(
            '$currentPage / $totalPages',
            style: AppTypography.labelLarge.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: currentPage < totalPages
              ? () => onPageChanged(currentPage + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
          color: palette.primary,
          disabledColor: palette.textHint,
        ),
      ],
    );
  }
}

class _RewardCatalogCard extends StatelessWidget {
  const _RewardCatalogCard({required this.item, required this.points});

  final RewardAdminItem item;
  final int points;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final canAfford = points >= item.pointsCost;
    final isSoldOut = item.stockRemaining <= 0;
    final rarity = _rewardRarity(item.pointsCost);
    final accent = rarity.color;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showRewardDetailSheet(context, item, points),
      child: Container(
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.surfaceVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _RewardCardImage(
                    imageUrl: item.imageUrl,
                    fallbackLabel: item.name,
                    accent: accent,
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _RarityBadge(rarity: rarity),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        canAfford ? Icons.flash_on_rounded : Icons.lock_outline,
                        color: canAfford ? accent : Colors.white70,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (item.description.isNotEmpty)
                        Text(
                          item.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.favorite_rounded, size: 16, color: accent),
                      const SizedBox(width: 4),
                      Text(
                        formatHeartPoints(item.pointsCost),
                        style: AppTypography.titleMedium.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSoldOut
                              ? Colors.red.withValues(alpha: 0.1)
                              : palette.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isSoldOut ? 'Hết hàng' : 'Còn ${item.stockRemaining}',
                          style: AppTypography.labelSmall.copyWith(
                            color: isSoldOut
                                ? Colors.redAccent
                                : palette.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
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
    );
  }
}

class _RewardCardImage extends StatelessWidget {
  const _RewardCardImage({
    required this.imageUrl,
    required this.fallbackLabel,
    required this.accent,
  });

  final String? imageUrl;
  final String fallbackLabel;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.surfaceVariant.withValues(alpha: 0.3),
      ),
      child: imageUrl == null || imageUrl!.isEmpty
          ? _RewardImageFallback(label: fallbackLabel, accent: accent)
          : Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  _RewardImageFallback(label: fallbackLabel, accent: accent),
            ),
    );
  }
}

class _RewardImageFallback extends StatelessWidget {
  const _RewardImageFallback({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final initials = _rewardInitials(label);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 10,
          right: 10,
          child: Icon(Icons.auto_awesome, color: accent, size: 18),
        ),
        Center(
          child: Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.16),
              border: Border.all(color: accent.withValues(alpha: 0.34)),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: AppTypography.headlineSmall.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RarityBadge extends StatelessWidget {
  const _RarityBadge({required this.rarity});

  final _RewardRarity rarity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: rarity.color.withValues(alpha: 0.16),
        border: Border.all(color: rarity.color.withValues(alpha: 0.26)),
      ),
      child: Text(
        rarity.label,
        style: AppTypography.labelSmall.copyWith(
          color: rarity.color,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _RewardShopLoading extends StatelessWidget {
  const _RewardShopLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _RewardShopError extends StatelessWidget {
  const _RewardShopError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.surfaceVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.store_mall_directory_outlined, color: palette.primary),
          const SizedBox(height: 12),
          Text(
            'Không tải được cửa hàng',
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

class _RewardShopEmpty extends StatelessWidget {
  const _RewardShopEmpty();

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        // color: palette.surface,
        // borderRadius: BorderRadius.circular(24),
        // border: Border.all(color: palette.surfaceVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 34, color: palette.primary),
          const SizedBox(height: 12),
          Text(
            'Cửa hàng đang trống',
            style: AppTypography.titleMedium.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          // const SizedBox(height: 8),
          // Text(
          //   'Khi backend mở catalog quà tặng, vật phẩm sẽ xuất hiện ở đây.',
          //   textAlign: TextAlign.center,
          //   style: AppTypography.bodyMedium.copyWith(
          //     color: palette.textSecondary,
          //   ),
          // ),
        ],
      ),
    );
  }
}

Future<void> _showRewardDetailSheet(
  BuildContext context,
  RewardAdminItem item,
  int points,
) {
  final parentContext = context;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _RewardRedemptionSheet(
        item: item,
        points: points,
        parentContext: parentContext,
      );
    },
  );
}

class _RewardRedemptionSheet extends ConsumerStatefulWidget {
  const _RewardRedemptionSheet({
    required this.item,
    required this.points,
    required this.parentContext,
  });

  final RewardAdminItem item;
  final int points;
  final BuildContext parentContext;

  @override
  ConsumerState<_RewardRedemptionSheet> createState() =>
      _RewardRedemptionSheetState();
}

class _RewardRedemptionSheetState
    extends ConsumerState<_RewardRedemptionSheet> {
  final _noteController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitRedemption() async {
    if (_isSubmitting) return;

    final item = widget.item;
    final canAfford = widget.points >= item.pointsCost;
    final isSoldOut = item.stockRemaining <= 0;

    if (isSoldOut || !canAfford) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final authNotifier = ref.read(authNotifierProvider.notifier);
      await ref
          .read(hrRepositoryProvider)
          .createRewardRedemption(
            rewardItemId: item.id,
            quantity: 1,
            requestedNote: _noteController.text,
          );

      ref.invalidate(rewardCatalogProvider);
      ref.invalidate(myRewardRedemptionsProvider);

      if (!mounted) return;
      Navigator.of(context).pop();
      unawaited(authNotifier.resyncRewardWallet(force: true));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!widget.parentContext.mounted) return;
        showTopSnackBar(
          widget.parentContext,
          message: 'Đã gửi yêu cầu đổi "${item.name}"',
        );
      });
    } on DioException catch (error) {
      final message = error.response?.data is Map
          ? (error.response!.data as Map)['message']?.toString()
          : null;
      if (!mounted) return;
      setState(() {
        _errorText = message ?? 'Đổi quà thất bại.';
        _isSubmitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString();
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final rarity = _rewardRarity(widget.item.pointsCost);
    final canAfford = widget.points >= widget.item.pointsCost;
    final isSoldOut = widget.item.stockRemaining <= 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.55,
      maxChildSize: 0.92,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.surfaceVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _RewardCardImage(
                imageUrl: widget.item.imageUrl,
                fallbackLabel: widget.item.name,
                accent: rarity.color,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _RarityBadge(rarity: rarity),
                  const Spacer(),
                  Text(
                    'Còn ${widget.item.stockRemaining}/${widget.item.stockTotal}',
                    style: AppTypography.labelMedium.copyWith(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                widget.item.name,
                style: AppTypography.headlineSmall.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.item.description.isNotEmpty
                    ? widget.item.description
                    : 'Quà tặng nội bộ dành cho thành viên trong công ty.',
                style: AppTypography.bodyLarge.copyWith(
                  color: palette.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: rarity.color.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.favorite_rounded, color: rarity.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Giá đổi: ${formatHeartPoints(widget.item.pointsCost)} tym',
                        style: AppTypography.titleMedium.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _noteController,
                maxLines: 3,
                style: TextStyle(color: palette.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Ghi chú yêu cầu',
                  hintText: 'Ví dụ: Đổi quà giúp mình',
                  hintStyle: TextStyle(color: palette.textHint),
                  labelStyle: TextStyle(color: palette.textSecondary),
                  filled: true,
                  fillColor: palette.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: palette.surfaceVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: palette.surfaceVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: rarity.color),
                  ),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.redAccent,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: (!canAfford || isSoldOut || _isSubmitting)
                    ? null
                    : _submitRedemption,
                style: FilledButton.styleFrom(
                  backgroundColor: rarity.color,
                  foregroundColor: palette.isLight
                      ? palette.background
                      : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: _isSubmitting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.isLight
                              ? palette.background
                              : Colors.white,
                        ),
                      )
                    : const Icon(Icons.shopping_bag_outlined),
                label: Text(
                  isSoldOut
                      ? 'Hết hàng'
                      : canAfford
                      ? 'Đổi quà ngay'
                      : 'Không đủ tym',
                  style: AppTypography.labelLarge.copyWith(
                    color: palette.isLight ? palette.background : Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _showRewardHistorySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _RewardHistorySheet(),
  );
}

class _RewardHistorySheet extends ConsumerWidget {
  const _RewardHistorySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appPalette;
    final redemptionsAsync = ref.watch(myRewardRedemptionsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.surfaceVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lịch sử đổi quà',
                            style: AppTypography.titleLarge.copyWith(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Các yêu cầu đổi quà của bạn',
                            style: AppTypography.bodyMedium.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          ref.invalidate(myRewardRedemptionsProvider),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: redemptionsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => _RewardHistoryError(
                    message: '$error',
                    onRetry: () => ref.invalidate(myRewardRedemptionsProvider),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return const _RewardHistoryEmpty();
                    }

                    return ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _RewardHistoryCard(item: items[index]);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RewardHistoryCard extends StatelessWidget {
  const _RewardHistoryCard({required this.item});

  final RewardRedemption item;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final rewardItem = item.rewardItem;
    final rarity = _rewardRarity(item.unitPointsCost);
    final accent = rarity.color;
    final status = _rewardRedemptionStatusMeta(item.status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(1),
              child: _RewardCardImage(
                imageUrl: rewardItem?.imageUrl,
                fallbackLabel: rewardItem?.name ?? 'Reward',
                accent: accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        rewardItem?.name ?? 'Phần quà',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: status.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        status.label,
                        style: AppTypography.labelSmall.copyWith(
                          color: status.color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'SL ${item.quantity} • ${formatHeartPoints(item.totalPointsCost)} tym',
                  style: AppTypography.bodyMedium.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatRewardDateTime(item.createdAt),
                  style: AppTypography.bodySmall.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                if ((item.requestedNote ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Ghi chú: ${item.requestedNote!.trim()}',
                    style: AppTypography.bodySmall.copyWith(
                      color: palette.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
                if ((item.processedNote ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Phản hồi: ${item.processedNote!.trim()}',
                    style: AppTypography.bodySmall.copyWith(
                      color: palette.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardHistoryError extends StatelessWidget {
  const _RewardHistoryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
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
              Icon(Icons.receipt_long_outlined, color: palette.primary),
              const SizedBox(height: 12),
              Text(
                'Không tải được lịch sử đổi quà',
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

class _RewardHistoryEmpty extends StatelessWidget {
  const _RewardHistoryEmpty();

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
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
              Icon(Icons.history_toggle_off_rounded, color: palette.primary),
              const SizedBox(height: 12),
              Text(
                'Chưa có lượt đổi quà nào',
                style: AppTypography.titleMedium.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Khi bạn gửi yêu cầu đổi quà, lịch sử sẽ xuất hiện ở đây.',
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

_RewardRarity _rewardRarity(int pointsCost) {
  if (pointsCost >= 500) {
    return const _RewardRarity('Legendary', Color(0xFFFF7A00));
  }
  if (pointsCost >= 250) {
    return const _RewardRarity('Epic', Color(0xFFE056FD));
  }
  if (pointsCost >= 120) {
    return const _RewardRarity('Rare', Color(0xFF3BA1FF));
  }
  return const _RewardRarity('Common', Color(0xFFE0A11B));
}

String _rewardInitials(String label) {
  final parts = label
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'RW';
  if (parts.length == 1) {
    return parts.first.characters.take(2).toString().toUpperCase();
  }
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}

class _RewardRarity {
  const _RewardRarity(this.label, this.color);

  final String label;
  final Color color;
}

class _RewardRedemptionStatusMeta {
  const _RewardRedemptionStatusMeta(this.label, this.color);

  final String label;
  final Color color;
}

_RewardRedemptionStatusMeta _rewardRedemptionStatusMeta(String status) {
  switch (status.trim().toLowerCase()) {
    case 'approved':
    case 'completed':
    case 'success':
      return const _RewardRedemptionStatusMeta('Đã duyệt', Color(0xFF29B36A));
    case 'rejected':
    case 'cancelled':
    case 'canceled':
      return const _RewardRedemptionStatusMeta('Từ chối', Color(0xFFE25555));
    default:
      return const _RewardRedemptionStatusMeta('Chờ xử lý', Color(0xFFE0A11B));
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
