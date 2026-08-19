import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nineteen_tech_app/features/auth/providers/auth_notifier.dart';
import 'package:nineteen_tech_app/features/profile/screens/reward_leaderboard_screen.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/widgets/heart_header_badge.dart';
import '../data/hr_models.dart';
import '../providers/hr_providers.dart';

class HrOverviewScreen extends ConsumerStatefulWidget {
  const HrOverviewScreen({super.key});

  @override
  ConsumerState<HrOverviewScreen> createState() => _HrOverviewScreenState();
}

class _HrOverviewScreenState extends ConsumerState<HrOverviewScreen> {
  static const _overviewLeaderboardLimit = 5;
  static const _fullLeaderboardLimit = 100;
  static const _pendingRewardRedemptionStatus = 'pending';
  late DateTime _selectedDate;

  static const _overviewLeaderboardQuery = RewardsOverviewQuery(
    limit: _overviewLeaderboardLimit,
  );
  static const _fullLeaderboardQuery = RewardsOverviewQuery(
    limit: _fullLeaderboardLimit,
  );

  @override
  void initState() {
    super.initState();
    final config = ref
        .read(authNotifierProvider)
        .valueOrNull
        ?.payrollStartConfig;
    _selectedDate = resolveCurrentPayrollMonth(config ?? 1);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(DateTime.now().year - 2, 1, 1),
      lastDate: DateTime(DateTime.now().year + 2, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = picked);
  }

  void _openRewardItemsPage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const _RewardItemsPage()));
  }

  void _openAddPointsPage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const _AddPointsPage()));
  }

  void _openRedeemRequestsPage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const _RedeemRequestsPage()));
  }

  void _openOtHoursPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _EmployeeOtHoursPage(month: _selectedDate),
      ),
    );
  }

  void _openRewardTransactionHistory() {
    context.push('/employees');
  }

  void _openLeaderboardPage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RewardLeaderboardScreen()));
  }

  Future<void> _showSelfTopUpDialog() async {
    final currentUser = ref.read(authNotifierProvider).valueOrNull?.user;
    if (currentUser == null || currentUser.id.isEmpty) {
      if (!mounted) return;
      showTopSnackBar(context, message: 'Không tìm thấy tài khoản hiện tại');
      return;
    }
    final pointsAdded = await showDialog<int>(
      context: context,
      builder: (_) =>
          _SelfTopUpDialog(userId: currentUser.id, userName: currentUser.name),
    );
    if (!mounted || pointsAdded == null) return;
    ref.invalidate(rewardsOverviewProvider(_overviewLeaderboardQuery));
    ref.invalidate(rewardsOverviewProvider(_fullLeaderboardQuery));
    ref.invalidate(myRewardTransactionsProvider);
    await ref
        .read(authNotifierProvider.notifier)
        .resyncRewardWallet(force: true);
    if (!mounted) return;
    showTopSnackBar(
      context,
      message: 'Đã nạp $pointsAdded tym cho ${currentUser.name}',
    );
  }

  Future<void> _confirmAndResetRewardPoints() async {
    final palette = context.appPalette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: palette.surface,
          title: Text(
            'Reset toàn bộ điểm?',
            style: TextStyle(color: palette.textPrimary),
          ),
          content: Text(
            'Thao tác này sẽ đưa toàn bộ điểm và lịch sử giao dịch về trạng thái rỗng. Bạn có chắc muốn tiếp tục không?',
            style: TextStyle(color: palette.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(hrRepositoryProvider).resetAdminRewardPoints();
      ref.invalidate(rewardsOverviewProvider(_overviewLeaderboardQuery));
      ref.invalidate(rewardsOverviewProvider(_fullLeaderboardQuery));
      ref.invalidate(myRewardTransactionsProvider);
      ref.invalidate(myRewardRedemptionsProvider);
      ref.invalidate(
        rewardAdminRedemptionsProvider(_pendingRewardRedemptionStatus),
      );

      if (!mounted) return;
      showTopSnackBar(
        context,
        message: 'Đã reset toàn bộ điểm và lịch sử giao dịch',
      );
    } on DioException catch (error) {
      final message = error.response?.data is Map
          ? (error.response!.data as Map)['message']?.toString()
          : null;
      if (!mounted) return;
      showTopSnackBar(context, message: message ?? 'Không thể reset điểm');
    } catch (error) {
      if (!mounted) return;
      showTopSnackBar(context, message: '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    scheduleRewardWalletFreshnessCheck(ref);
    final leavesAsync = ref.watch(hrOverviewLeavesProvider);
    final rewardsOverviewAsync = ref.watch(
      rewardsOverviewProvider(_overviewLeaderboardQuery),
    );
    final pendingRedemptionsAsync = ref.watch(
      rewardAdminRedemptionsProvider(_pendingRewardRedemptionStatus),
    );
    final isWide = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      body: SafeArea(
        child: leavesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _HrOverviewErrorState(
            message: '$error',
            onRetry: () => ref.invalidate(hrOverviewLeavesProvider),
          ),
          data: (leaves) {
            final content = RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(hrOverviewLeavesProvider);
                ref.invalidate(
                  rewardsOverviewProvider(_overviewLeaderboardQuery),
                );
                ref.invalidate(
                  rewardAdminRedemptionsProvider(
                    _pendingRewardRedemptionStatus,
                  ),
                );
                await ref.read(hrOverviewLeavesProvider.future);
                await ref.read(
                  rewardsOverviewProvider(_overviewLeaderboardQuery).future,
                );
                await ref.read(
                  rewardAdminRedemptionsProvider(
                    _pendingRewardRedemptionStatus,
                  ).future,
                );
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  isWide ? 28 : 16,
                  18,
                  isWide ? 28 : 16,
                  28,
                ),
                children: [
                  _OverviewHeader(
                    selectedDate: _selectedDate,
                    onPickDate: _pickDate,
                  ),
                  const SizedBox(height: 12),
                  _AdminOverviewActions(
                    onItemsPressed: _openRewardItemsPage,
                    onAddPointsPressed: _openAddPointsPage,
                    onSelfTopUpPressed: _showSelfTopUpDialog,
                    onEmployeesPressed: _openRewardTransactionHistory,
                    onHistoryPressed: _openRewardTransactionHistory,
                    onRequestsPressed: _openRedeemRequestsPage,
                    onResetPointsPressed: _confirmAndResetRewardPoints,
                  ),
                  // const SizedBox(height: 18),
                  // _OtHoursPreviewCard(
                  //   month: _selectedDate,
                  //   onSeeMore: _openOtHoursPage,
                  // ),
                  // const SizedBox(height: 18),
                  _HrOverviewSection(
                    title: 'Bảng xếp hạng nhân viên',
                    trailing: TextButton(
                      onPressed: _openLeaderboardPage,
                      child: const Text('Xem thêm'),
                    ),
                    child: _EmployeeRankingSection(
                      rankingsAsync: rewardsOverviewAsync.whenData(
                        (value) => value.leaderboard,
                      ),
                      onRetry: () => ref.invalidate(
                        rewardsOverviewProvider(_overviewLeaderboardQuery),
                      ),
                      maxItems: _overviewLeaderboardLimit,
                    ),
                  ),
                  // const SizedBox(height: 18),
                  // _HrOverviewSection(
                  //   title: 'Tổng quan nhanh',
                  //   child: _OverviewMetricCarousel(
                  //     cards: [
                  //       const _OverviewMetricCardData(
                  //         value: '--',
                  //         label: 'Tổng nhân sự',
                  //         helper: 'Cần API tổng hợp',
                  //         color: AppColors.info,
                  //       ),
                  //       const _OverviewMetricCardData(
                  //         value: '--',
                  //         label: 'Đã chấm công',
                  //         helper: 'Chưa có dữ liệu ngày',
                  //         color: AppColors.online,
                  //       ),
                  //       const _OverviewMetricCardData(
                  //         value: '--',
                  //         label: 'Chưa chấm công',
                  //         helper: 'Chưa có dữ liệu ngày',
                  //         color: AppColors.danger,
                  //       ),
                  //       _OverviewMetricCardData(
                  //         value: '${data.pendingRequests.length}',
                  //         label: 'Đơn chờ duyệt',
                  //         helper:
                  //             '${data.pendingLeaveCount} phép · ${data.pendingOtCount} OT',
                  //         color: palette.primary,
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  const SizedBox(height: 18),
                  _HrOverviewSection(
                    title: 'Yêu cầu chờ duyệt',
                    trailing: TextButton(
                      onPressed: _openRedeemRequestsPage,
                      child: const Text('Xem tất cả'),
                    ),
                    child: _PendingApprovalSection(
                      pendingRequestsAsync: pendingRedemptionsAsync,
                      onRetry: () => ref.invalidate(
                        rewardAdminRedemptionsProvider(
                          _pendingRewardRedemptionStatus,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // _HrOverviewSection(
                  //   title: 'Chấm công hôm nay',

                  //   child: _AttendanceInsightsPlaceholder(
                  //     selectedDate: _selectedDate,
                  //   ),
                  // ),
                  // const SizedBox(height: 18),
                  // _HrOverviewSection(
                  //   title: 'Báo cáo nhanh',
                  //   child: _OverviewMetricCarousel(
                  //     cards: [
                  //       _OverviewMetricCardData(
                  //         value:
                  //             '${_formatCompactNumber(data.approvedLeaveDays)} ngày',
                  //         label: 'Phép đã duyệt',
                  //         helper: _monthLabel(_selectedDate),
                  //         color: AppColors.online,
                  //         icon: Icons.event_available_outlined,
                  //       ),
                  //       _OverviewMetricCardData(
                  //         value:
                  //             '${_formatCompactNumber(data.pendingOtHours)}h',
                  //         label: 'OT chờ duyệt',
                  //         helper: '${data.pendingOtCount} đơn OT',
                  //         color: AppColors.warning,
                  //         icon: Icons.more_time_outlined,
                  //       ),
                  //       _OverviewMetricCardData(
                  //         value: '${data.resolvedCount}',
                  //         label: 'Đã xử lý',
                  //         helper:
                  //             '${data.approvedCount} duyệt · ${data.rejectedCount} từ chối',
                  //         color: palette.primary,
                  //         icon: Icons.fact_check_outlined,
                  //       ),
                  //     ],
                  //   ),
                  // ),
                ],
              ),
            );

            if (isWide) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: content,
                ),
              );
            }
            return content;
          },
        ),
      ),
    );
  }
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({required this.selectedDate, required this.onPickDate});

  final DateTime selectedDate;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Row(
      children: [
        Expanded(
          child: Text(
            'Tổng quan',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onPickDate,
          icon: Icon(Icons.calendar_today_outlined, color: palette.primary),
          label: Text(
            _fullDateLabel(selectedDate),
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: palette.surface,
            side: BorderSide(color: palette.surfaceVariant),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _AdminOverviewActions extends ConsumerWidget {
  const _AdminOverviewActions({
    required this.onItemsPressed,
    required this.onAddPointsPressed,
    required this.onSelfTopUpPressed,
    required this.onEmployeesPressed,
    required this.onHistoryPressed,
    required this.onRequestsPressed,
    required this.onResetPointsPressed,
  });

  final VoidCallback onItemsPressed;
  final VoidCallback onAddPointsPressed;
  final VoidCallback onSelfTopUpPressed;
  final VoidCallback onEmployeesPressed;
  final VoidCallback onHistoryPressed;
  final VoidCallback onRequestsPressed;
  final VoidCallback onResetPointsPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appPalette;
    final itemCount = ref.watch(
      rewardAdminItemsProvider.select(
        (value) => value.valueOrNull?.length ?? 0,
      ),
    );
    final employeeCount = ref.watch(
      rewardAdminEmployeesProvider.select(
        (value) => value.valueOrNull?.length ?? 0,
      ),
    );
    final pendingRedemptions = ref.watch(
      rewardAdminRedemptionsProvider(
        _HrOverviewScreenState._pendingRewardRedemptionStatus,
      ).select((value) => value.valueOrNull?.length ?? 0),
    );
    final currentPoints =
        ref.watch(authNotifierProvider).valueOrNull?.points ?? 0;

    final cards = [
      (
        icon: Icons.inventory_2_outlined,
        title: 'Vật phẩm',
        value: '$itemCount',
        onPressed: onItemsPressed,
      ),
      (
        icon: Icons.exposure_plus_1_rounded,
        title: 'Thay đổi điểm',
        value: '$employeeCount',
        onPressed: onAddPointsPressed,
      ),
      (
        icon: Icons.favorite_rounded,
        title: 'Nạp tym',
        value: formatHeartPoints(currentPoints),
        onPressed: onSelfTopUpPressed,
      ),
      (
        icon: Icons.badge_outlined,
        title: 'Nhân sự',
        value: 'MVP',
        onPressed: onEmployeesPressed,
      ),
      (
        icon: Icons.redeem_outlined,
        title: 'Yêu cầu đổi quà',
        value: '$pendingRedemptions',
        onPressed: onRequestsPressed,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      // decoration: BoxDecoration(
      //   borderRadius: BorderRadius.circular(28),
      //   border: Border.all(color: palette.surfaceVariant.withValues(alpha: 0.9)),
      //   gradient: LinearGradient(
      //     begin: Alignment.topLeft,
      //     end: Alignment.bottomRight,
      //     colors: [
      //       palette.card.withValues(alpha: 0.96),
      //       palette.surface.withValues(alpha: 0.92),
      //     ],
      //   ),
      // ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Công cụ quản lý',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // TextButton.icon(
              //   onPressed: onHistoryPressed,
              //   icon: const Icon(Icons.history_rounded, size: 18),
              //   label: const Text('Lịch sử điểm'),
              // ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final spacing = 8.0;
              final rawWidth = (constraints.maxWidth - (spacing * 3)) / 4;
              final cardWidth = rawWidth.clamp(74.0, 120.0);

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final card in cards)
                    SizedBox(
                      width: cardWidth,
                      child: _AdminStatActionCard(
                        icon: card.icon,
                        title: card.title,
                        value: card.value,
                        onPressed: card.onPressed,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _AdminResetTile(onPressed: onResetPointsPressed),
        ],
      ),
    );
  }
}

class _AdminStatActionCard extends StatelessWidget {
  const _AdminStatActionCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onPressed,
        child: Container(
          // height: 136,
          // padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          // decoration: BoxDecoration(
          //   borderRadius: BorderRadius.circular(22),
          //   border: Border.all(
          //     color: palette.surfaceVariant.withValues(alpha: 0.82),
          //   ),
          //   gradient: LinearGradient(
          //     begin: Alignment.topCenter,
          //     end: Alignment.bottomCenter,
          //     colors: [
          //       palette.surface.withValues(alpha: 0.9),
          //       palette.card.withValues(alpha: 0.98),
          //     ],
          //   ),
          // ),
          child: Column(
            children: [
              Icon(icon, size: 24, color: palette.primary),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              // const Spacer(),
              // Text(
              //   value,
              //   style: TextStyle(
              //     color: palette.textPrimary,
              //     fontSize: 23,
              //     fontWeight: FontWeight.w500,
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminResetTile extends StatelessWidget {
  const _AdminResetTile({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: Container(
          // padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                // width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.danger.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.restart_alt_rounded,
                  color: AppColors.danger,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reset điểm',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    // const SizedBox(height: 4),
                    // Text(
                    //   'Mỗi tháng 1 lần',
                    //   style: TextStyle(
                    //     color: palette.textSecondary,
                    //     fontSize: 14,
                    //   ),
                    // ),
                  ],
                ),
              ),

              // Icon(
              //   Icons.chevron_right_rounded,
              //   color: palette.textSecondary,
              //   size: 28,
              // ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HrOverviewSection extends StatelessWidget {
  const _HrOverviewSection({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final trailingWidgets = trailing == null
        ? const <Widget>[]
        : <Widget>[trailing!];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        // color: palette.surface,
        // borderRadius: BorderRadius.circular(24),
        // border: Border.all(
        //   color: palette.surfaceVariant.withValues(alpha: 0.9),
        // ),
        // boxShadow: [
        //   if (palette.isLight)
        //     BoxShadow(
        //       color: Colors.black.withValues(alpha: 0.04),
        //       blurRadius: 22,
        //       offset: const Offset(0, 10),
        //     ),
        // ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ...trailingWidgets,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _OtHoursPreviewCard extends ConsumerWidget {
  const _OtHoursPreviewCard({required this.month, required this.onSeeMore});

  final DateTime month;
  final VoidCallback onSeeMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appPalette;
    final config = ref
        .read(authNotifierProvider)
        .valueOrNull
        ?.payrollStartConfig;
    final startDay = config ?? 1;
    final range = _buildOtSummaryRange(month, startDay);
    final query = EmployeeOtSummaryQuery(
      from: _formatApiDate(range.start),
      to: _formatApiDate(range.end),
    );
    final otSummaryAsync = ref.watch(employeeOtSummaryProvider(query));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: palette.surfaceVariant.withValues(alpha: 0.9),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.card.withValues(alpha: 0.96),
            palette.surface.withValues(alpha: 0.92),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Giờ OT theo nhân viên',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(onPressed: onSeeMore, child: const Text('Xem thêm')),
            ],
          ),
          // const SizedBox(height: 4),
          // Text(
          //   '(giờ)',
          //   style: TextStyle(
          //     color: palette.textSecondary,
          //     fontSize: 14,
          //   ),
          // ),
          const SizedBox(height: 12),
          otSummaryAsync.when(
            loading: () => const SizedBox(
              height: 244,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SizedBox(
              height: 244,
              child: _HrOverviewErrorState(
                message: '$error',
                onRetry: () => ref.invalidate(employeeOtSummaryProvider(query)),
              ),
            ),
            data: (items) {
              final totalOtHours = items.fold<double>(
                0,
                (sum, item) => sum + item.totalOt,
              );
              final stats = items
                  .take(4)
                  .map(
                    (item) => _EmployeeOtStats(
                      name: item.name,
                      approvedHours: item.totalOt,
                      pendingHours: 0,
                    ),
                  )
                  .toList(growable: false);

              if (stats.isEmpty) {
                return const SizedBox(
                  height: 244,
                  child: _OverviewEmptyState(
                    icon: Icons.schedule_outlined,
                    title: 'Chưa có dữ liệu OT',
                    description: 'Khi có OT trong kỳ, biểu đồ sẽ hiện ở đây.',
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _formatHourCompact(totalOtHours),
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'tổng OT toàn bộ',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _OtHoursBarChart(stats: stats),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OtHoursBarChart extends StatelessWidget {
  const _OtHoursBarChart({required this.stats});

  final List<_EmployeeOtStats> stats;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final maxHours = stats.fold<double>(
      0,
      (max, item) => math.max(max, item.totalHours),
    );
    final axisMax = math.max(5.0, (maxHours / 5).ceil() * 5.0);
    final ticks = List<double>.generate(
      5,
      (index) => axisMax * (4 - index) / 4,
    );

    return SizedBox(
      height: 244,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final tick in ticks)
                  Text(
                    _formatTick(tick),
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const topPadding = 12.0;
                const labelHeight = 44.0;
                const valueHeight = 20.0;
                const verticalSpacing = 28.0;
                final chartHeight =
                    constraints.maxHeight -
                    labelHeight -
                    topPadding -
                    valueHeight -
                    verticalSpacing;

                return Stack(
                  children: [
                    Positioned.fill(
                      top: topPadding,
                      bottom: labelHeight,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (var index = 0; index < 5; index++)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: palette.surfaceVariant.withValues(
                                alpha: 0.55,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < stats.length; i++) ...[
                          Expanded(
                            child: _OtBarItem(
                              stat: stats[i],
                              axisMax: axisMax,
                              chartHeight: chartHeight,
                            ),
                          ),
                          if (i != stats.length - 1) const SizedBox(width: 18),
                        ],
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OtBarItem extends StatelessWidget {
  const _OtBarItem({
    required this.stat,
    required this.axisMax,
    required this.chartHeight,
  });

  final _EmployeeOtStats stat;
  final double axisMax;
  final double chartHeight;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final ratio = axisMax <= 0
        ? 0.0
        : (stat.totalHours / axisMax).clamp(0.0, 1.0);
    final barHeight = math.max(6.0, chartHeight * ratio);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          stat.totalHours.toStringAsFixed(1),
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 54,
          height: barHeight,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                palette.primary,
                palette.primary.withValues(alpha: 0.78),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: palette.primary.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 34,
          child: Text(
            _shortEmployeeName(stat.name),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 12.5,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _OverviewMetricCarousel extends StatelessWidget {
  const _OverviewMetricCarousel({required this.cards});

  final List<_OverviewMetricCardData> cards;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 768;
    final cardWidth = isWide ? 210.0 : 172.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < cards.length; index++) ...[
            SizedBox(
              width: cardWidth,
              child: _OverviewMetricCard(data: cards[index]),
            ),
            if (index != cards.length - 1) const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

class _OverviewMetricCard extends StatelessWidget {
  const _OverviewMetricCard({required this.data});

  final _OverviewMetricCardData data;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.surfaceVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.icon != null) ...[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(data.icon, color: data.color, size: 20),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            data.value,
            style: TextStyle(
              color: data.color,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data.label,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.helper,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardItemTile extends StatelessWidget {
  const _RewardItemTile({required this.item, required this.onTap});

  final RewardAdminItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: palette.surfaceVariant.withValues(alpha: 0.82),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                      ? Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _RewardTileImageFallback(color: palette.primary),
                        )
                      : _RewardTileImageFallback(color: palette.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                        height: 1.35,
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
                    '${item.pointsCost}',
                    style: TextStyle(
                      color: palette.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Còn ${item.stockRemaining}',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: palette.textHint,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardTileImageFallback extends StatelessWidget {
  const _RewardTileImageFallback({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Icon(Icons.card_giftcard_rounded, color: color, size: 22),
    );
  }
}

class _RedeemRequestTile extends ConsumerStatefulWidget {
  const _RedeemRequestTile({required this.redemption, this.compact = false});

  final RewardRedemption redemption;
  final bool compact;

  @override
  ConsumerState<_RedeemRequestTile> createState() => _RedeemRequestTileState();
}

class _RedeemRequestTileState extends ConsumerState<_RedeemRequestTile> {
  bool _isSubmitting = false;

  Future<void> _process(String status) async {
    if (_isSubmitting) return;

    final defaultNote = status == 'approved'
        ? 'Đã duyệt yêu cầu đổi quà'
        : 'Từ chối yêu cầu đổi quà';
    final note = await _showProcessRedemptionDialog(
      context,
      title: status == 'approved' ? 'Duyệt yêu cầu' : 'Từ chối yêu cầu',
      initialNote: defaultNote,
      confirmLabel: status == 'approved' ? 'Duyệt' : 'Từ chối',
    );
    if (note == null) return;

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(hrRepositoryProvider)
          .processAdminRewardRedemption(
            id: widget.redemption.id,
            status: status,
            processedNote: note,
          );

      ref.invalidate(
        rewardAdminRedemptionsProvider(
          _HrOverviewScreenState._pendingRewardRedemptionStatus,
        ),
      );
      ref.invalidate(myRewardRedemptionsProvider);

      if (!mounted) return;
      showTopSnackBar(
        context,
        message: status == 'approved'
            ? 'Đã duyệt yêu cầu đổi quà'
            : 'Đã từ chối yêu cầu đổi quà',
      );
    } on DioException catch (error) {
      final message = error.response?.data is Map
          ? (error.response!.data as Map)['message']?.toString()
          : null;
      if (!mounted) return;
      showTopSnackBar(context, message: message ?? 'Xử lý yêu cầu thất bại');
    } catch (error) {
      if (!mounted) return;
      showTopSnackBar(context, message: '$error');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final redemption = widget.redemption;
    final item = redemption.rewardItem;
    final statusColor = switch (redemption.status) {
      'approved' => AppColors.online,
      'rejected' => AppColors.danger,
      _ => AppColors.warning,
    };
    final statusLabel = switch (redemption.status) {
      'approved' => 'Đã duyệt',
      'rejected' => 'Từ chối',
      _ => 'Chờ xử lý',
    };
    final requesterName = _redemptionRequesterLabel(redemption);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.surfaceVariant.withValues(alpha: 0.82),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InitialAvatar(name: requesterName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requesterName,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item?.name ?? 'Phần quà',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SL ${redemption.quantity} • ${formatHeartPoints(redemption.totalPointsCost)} tym',
                      style: TextStyle(
                        color: palette.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StatusPill(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _rewardRedemptionMetaLine(redemption),
            style: TextStyle(color: palette.textSecondary, fontSize: 12),
          ),
          if ((redemption.requestedNote ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Ghi chú user: ${redemption.requestedNote!.trim()}',
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          if ((redemption.processedNote ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Ghi chú xử lý: ${redemption.processedNote!.trim()}',
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          if (redemption.status == 'pending') ...[
            SizedBox(height: widget.compact ? 12 : 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => _process('rejected'),
                    child: const Text('Từ chối'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => _process('approved'),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Duyệt'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminInputField extends StatelessWidget {
  const _AdminInputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: _adminFieldDecoration(context, label: label, hint: hint),
    );
  }
}

class _RewardImageUploadField extends StatelessWidget {
  const _RewardImageUploadField({
    required this.imageUrl,
    required this.isUploading,
    required this.onPressed,
  });

  final String? imageUrl;
  final bool isUploading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasImage ? palette.primary : palette.surfaceVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ảnh vật phẩm',
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (hasImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: palette.surfaceVariant.withValues(alpha: 0.35),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: palette.textHint,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  hasImage ? 'Ảnh đã được upload' : 'Chưa có ảnh nào được chọn',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: isUploading ? null : onPressed,
                icon: isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        hasImage
                            ? Icons.refresh_rounded
                            : Icons.cloud_upload_outlined,
                      ),
                label: Text(isUploading ? 'Đang upload...' : 'Chọn ảnh'),
              ),
            ],
          ),
          if (hasImage) ...[
            const SizedBox(height: 8),
            Text(
              imageUrl!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textHint, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _RewardItemsPage extends ConsumerWidget {
  const _RewardItemsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(rewardAdminItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vật phẩm'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: FilledButton.icon(
                onPressed: () async {
                  final created = await Navigator.of(context)
                      .push<RewardAdminItem>(
                        MaterialPageRoute(
                          builder: (_) => const _CreateRewardItemPage(),
                        ),
                      );
                  if (created != null) {
                    ref.invalidate(rewardAdminItemsProvider);
                  }
                },
                icon: const Icon(Icons.add_box_outlined, size: 18),
                label: const Text('Tạo vật phẩm'),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(rewardAdminItemsProvider);
          await ref.read(rewardAdminItemsProvider.future);
        },
        child: itemsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _HrOverviewErrorState(
                message: '$error',
                onRetry: () => ref.invalidate(rewardAdminItemsProvider),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: const [
                  _OverviewEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Chưa có vật phẩm',
                    description:
                        'Tạo vật phẩm đầu tiên để người dùng có thể đổi điểm.',
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) => _RewardItemTile(
                item: items[index],
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _RewardItemDetailPage(item: items[index]),
                    ),
                  );
                },
              ),
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemCount: items.length,
            );
          },
        ),
      ),
    );
  }
}

class _CreateRewardItemPage extends ConsumerStatefulWidget {
  const _CreateRewardItemPage({this.initialItem});

  final RewardAdminItem? initialItem;

  @override
  ConsumerState<_CreateRewardItemPage> createState() =>
      _CreateRewardItemPageState();
}

class _CreateRewardItemPageState extends ConsumerState<_CreateRewardItemPage> {
  static const _categories = ['gift', 'food', 'office', 'other'];

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pointsController = TextEditingController();
  final _stockController = TextEditingController(text: '10');
  final _sortOrderController = TextEditingController(text: '1');
  final _imagePicker = ImagePicker();

  String _selectedCategory = _categories.first;
  String? _uploadedImageUrl;
  bool _isActive = true;
  bool _isSubmitting = false;
  bool _isUploadingImage = false;
  String? _errorText;

  bool get _isEditMode => widget.initialItem != null;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    if (item == null) return;
    _nameController.text = item.name;
    _descriptionController.text = item.description;
    _pointsController.text = item.pointsCost.toString();
    _stockController.text = item.stockTotal.toString();
    _sortOrderController.text = item.sortOrder.toString();
    _selectedCategory = item.category;
    _uploadedImageUrl = item.imageUrl;
    _isActive = item.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _pointsController.dispose();
    _stockController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    if (_isSubmitting || _isUploadingImage) return;

    setState(() {
      _isUploadingImage = true;
      _errorText = null;
    });

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (image == null) {
        if (!mounted) return;
        setState(() => _isUploadingImage = false);
        return;
      }

      final uploadedUrl = await ref
          .read(hrRepositoryProvider)
          .uploadRewardItemImage(image);

      if (!mounted) return;
      setState(() {
        _uploadedImageUrl = uploadedUrl;
      });
      showTopSnackBar(context, message: 'Đã upload ảnh vật phẩm');
    } on DioException catch (error) {
      final message = error.response?.data is Map
          ? (error.response!.data as Map)['message']?.toString()
          : null;
      if (!mounted) return;
      setState(() {
        _errorText = message ?? 'Upload ảnh thất bại.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final pointsCost = int.tryParse(_pointsController.text.trim());
    final stockTotal = int.tryParse(_stockController.text.trim());
    final sortOrder = int.tryParse(_sortOrderController.text.trim()) ?? 1;

    if (name.isEmpty ||
        description.isEmpty ||
        (_uploadedImageUrl == null || _uploadedImageUrl!.trim().isEmpty) ||
        pointsCost == null ||
        pointsCost <= 0 ||
        stockTotal == null ||
        stockTotal < 0) {
      setState(() {
        _errorText = 'Vui lòng nhập đầy đủ thông tin và kiểm tra lại số liệu.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final repo = ref.read(hrRepositoryProvider);
      final RewardAdminItem savedItem;
      if (_isEditMode) {
        savedItem = await repo.updateAdminRewardItem(
          id: widget.initialItem!.id,
          name: name,
          description: description,
          imageUrl: _uploadedImageUrl!.trim(),
          pointsCost: pointsCost,
          stockTotal: stockTotal,
          isActive: _isActive,
          sortOrder: sortOrder,
          category: _selectedCategory,
        );
      } else {
        savedItem = await repo.createAdminRewardItem(
          name: name,
          description: description,
          imageUrl: _uploadedImageUrl!.trim(),
          pointsCost: pointsCost,
          stockTotal: stockTotal,
          isActive: _isActive,
          sortOrder: sortOrder,
          category: _selectedCategory,
        );
      }
      ref.invalidate(rewardAdminItemsProvider);
      if (!mounted) return;
      showTopSnackBar(
        context,
        message: _isEditMode
            ? 'Đã cập nhật vật phẩm "$name"'
            : 'Đã tạo vật phẩm "$name"',
      );
      Navigator.of(context).pop(savedItem);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = '$error';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Chỉnh sửa vật phẩm' : 'Tạo vật phẩm'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AdminInputField(
            controller: _nameController,
            label: 'Tên vật phẩm',
            hint: 'Ví dụ: Bình nước 19T',
          ),
          const SizedBox(height: 12),
          _AdminInputField(
            controller: _descriptionController,
            label: 'Mô tả',
            hint: 'Mô tả ngắn về vật phẩm',
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          _RewardImageUploadField(
            imageUrl: _uploadedImageUrl,
            isUploading: _isUploadingImage,
            onPressed: _pickAndUploadImage,
          ),
          const SizedBox(height: 12),
          _AdminInputField(
            controller: _pointsController,
            label: 'Số điểm đổi',
            hint: 'Ví dụ: 100',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          _AdminInputField(
            controller: _stockController,
            label: 'Số lượng tồn',
            hint: 'Ví dụ: 50',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          _AdminInputField(
            controller: _sortOrderController,
            label: 'Thứ tự hiển thị',
            hint: 'Ví dụ: 1',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            decoration: _adminFieldDecoration(
              context,
              label: 'Danh mục',
              hint: 'Chọn danh mục vật phẩm',
            ),
            items: _categories
                .map(
                  (category) => DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  ),
                )
                .toList(),
            onChanged: _isSubmitting
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _selectedCategory = value);
                  },
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            value: _isActive,
            onChanged: _isSubmitting
                ? null
                : (value) => setState(() => _isActive = value),
            title: const Text('Kích hoạt vật phẩm'),
            contentPadding: EdgeInsets.zero,
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Text(_errorText!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _isEditMode ? Icons.edit_outlined : Icons.add_box_outlined,
                  ),
            label: Text(
              _isSubmitting
                  ? (_isEditMode ? 'Đang cập nhật...' : 'Đang tạo...')
                  : (_isEditMode ? 'Cập nhật vật phẩm' : 'Tạo vật phẩm'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardItemDetailPage extends ConsumerStatefulWidget {
  const _RewardItemDetailPage({required this.item});

  final RewardAdminItem item;

  @override
  ConsumerState<_RewardItemDetailPage> createState() =>
      _RewardItemDetailPageState();
}

class _RewardItemDetailPageState extends ConsumerState<_RewardItemDetailPage> {
  late RewardAdminItem _item;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  Future<void> _deleteItem() async {
    if (_isDeleting) return;

    final palette = context.appPalette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: palette.surface,
          title: Text(
            'Xóa vật phẩm?',
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Vật phẩm "${_item.name}" sẽ bị xóa vĩnh viễn. Bạn có chắc muốn tiếp tục không?',
            style: TextStyle(color: palette.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      await ref.read(hrRepositoryProvider).deleteAdminRewardItem(_item.id);
      ref.invalidate(rewardAdminItemsProvider);
      if (!mounted) return;
      showTopSnackBar(context, message: 'Đã xóa vật phẩm "${_item.name}"');
      Navigator.of(context).pop(true);
    } on DioException catch (error) {
      final message = error.response?.data is Map
          ? (error.response!.data as Map)['message']?.toString()
          : null;
      if (!mounted) return;
      setState(() => _isDeleting = false);
      showTopSnackBar(context, message: message ?? 'Không thể xóa vật phẩm');
    } catch (error) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      showTopSnackBar(context, message: '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Scaffold(
      appBar: AppBar(
        // title: const Text('Chi tiết vật phẩm'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: OutlinedButton.icon(
                onPressed: _isDeleting
                    ? null
                    : () async {
                        final updatedItem = await Navigator.of(context)
                            .push<RewardAdminItem>(
                              MaterialPageRoute(
                                builder: (_) =>
                                    _CreateRewardItemPage(initialItem: _item),
                              ),
                            );
                        if (updatedItem == null || !mounted) return;
                        setState(() => _item = updatedItem);
                        ref.invalidate(rewardAdminItemsProvider);
                      },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Chỉnh sửa'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: OutlinedButton.icon(
                onPressed: _isDeleting ? null : _deleteItem,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
                icon: _isDeleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(_isDeleting ? 'Đang xóa...' : 'Xóa'),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: palette.surfaceVariant.withValues(alpha: 0.82),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: _item.imageUrl != null && _item.imageUrl!.isNotEmpty
                        ? Image.network(
                            _item.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const _RewardDetailImageFallback(
                                  icon: Icons.broken_image_outlined,
                                ),
                          )
                        : const _RewardDetailImageFallback(
                            icon: Icons.card_giftcard_rounded,
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _item.name,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _item.description.isEmpty
                            ? 'Chưa có mô tả cho vật phẩm này.'
                            : _item.description,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _RewardInfoChip(
                            label: 'Điểm đổi',
                            value: '${_item.pointsCost} tym',
                          ),
                          _RewardInfoChip(
                            label: 'Tồn kho',
                            value:
                                '${_item.stockRemaining}/${_item.stockTotal}',
                          ),
                          _RewardInfoChip(
                            label: 'Danh mục',
                            value: _item.category,
                          ),
                          _RewardInfoChip(
                            label: 'Trạng thái',
                            value: _item.isActive ? 'Đang bật' : 'Đã tắt',
                          ),
                          _RewardInfoChip(
                            label: 'Thứ tự',
                            value: '${_item.sortOrder}',
                          ),
                        ],
                      ),
                      // if (_item.imageUrl != null &&
                      //     _item.imageUrl!.isNotEmpty) ...[
                      //   const SizedBox(height: 18),
                      //   Text(
                      //     'URL ảnh',
                      //     style: TextStyle(
                      //       color: palette.textPrimary,
                      //       fontSize: 13,
                      //       fontWeight: FontWeight.w700,
                      //     ),
                      //   ),
                      //   const SizedBox(height: 6),
                      //   SelectableText(
                      //     _item.imageUrl!,
                      //     style: TextStyle(
                      //       color: palette.textHint,
                      //       fontSize: 12,
                      //       height: 1.4,
                      //     ),
                      //   ),
                      // ],
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

class _RewardDetailImageFallback extends StatelessWidget {
  const _RewardDetailImageFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Container(
      color: palette.primary.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: Icon(icon, color: palette.primary, size: 48),
    );
  }
}

class _RewardInfoChip extends StatelessWidget {
  const _RewardInfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      // decoration: BoxDecoration(
      //   color: palette.surfaceVariant.withValues(alpha: 0.35),
      //   borderRadius: BorderRadius.circular(14),
      // ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPointsPage extends ConsumerStatefulWidget {
  const _AddPointsPage();

  @override
  ConsumerState<_AddPointsPage> createState() => _AddPointsPageState();
}

class _AddPointsPageState extends ConsumerState<_AddPointsPage> {
  final _pointController = TextEditingController();
  final _noteController = TextEditingController();
  RewardAdminEmployee? _selectedEmployee;
  String? _errorText;
  bool _didRequestEmployees = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pointController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final points = int.tryParse(_pointController.text.trim());
    final selectedEmployee = _selectedEmployee;

    if (selectedEmployee == null) {
      setState(() {
        _errorText = 'Vui lòng chọn nhân viên.';
      });
      return;
    }

    if (!_isValidUuid(selectedEmployee.id)) {
      setState(() {
        _errorText = 'Nhân viên được chọn không có `user_id` hợp lệ.';
      });
      return;
    }

    if (points == null) {
      setState(() {
        _errorText = 'Không để trống số điểm.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await ref
          .read(hrRepositoryProvider)
          .grantAdminRewardPoints(
            userId: selectedEmployee.id,
            points: points,
            note: _noteController.text,
          );
      ref.invalidate(
        rewardsOverviewProvider(
          _HrOverviewScreenState._overviewLeaderboardQuery,
        ),
      );
      ref.invalidate(
        rewardsOverviewProvider(_HrOverviewScreenState._fullLeaderboardQuery),
      );
      if (!mounted) return;
      showTopSnackBar(
        context,
        message: 'Đã cộng $points điểm cho ${selectedEmployee.name}',
      );
      Navigator.of(context).pop(true);
    } on DioException catch (error) {
      final message = error.response?.data is Map
          ? (error.response!.data as Map)['message']?.toString()
          : null;
      if (!mounted) return;
      setState(() {
        _errorText = message ?? 'Cộng điểm thất bại.';
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

  Future<List<RewardAdminEmployee>> _loadEmployees() async {
    final currentEmployeesState = ref.read(rewardAdminEmployeesProvider);
    if (_didRequestEmployees && !currentEmployeesState.hasError) {
      return ref.read(rewardAdminEmployeesProvider).valueOrNull ??
          const <RewardAdminEmployee>[];
    }

    if (!_didRequestEmployees) {
      setState(() => _didRequestEmployees = true);
    } else {
      ref.invalidate(rewardAdminEmployeesProvider);
    }

    try {
      final employees = await ref.read(rewardAdminEmployeesProvider.future);
      if (!mounted) return employees;
      if (employees.isNotEmpty && _selectedEmployee == null) {
        setState(() => _selectedEmployee = employees.first);
      }
      return employees;
    } catch (_) {
      if (!mounted) return const <RewardAdminEmployee>[];
      setState(() {});
      rethrow;
    }
  }

  Future<void> _openEmployeePicker() async {
    if (_isSubmitting) return;

    setState(() => _errorText = null);

    try {
      final employees = await _loadEmployees();
      if (!mounted || employees.isEmpty) return;

      final selectedEmployeeId = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: context.appPalette.surface,
        builder: (context) {
          final palette = context.appPalette;
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Chọn người được cộng điểm',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: employees.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: palette.surfaceVariant),
                    itemBuilder: (context, index) {
                      final employee = employees[index];
                      final isSelected = employee.id == _selectedEmployee?.id;
                      return ListTile(
                        title: Text(employee.name),
                        trailing: isSelected
                            ? Icon(Icons.check, color: palette.primary)
                            : null,
                        onTap: () => Navigator.of(context).pop(employee.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (!mounted || selectedEmployeeId == null) return;

      setState(() {
        _selectedEmployee = employees
            .where((employee) => employee.id == selectedEmployeeId)
            .firstOrNull;
      });
    } on DioException catch (error) {
      final message = error.response?.data is Map
          ? (error.response!.data as Map)['message']?.toString()
          : null;
      if (!mounted) return;
      setState(() {
        _errorText = message ?? 'Không tải được danh sách nhân viên.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = _didRequestEmployees
        ? ref.watch(rewardAdminEmployeesProvider)
        : const AsyncValue<List<RewardAdminEmployee>>.data(
            <RewardAdminEmployee>[],
          );
    final employees =
        employeesAsync.valueOrNull ?? const <RewardAdminEmployee>[];
    final isLoadingEmployees = employeesAsync.isLoading;
    final employeesError = employeesAsync.hasError
        ? employeesAsync.error.toString()
        : null;

    if (_selectedEmployee == null && employees.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _selectedEmployee != null) return;
        setState(() => _selectedEmployee = employees.first);
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Cộng/Trừ điểm')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AdminInputField(
            controller: _pointController,
            label: 'Nhập số điểm',
            hint: 'Ví dụ: 50',
            keyboardType: const TextInputType.numberWithOptions(signed: true),
          ),
          const SizedBox(height: 12),
          _AdminInputField(
            controller: _noteController,
            label: 'Lý do',
            hint: 'Nhập lý do cộng điểm',
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: isLoadingEmployees ? null : _openEmployeePicker,
            child: InputDecorator(
              decoration:
                  _adminFieldDecoration(
                    context,
                    label: 'Người thay đổi',
                  ).copyWith(
                    suffixIcon: isLoadingEmployees
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
              child: Text(
                _selectedEmployee?.name ?? 'Nhấn để chọn nhân viên',
                style: TextStyle(
                  color: _selectedEmployee == null
                      ? context.appPalette.textSecondary
                      : context.appPalette.textPrimary,
                ),
              ),
            ),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Text(_errorText!, style: const TextStyle(color: AppColors.danger)),
          ],
          if (employeesError != null) ...[
            const SizedBox(height: 12),
            Text(
              'Không tải được danh sách nhân viên: $employeesError',
              style: const TextStyle(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed:
                _selectedEmployee == null || isLoadingEmployees || _isSubmitting
                ? null
                : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Xác nhận cộng điểm'),
          ),
          if (_didRequestEmployees &&
              !isLoadingEmployees &&
              employeesError == null &&
              employees.isEmpty) ...[
            const SizedBox(height: 16),
            const _OverviewEmptyState(
              icon: Icons.people_alt_outlined,
              title: 'Chưa có nhân viên',
              description: 'Hiện chưa có dữ liệu nhân viên để cộng điểm.',
            ),
          ],
        ],
      ),
    );
  }
}

class _RedeemRequestsPage extends ConsumerWidget {
  const _RedeemRequestsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(
      rewardAdminRedemptionsProvider(
        _HrOverviewScreenState._pendingRewardRedemptionStatus,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Yêu cầu đổi quà')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(
            rewardAdminRedemptionsProvider(
              _HrOverviewScreenState._pendingRewardRedemptionStatus,
            ),
          );
          await ref.read(
            rewardAdminRedemptionsProvider(
              _HrOverviewScreenState._pendingRewardRedemptionStatus,
            ).future,
          );
        },
        child: requestsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              _InlineErrorCard(
                title: 'Không tải được yêu cầu đổi quà',
                message: '$error',
                onRetry: () => ref.invalidate(
                  rewardAdminRedemptionsProvider(
                    _HrOverviewScreenState._pendingRewardRedemptionStatus,
                  ),
                ),
              ),
            ],
          ),
          data: (requests) => requests.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: const [
                    _OverviewEmptyState(
                      icon: Icons.redeem_outlined,
                      title: 'Chưa có yêu cầu đổi quà',
                      description:
                          'Khi user gửi yêu cầu đổi quà, danh sách sẽ hiển thị ở đây.',
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) =>
                      _RedeemRequestTile(redemption: requests[index]),
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemCount: requests.length,
                ),
        ),
      ),
    );
  }
}

class _EmployeeOtHoursPage extends ConsumerWidget {
  const _EmployeeOtHoursPage({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref
        .read(authNotifierProvider)
        .valueOrNull
        ?.payrollStartConfig;
    final startDay = config ?? 1;
    final range = _buildOtSummaryRange(month, startDay);
    final query = EmployeeOtSummaryQuery(
      from: _formatApiDate(range.start),
      to: _formatApiDate(range.end),
    );
    final otSummaryAsync = ref.watch(employeeOtSummaryProvider(query));
    final title =
        'Giờ OT ${month.month.toString().padLeft(2, '0')}/${month.year}';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: otSummaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _HrOverviewErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(employeeOtSummaryProvider(query)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const _OverviewEmptyState(
              icon: Icons.schedule_outlined,
              title: 'Chưa có dữ liệu OT',
              description: 'Không có dữ liệu OT trong kỳ này.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(employeeOtSummaryProvider(query));
              await ref.read(employeeOtSummaryProvider(query).future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                final palette = context.appPalette;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: palette.surfaceVariant),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: palette.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '#${index + 1}',
                          style: TextStyle(
                            color: palette.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Đã duyệt ${_formatHourCompact(item.totalOt)}',
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 13,
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
                            _formatHourCompact(item.totalOt),
                            style: TextStyle(
                              color: palette.primary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'tổng OT',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _SelfTopUpDialog extends ConsumerStatefulWidget {
  const _SelfTopUpDialog({required this.userId, required this.userName});

  final String userId;
  final String userName;

  @override
  ConsumerState<_SelfTopUpDialog> createState() => _SelfTopUpDialogState();
}

class _SelfTopUpDialogState extends ConsumerState<_SelfTopUpDialog> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final points = int.tryParse(_controller.text.trim());
    if (points == null || points < 1) {
      setState(() {
        _errorText = 'Vui lòng nhập số tym lớn hơn 0';
      });
      return;
    }

    if (points > 1000000) {
      setState(() {
        _errorText = 'Số tym nạp tối đa là 1,000,000';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await ref
          .read(hrRepositoryProvider)
          .grantAdminRewardPoints(userId: widget.userId, points: points);

      if (!mounted) return;
      Navigator.of(context).pop(points);
    } on DioException catch (error) {
      final message = error.response?.data is Map
          ? (error.response!.data as Map)['message']?.toString()
          : null;
      if (!mounted) return;
      setState(() {
        _errorText = message ?? 'Không thể nạp tym';
        _isSubmitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = '$error';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return AlertDialog(
      backgroundColor: palette.surface,
      title: Text(
        'Nạp tym cho chính bạn',
        style: TextStyle(color: palette.textPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tài khoản: ${widget.userName}',
            style: TextStyle(color: palette.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(7),
            ],
            decoration: InputDecoration(
              labelText: 'Số tym muốn nạp',
              hintText: 'Ví dụ: 10',
              errorText: _errorText,
            ),
            onSubmitted: (_) {
              if (!_isSubmitting) _submit();
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Nạp tym'),
        ),
      ],
    );
  }
}

class _InlineErrorCard extends StatelessWidget {
  const _InlineErrorCard({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

class _EmployeeRankingSection extends StatelessWidget {
  const _EmployeeRankingSection({
    required this.rankingsAsync,
    required this.onRetry,
    this.maxItems,
  });

  final AsyncValue<List<RewardLeaderboardEntry>> rankingsAsync;
  final VoidCallback onRetry;
  final int? maxItems;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return rankingsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Text(
              'Không tải được bảng xếp hạng',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
      data: (rankings) {
        if (rankings.isEmpty) {
          return const _OverviewEmptyState(
            icon: Icons.emoji_events_outlined,
            title: 'Chưa có dữ liệu xếp hạng',
            description:
                'API chưa trả về employee nào trong bảng xếp hạng điểm.',
          );
        }

        final visibleRankings = maxItems == null
            ? rankings
            : rankings.take(maxItems!).toList(growable: false);

        return Column(
          children: [
            for (var index = 0; index < visibleRankings.length; index++) ...[
              _EmployeeRankingTile(entry: visibleRankings[index]),
              if (index != visibleRankings.length - 1)
                Divider(height: 1, color: palette.surfaceVariant),
            ],
          ],
        );
      },
    );
  }
}

class _EmployeeRankingTile extends StatelessWidget {
  const _EmployeeRankingTile({required this.entry});

  final RewardLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final accent = switch (entry.rank) {
      1 => const Color(0xFFC78A12),
      2 => const Color(0xFF7A8BA6),
      3 => const Color(0xFFB97745),
      _ => palette.primary,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,

            alignment: Alignment.center,
            child: Text(
              '#${entry.rank}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          _RewardRankingAvatar(entry: entry),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // const SizedBox(height: 4),
                // Text(
                //   '${entry.email} · +${entry.lifetimeEarned} / -${entry.lifetimeSpent}',
                //   style: TextStyle(color: palette.textSecondary, fontSize: 12),
                // ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.rankingPoints}',
                style: TextStyle(
                  color: accent,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              // const SizedBox(height: 4),
              // Text(
              //   'tym',
              //   style: TextStyle(color: palette.textSecondary, fontSize: 12),
              // ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardRankingAvatar extends StatelessWidget {
  const _RewardRankingAvatar({required this.entry});

  final RewardLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final initials = _initials(entry.name);

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: entry.avatarUrl == null || entry.avatarUrl!.isEmpty
          ? Text(
              initials,
              style: TextStyle(
                color: palette.primary,
                fontWeight: FontWeight.w700,
              ),
            )
          : Image.network(
              entry.avatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) {
                return Text(
                  initials,
                  style: TextStyle(
                    color: palette.primary,
                    fontWeight: FontWeight.w700,
                  ),
                );
              },
            ),
    );
  }
}

class _PendingApprovalSection extends StatelessWidget {
  const _PendingApprovalSection({
    required this.pendingRequestsAsync,
    required this.onRetry,
  });

  final AsyncValue<List<RewardRedemption>> pendingRequestsAsync;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return pendingRequestsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Text(
              'Không tải được đơn chờ duyệt',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
      data: (pendingRequests) {
        if (pendingRequests.isEmpty) {
          return const _OverviewEmptyState(
            icon: Icons.redeem_outlined,
            title: 'Không có yêu cầu đổi quà',
            description:
                'Khi nhân viên gửi yêu cầu đổi quà, danh sách chờ duyệt sẽ hiển thị tại đây.',
          );
        }

        return Column(
          children: [
            for (var index = 0; index < pendingRequests.length; index++) ...[
              _PendingApprovalTile(redemption: pendingRequests[index]),
              if (index != pendingRequests.length - 1)
                Divider(height: 1, color: palette.surfaceVariant),
            ],
          ],
        );
      },
    );
  }
}

class _PendingApprovalTile extends StatelessWidget {
  const _PendingApprovalTile({required this.redemption});

  final RewardRedemption redemption;

  @override
  Widget build(BuildContext context) {
    return _RedeemRequestTile(redemption: redemption, compact: true);
  }
}

class _AttendanceInsightsPlaceholder extends StatelessWidget {
  const _AttendanceInsightsPlaceholder({required this.selectedDate});

  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.surfaceVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: _AttendanceMetricPlaceholder(
                  label: 'Đã chấm công',
                  color: AppColors.online,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _AttendanceMetricPlaceholder(
                  label: 'Chưa chấm công',
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 10,
                    color: AppColors.online.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 10,
                    color: AppColors.danger.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          // const SizedBox(height: 14),
          // Row(
          //   crossAxisAlignment: CrossAxisAlignment.start,
          //   children: [
          //     Icon(Icons.info_outline, color: palette.primary, size: 18),
          //     const SizedBox(width: 8),
          //     Expanded(
          //       child: Text(
          //         'Ngày ${_dateOnlyLabel(selectedDate)} hiện chưa có API tổng hợp chấm công theo toàn công ty, nên màn này mới dựng sẵn giao diện và chờ BE cấp số liệu thật.',
          //         style: TextStyle(
          //           color: palette.textSecondary,
          //           fontSize: 13,
          //           height: 1.45,
          //         ),
          //       ),
          //     ),
          //   ],
          // ),
        ],
      ),
    );
  }
}

class _AttendanceMetricPlaceholder extends StatelessWidget {
  const _AttendanceMetricPlaceholder({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '--',
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityTile extends StatelessWidget {
  const _RecentActivityTile({required this.activity});

  final _RecentActivity activity;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.push(
        '/hr/leaves/${activity.leave.id}',
        extra: activity.leave,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 7),
              decoration: BoxDecoration(
                color: activity.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activity.subtitle,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 13,
                      height: 1.4,
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
                  activity.trailing,
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Icon(Icons.chevron_right_rounded, color: palette.textHint),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHintChip extends StatelessWidget {
  const _SectionHintChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final initials = _initials(name);
    final seed = name.runes.fold<int>(0, (value, element) => value + element);
    final colors = <Color>[
      palette.primary,
      AppColors.info,
      AppColors.online,
      AppColors.warning,
    ];
    final color = colors[seed % colors.length];

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _OverviewEmptyState extends StatelessWidget {
  const _OverviewEmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      // decoration: BoxDecoration(
      //   color: palette.card,
      //   borderRadius: BorderRadius.circular(20),
      // ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: palette.primary),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _HrOverviewErrorState extends StatelessWidget {
  const _HrOverviewErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.danger,
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              'Không tải được dữ liệu tổng quan',
              style: TextStyle(
                color: context.appPalette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appPalette.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

class _OverviewMetricCardData {
  const _OverviewMetricCardData({
    required this.value,
    required this.label,
    required this.helper,
    required this.color,
    this.icon,
  });

  final String value;
  final String label;
  final String helper;
  final Color color;
  final IconData? icon;
}

class _RecentActivity {
  const _RecentActivity({
    required this.leave,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.color,
  });

  final LeaveRequest leave;
  final String title;
  final String subtitle;
  final String trailing;
  final Color color;
}

class _HrOverviewViewData {
  const _HrOverviewViewData({
    required this.employeeNames,
    required this.pendingRequests,
    required this.pendingLeaveCount,
    required this.pendingOtCount,
    required this.pendingOtHours,
    required this.approvedLeaveDays,
    required this.approvedCount,
    required this.rejectedCount,
    required this.resolvedCount,
    required this.recentActivities,
  });

  factory _HrOverviewViewData.fromLeaves({
    required List<LeaveRequest> leaves,
    required DateTime selectedDate,
  }) {
    final monthStart = DateTime(selectedDate.year, selectedDate.month, 1);
    final nextMonth = DateTime(selectedDate.year, selectedDate.month + 1, 1);

    final monthLeaves = leaves
        .where((leave) => _leaveIntersectsMonth(leave, monthStart, nextMonth))
        .toList(growable: false);

    final pendingRequests =
        monthLeaves
            .where((leave) => leave.status == 'submitted')
            .toList(growable: false)
          ..sort(_compareLeaveForDisplay);

    final approvedLeaves = monthLeaves
        .where((leave) => leave.status == 'approved')
        .toList(growable: false);
    final rejectedLeaves = monthLeaves
        .where((leave) => leave.status == 'rejected')
        .toList(growable: false);

    final approvedLeaveDays = approvedLeaves
        .where((leave) => leave.type != 'ot')
        .fold<double>(0, (sum, leave) => sum + (leave.requestedDays ?? 0));

    final pendingOtRequests = pendingRequests
        .where((leave) => leave.type == 'ot')
        .toList(growable: false);
    final pendingOtHours = pendingOtRequests.fold<double>(
      0,
      (sum, leave) => sum + _otDurationHours(leave),
    );

    final recentLeaves = monthLeaves.toList(growable: false)
      ..sort(_compareLeaveForRecent);

    final employeeNames = _collectEmployeeNames(monthLeaves);

    return _HrOverviewViewData(
      employeeNames: employeeNames,
      pendingRequests: pendingRequests.take(5).toList(growable: false),
      pendingLeaveCount: pendingRequests
          .where((leave) => leave.type != 'ot')
          .length,
      pendingOtCount: pendingOtRequests.length,
      pendingOtHours: pendingOtHours,
      approvedLeaveDays: approvedLeaveDays,
      approvedCount: approvedLeaves.length,
      rejectedCount: rejectedLeaves.length,
      resolvedCount: approvedLeaves.length + rejectedLeaves.length,
      recentActivities: recentLeaves
          .take(4)
          .map(_buildRecentActivity)
          .toList(growable: false),
    );
  }

  final List<String> employeeNames;
  final List<LeaveRequest> pendingRequests;
  final int pendingLeaveCount;
  final int pendingOtCount;
  final double pendingOtHours;
  final double approvedLeaveDays;
  final int approvedCount;
  final int rejectedCount;
  final int resolvedCount;
  final List<_RecentActivity> recentActivities;
}

class _EmployeeOtStats {
  const _EmployeeOtStats({
    required this.name,
    required this.approvedHours,
    required this.pendingHours,
  });

  final String name;
  final double approvedHours;
  final double pendingHours;

  double get totalHours => approvedHours + pendingHours;
}

List<_EmployeeOtStats> _buildEmployeeOtStats({
  required List<LeaveRequest> leaves,
  required List<RewardAdminEmployee> employees,
  required DateTime month,
}) {
  final monthStart = DateTime(month.year, month.month, 1);
  final nextMonth = DateTime(month.year, month.month + 1, 1);

  final approvedMap = <String, double>{};
  final pendingMap = <String, double>{};

  for (final leave in leaves) {
    if (leave.type != 'ot') continue;
    if (!_leaveIntersectsMonth(leave, monthStart, nextMonth)) continue;
    final name = leave.userName?.trim();
    if (name == null || name.isEmpty) continue;
    final hours = _otDurationHours(leave);
    if (leave.status == 'approved') {
      approvedMap[name] = (approvedMap[name] ?? 0) + hours;
    } else if (leave.status == 'submitted') {
      pendingMap[name] = (pendingMap[name] ?? 0) + hours;
    }
  }

  final knownNames = employees
      .map((employee) => employee.name.trim())
      .where((name) => name.isNotEmpty)
      .toSet();

  final allNames = <String>{
    ...knownNames,
    ...approvedMap.keys,
    ...pendingMap.keys,
  };

  final stats =
      allNames
          .map(
            (name) => _EmployeeOtStats(
              name: name,
              approvedHours: approvedMap[name] ?? 0,
              pendingHours: pendingMap[name] ?? 0,
            ),
          )
          .toList(growable: false)
        ..sort((a, b) {
          final totalCompare = b.totalHours.compareTo(a.totalHours);
          if (totalCompare != 0) return totalCompare;
          final approvedCompare = b.approvedHours.compareTo(a.approvedHours);
          if (approvedCompare != 0) return approvedCompare;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

  return stats;
}

String _formatHourCompact(double value) {
  if (value == value.roundToDouble()) {
    return '${value.toInt()}h';
  }
  return '${value.toStringAsFixed(1)}h';
}

class _OtSummaryRange {
  const _OtSummaryRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

_OtSummaryRange _buildOtSummaryRange(DateTime month, int payrollStartDay) {
  return _OtSummaryRange(
    start: DateTime(month.year, month.month - 1, payrollStartDay),
    end: DateTime(month.year, month.month, payrollStartDay - 1),
  );
}

String _formatApiDate(DateTime date) => date.toIso8601String().substring(0, 10);

String _formatTick(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}

String _shortEmployeeName(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.length <= 2) return name;
  final lastTwo = words.skip(words.length - 2).toList(growable: false);
  final prefix = words
      .take(words.length - 2)
      .map((word) => '${word[0]}.')
      .join(' ');
  return '$prefix ${lastTwo.join(' ')}';
}

List<String> _collectEmployeeNames(List<LeaveRequest> leaves) {
  final names =
      leaves
          .map((leave) => leave.userName?.trim())
          .whereType<String>()
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  return names;
}

_RecentActivity _buildRecentActivity(LeaveRequest leave) {
  final userName = leave.userName?.trim().isNotEmpty == true
      ? leave.userName!.trim()
      : 'Nhân sự';
  final typeLabel = _leaveTypeLabel(leave.type);
  final action = switch (leave.status) {
    'approved' => 'được duyệt',
    'rejected' => 'bị từ chối',
    _ => 'đã gửi đơn',
  };

  return _RecentActivity(
    leave: leave,
    title: '$userName $action $typeLabel',
    subtitle: leave.type == 'ot'
        ? '${_dateRangeLabel(leave)} · ${_timeRangeLabel(leave)}'
        : '${_dateRangeLabel(leave)} · ${_leaveDurationLabel(leave)}',
    trailing: _recentTrailingLabel(leave),
    color: _statusColor(leave.status, null),
  );
}

bool _leaveIntersectsMonth(
  LeaveRequest leave,
  DateTime monthStart,
  DateTime monthEndExclusive,
) {
  final start = DateTime.tryParse(leave.startDate);
  if (start == null) return false;
  final end = DateTime.tryParse(leave.endDate) ?? start;
  return start.isBefore(monthEndExclusive) && !end.isBefore(monthStart);
}

int _compareLeaveForDisplay(LeaveRequest a, LeaveRequest b) {
  final aDate = _primaryLeaveDate(a);
  final bDate = _primaryLeaveDate(b);
  return aDate.compareTo(bDate);
}

int _compareLeaveForRecent(LeaveRequest a, LeaveRequest b) {
  final aDate = _recentSortDate(a);
  final bDate = _recentSortDate(b);
  return bDate.compareTo(aDate);
}

DateTime _primaryLeaveDate(LeaveRequest leave) {
  return DateTime.tryParse(leave.startDate) ??
      leave.approvedAt ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime _recentSortDate(LeaveRequest leave) {
  return leave.approvedAt ??
      DateTime.tryParse(leave.startDate) ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

double _otDurationHours(LeaveRequest leave) {
  final start = _parseTimeOfDay(leave.startTime);
  final end = _parseTimeOfDay(leave.endTime);
  if (start == null || end == null) return 0;

  final startMinutes = start.hour * 60 + start.minute;
  var endMinutes = end.hour * 60 + end.minute;
  if (endMinutes < startMinutes) {
    endMinutes += Duration.minutesPerDay;
  }
  return (endMinutes - startMinutes) / 60;
}

TimeOfDay? _parseTimeOfDay(String? value) {
  if (value == null || value.isEmpty) return null;
  final parts = value.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String _leaveTypeLabel(String type) {
  switch (type) {
    case 'annual':
      return 'Phép năm';
    case 'sick':
      return 'Nghỉ ốm';
    case 'personal':
      return 'Việc riêng';
    case 'ot':
      return 'OT';
    default:
      return 'Đơn nhân sự';
  }
}

String _statusLabel(String? status) {
  switch (status) {
    case 'submitted':
      return 'Chờ duyệt';
    case 'approved':
      return 'Đã duyệt';
    case 'rejected':
      return 'Từ chối';
    case 'cancelled':
      return 'Đã hủy';
    default:
      return 'Đang xử lý';
  }
}

Color _statusColor(String? status, AppThemePalette? palette) {
  switch (status) {
    case 'submitted':
      return AppColors.warning;
    case 'approved':
      return AppColors.online;
    case 'rejected':
      return AppColors.danger;
    case 'cancelled':
      return AppColors.danger;
    default:
      return palette?.textHint ?? Colors.grey;
  }
}

String _dateRangeLabel(LeaveRequest leave) {
  final start = DateTime.tryParse(leave.startDate);
  final end = DateTime.tryParse(leave.endDate);
  if (start == null) return '--/--/----';
  final startLabel = _dateOnlyLabel(start);
  final endLabel = _dateOnlyLabel(end ?? start);
  return startLabel == endLabel ? startLabel : '$startLabel - $endLabel';
}

String _leaveDurationLabel(LeaveRequest leave) {
  final requestedDays = leave.requestedDays;
  if (requestedDays == null || requestedDays <= 0) return 'Không rõ thời lượng';
  return '${_formatCompactNumber(requestedDays)} ngày';
}

String _timeRangeLabel(LeaveRequest leave) {
  if (leave.startTime == null || leave.endTime == null) {
    return 'Chưa có khung giờ';
  }
  return '${leave.startTime} - ${leave.endTime}';
}

String _monthLabel(DateTime date) {
  return 'Tháng ${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _redemptionRequesterLabel(RewardRedemption redemption) {
  final userName = redemption.userName?.trim();
  if (userName != null && userName.isNotEmpty) {
    return userName;
  }
  final userId = redemption.userId.trim();
  if (userId.isEmpty) return 'Nhân viên';
  final shortId = userId.length > 8 ? userId.substring(0, 8) : userId;
  return 'User $shortId';
}

String _rewardRedemptionMetaLine(RewardRedemption redemption) {
  final unitCost = formatHeartPoints(redemption.unitPointsCost);
  final createdAt = redemption.createdAt?.toLocal();
  final createdLabel = createdAt == null
      ? 'Không rõ thời gian'
      : '${_dateOnlyLabel(createdAt)} • ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  return '$createdLabel • $unitCost tym / món';
}

Future<String?> _showProcessRedemptionDialog(
  BuildContext context, {
  required String title,
  required String initialNote,
  required String confirmLabel,
}) async {
  final controller = TextEditingController(text: initialNote);
  final result = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Ghi chú xử lý',
            hintText: 'Nhập ghi chú cho yêu cầu này',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  controller.dispose();
  return result;
}

String _fullDateLabel(DateTime date) {
  return 'Hôm nay, ${_dateOnlyLabel(date)}';
}

String _dateOnlyLabel(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

bool _isValidUuid(String value) {
  final uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  return uuidPattern.hasMatch(value.trim());
}

InputDecoration _adminFieldDecoration(
  BuildContext context, {
  required String label,
  String? hint,
}) {
  final palette = context.appPalette;

  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: palette.card,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: palette.surfaceVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: palette.primary),
    ),
  );
}

String _recentTrailingLabel(LeaveRequest leave) {
  if (leave.approvedAt != null) {
    return _dateOnlyLabel(leave.approvedAt!.toLocal());
  }
  final start = DateTime.tryParse(leave.startDate);
  if (start != null) return _dateOnlyLabel(start);
  return '--/--/----';
}

String _formatCompactNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

String _initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return 'NA';
  if (words.length == 1) {
    return words.first.characters.take(2).toString().toUpperCase();
  }
  return '${words.first.characters.first}${words.last.characters.first}'
      .toUpperCase();
}
