import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../auth/providers/auth_notifier.dart';
import '../../task/models/task_models.dart';
import '../../task/screens/task_detail_screen.dart';
import '../data/daily_report_models.dart';
import '../data/hr_models.dart';
import '../providers/daily_report_providers.dart';
import '../providers/hr_providers.dart';
import 'evening_report_sheet.dart';
import 'leave_create_screen.dart';
import 'morning_report_sheet.dart';
import 'ot_report_sheet.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/widgets/heart_header_badge.dart';
import '../hr_role_utils.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appPalette;
    final attendanceAsync = ref.watch(attendanceProvider);
    final now = DateTime.now();
    final leaveBalanceAsync = ref.watch(
      leaveBalanceProvider(LeaveBalanceQuery(year: now.year)),
    );
    final wfhBalanceAsync = ref.watch(
      wfhBalanceProvider(LeaveBalanceQuery(year: now.year)),
    );
    final roles = ref.watch(authNotifierProvider).valueOrNull?.user?.roles ?? [];
    final canApproveLeaves = canApproveLeavesForRoles(roles);
    final isWide = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chấm công'),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Center(child: HeartHeaderBadge(compact: true)),
          ),
          IconButton(
            icon: const Icon(Icons.terminal_rounded),
            tooltip: 'Audit log báo cáo ngày',
            onPressed: () => context.push('/hr/daily-reports/audit-logs'),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            tooltip: 'Lịch làm việc',
            onPressed: () => context.push('/hr/history'),
          ),
          IconButton(
            icon: const Icon(Icons.note_add_outlined),
            tooltip: 'Xem đơn',
            onPressed: () => context.push('/hr/leaves'),
          ),
          if (canApproveLeaves)
            IconButton(
              icon: const Icon(Icons.calendar_view_week_outlined),
              tooltip: 'Lịch OFF/WFH',
              onPressed: () => context.push('/hr/weekly-schedule'),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Cấu hình',
            onPressed: () => context.push('/hr/config'),
          ),
        ],
      ),
      body: attendanceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$e', style: const TextStyle(color: AppColors.danger)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.read(attendanceProvider.notifier).refresh(),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
        data: (state) => _buildContent(
          context,
          ref,
          state,
          leaveBalanceAsync,
          wfhBalanceAsync,
          isWide,
          palette,
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    AttendanceState state,
    AsyncValue<LeaveBalance> leaveBalanceAsync,
    AsyncValue<WfhBalance> wfhBalanceAsync,
    bool isWide,
    AppThemePalette palette,
  ) {
    if (state.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          showTopSnackBar(
            context,
            message: state.errorMessage!,
            backgroundColor: AppColors.danger,
          );
        }
      });
    }

    final record = state.todayRecord ?? {};
    final rawSessions = record['sessions'];
    final sessions = rawSessions is List ? rawSessions : <dynamic>[];
    final hasOpenSession = record['has_open_session'] == true;
    final totalHours = record['total_hours'] ?? 0;
    final totalOt = record['total_ot'] ?? 0;
    final canCheckout = hasOpenSession;
    final primaryActionLabel = canCheckout ? 'Check Out' : 'Check In';
    final primaryActionIcon = canCheckout ? Icons.logout : Icons.login;
    final primaryActionColor = _hrAccentColor(palette);
    Future<void> primaryAction() {
      return _handleAttendanceAction(context, ref, isCheckout: canCheckout);
    }

    final content = RefreshIndicator(
      onRefresh: () async {
        await ref.read(attendanceProvider.notifier).refresh();
      },
      child: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 28 : 20,
          vertical: 16,
        ),
        children: [
          _PayrollCountdownCard(palette: palette, isWide: isWide),
          const SizedBox(height: 22),
          _TodayOverviewSection(
            sessionCount: sessions.length,
            totalHours: totalHours,
            totalOt: totalOt,
            palette: palette,
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: isWide ? 360 : double.infinity,
              child: _PrimaryAttendanceActionButton(
                label: primaryActionLabel,
                icon: primaryActionIcon,
                color: primaryActionColor,
                onPressed: primaryAction,
              ),
            ),
          ),
          // Daily report button (only visible after check-in)
          if (hasOpenSession || sessions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: isWide ? 360 : double.infinity,
                  child: _DailyReportButton(palette: palette),
                ),
              ),
            ),
          const SizedBox(height: 22),
          _sectionDivider(palette),
          const SizedBox(height: 22),
          LeaveBalanceOverviewCard(
            balanceAsync: leaveBalanceAsync,
            wfhBalanceAsync: wfhBalanceAsync,
            palette: palette,
          ),
          const SizedBox(height: 22),
          _sectionDivider(palette),
          const SizedBox(height: 22),
          _TodaySessionsSection(sessions: sessions, palette: palette),
          const SizedBox(height: 22),
          _sectionDivider(palette),
          const SizedBox(height: 22),
          const _MyTasksSection(),
        ],
      ),
    );

    if (isWide) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: content,
        ),
      );
    }
    return content;
  }

  Future<void> _handleAttendanceAction(
    BuildContext context,
    WidgetRef ref, {
    required bool isCheckout,
  }) async {
    final attendanceNotifier = ref.read(attendanceProvider.notifier);
    AttendanceCheckoutResult? checkoutResult;

    if (isCheckout) {
      checkoutResult = await attendanceNotifier.checkout();
    } else {
      await attendanceNotifier.checkin();
    }

    final nextState = ref.read(attendanceProvider);
    if (nextState.hasError) return;

    await ref
        .read(authNotifierProvider.notifier)
        .resyncRewardWallet(force: true);

    if (!context.mounted) return;
    if (isCheckout) {
      await _showAttendanceRewardDialog(
        context,
        isCheckout: isCheckout,
        rewardPoints: checkoutResult?.rewarded == true
            ? checkoutResult!.rewardPoints
            : null,
      );
    } else {
      // After check-in, prompt for morning report
      _promptMorningReport(context, ref);
    }
  }

  void _promptMorningReport(BuildContext context, WidgetRef ref) {
    final palette = context.appPalette;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Báo cáo công việc',
          style: TextStyle(color: palette.textPrimary, fontSize: 17),
        ),
        content: Text(
          'Bạn có muốn báo cáo công việc sáng không?',
          style: TextStyle(color: palette.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Để sau', style: TextStyle(color: palette.textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              showMorningReportSheet(context);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.online),
            child: const Text('Báo cáo ngay'),
          ),
        ],
      ),
    );
  }
}

class _PayrollCountdownCard extends StatelessWidget {
  const _PayrollCountdownCard({required this.palette, required this.isWide});

  final AppThemePalette palette;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final mood = _resolvePayrollMood(DateTime.now());
    final accent = _hrAccentColor(palette);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 22 : 18,
        vertical: isWide ? 18 : 16,
      ),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.surfaceVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: isWide ? 112 : 96,
            height: isWide ? 112 : 96,
            child: Lottie.asset(
              mood.animationAssetPath,
              repeat: true,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mood.title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  mood.subtitle,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(
                      alpha: palette.isLight ? 0.16 : 0.2,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    mood.badge,
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
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

class _PayrollMoodState {
  const _PayrollMoodState({
    required this.animationAssetPath,
    required this.title,
    required this.subtitle,
    required this.badge,
  });

  final String animationAssetPath;
  final String title;
  final String subtitle;
  final String badge;
}

_PayrollMoodState _resolvePayrollMood(DateTime now) {
  final nextPayrollDate = _nextPayrollDate(now);
  final remainingDays = nextPayrollDate.difference(_startOfDay(now)).inDays;
  final day = now.day;

  final countdownText = remainingDays == 0
      ? 'Hôm nay là ngày nhận lương'
      : 'Còn $remainingDays ngày tới kỳ lương mùng 10';

  if (day >= 10) {
    return _PayrollMoodState(
      animationAssetPath: 'assets/animation/rich_mood.json',
      title: 'Ví còn dày, tinh thần đi làm lên cao',
      subtitle: countdownText,
      badge: remainingDays == 0 ? 'Lương về hôm nay' : 'Đầu tháng dư dả',
    );
  }
  if (day >= 20) {
    return _PayrollMoodState(
      animationAssetPath: 'assets/animation/normal_mood.json',
      title: 'Vẫn ổn, nhưng nên tiêu có kế hoạch',
      subtitle: countdownText,
      badge: 'Giữa tháng giữ nhịp',
    );
  }
  return _PayrollMoodState(
    animationAssetPath: 'assets/animation/broke_mood.json',
    title: 'Làm chill chill đợi lương',
    subtitle: countdownText,
    badge: 'Cuối tháng mong lương',
  );
}

DateTime _nextPayrollDate(DateTime now) {
  final today = _startOfDay(now);
  final thisMonthPayroll = DateTime(now.year, now.month, 10);
  if (!today.isAfter(thisMonthPayroll)) {
    return thisMonthPayroll;
  }
  return DateTime(now.year, now.month + 1, 10);
}

DateTime _startOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

Future<void> _showAttendanceRewardDialog(
  BuildContext context, {
  required bool isCheckout,
  int? rewardPoints,
}) {
  final palette = context.appPalette;
  final lines = isCheckout ? _checkoutRewardLines : _checkinRewardLines;
  final line = lines[DateTime.now().millisecond % lines.length];
  final hasReward = isCheckout && (rewardPoints ?? 0) > 0;
  final badgeText = hasReward
      ? '+$rewardPoints điểm thưởng'
      : (isCheckout ? 'Hoàn tất' : '+1 tym');
  final titleText = isCheckout ? 'Checkout thành công' : 'Check in thành công';
  final subtitleText = hasReward
      ? 'Bạn đã được cộng ${rewardPoints!} điểm thưởng'
      : line;

  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: palette.primary.withValues(alpha: 0.26)),
            boxShadow: [
              BoxShadow(
                color: palette.primary.withValues(alpha: 0.16),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: Lottie.asset(
                  'assets/animation/addTym.json',
                  repeat: true,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                badgeText,
                style: TextStyle(
                  color: palette.primary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                titleText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitleText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Tiếp tục'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

const List<String> _checkinRewardLines = [
  'Một ngày mới mở ra, chấm công xong là tinh thần cũng vào guồng.',
  'Bạn vừa gieo một nhịp chăm chỉ, cuối ngày sẽ gặt lại thật nhiều niềm vui.',
  'Đi làm đúng nhịp, lòng vui đúng điệu, thêm một tym cho hành trình hôm nay.',
  'Bắt đầu chỉn chu là cách dịu dàng nhất để ngày mới trở nên rực rỡ.',
  'Check in rồi, giờ thì cứ để năng lượng tích cực dẫn lối cho một ngày tuyệt vời nhé!',
  'Một nhịp check in, một bước khởi đầu, chúc bạn có một ngày làm việc hiệu quả và tràn đầy năng lượng.',
  'Đã check in, đã sẵn sàng, giờ là lúc tỏa sáng với những nỗ lực của bạn rồi đấy!',
  'Check in thành công rồi, giờ thì cứ để tinh thần hứng khởi dẫn lối cho một ngày làm việc tuyệt vời nhé!',
];

const List<String> _checkoutRewardLines = [
  'Khép lại một ngày gọn gàng, thêm một tym cho những cố gắng âm thầm.',
  'Hôm nay bạn đã làm đủ tốt, phần còn lại cứ để buổi tối chữa lành.',
  'Rời công việc với trái tim đầy hơn một nhịp, đó cũng là thành tựu đẹp.',
  'Một ngày đi qua, một điểm được cộng, và một phiên bản bền bỉ hơn được giữ lại.',
  'Check out rồi, giờ là lúc để thư giãn và tận hưởng thành quả của một ngày làm việc chăm chỉ nhé!',
  'Đã check out, đã hoàn thành, giờ là lúc để thư giãn và tận hưởng thành quả của một ngày làm việc chăm chỉ nhé!',
  'Check out thành công rồi, giờ thì cứ để tinh thần nhẹ nhõm dẫn lối cho một buổi tối thư giãn tuyệt vời nhé!',
  'Một ngày đã khép lại, một tym đã được trao, giờ là lúc để thư giãn và tận hưởng thành quả của một ngày làm việc chăm chỉ nhé!',
];

class _TodayOverviewSection extends StatelessWidget {
  const _TodayOverviewSection({
    required this.sessionCount,
    required this.totalHours,
    required this.totalOt,
    required this.palette,
  });

  final int sessionCount;
  final dynamic totalHours;
  final dynamic totalOt;
  final AppThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final accent = _hrAccentColor(palette);
    final subtle = palette.textHint.withValues(
      alpha: palette.isLight ? 0.42 : 0.6,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hôm nay',
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _TodayMetric(
                value: '$sessionCount',
                label: 'phiên',
                color: accent,
                align: CrossAxisAlignment.center,
              ),
            ),
            _OverviewDot(color: subtle),
            Expanded(
              child: _TodayMetric(
                value: _formatHourValue(totalHours),
                label: 'tổng',
                color: accent,
                align: CrossAxisAlignment.center,
              ),
            ),
            _OverviewDot(color: subtle),
            Expanded(
              child: _TodayMetric(
                value: _formatHourValue(totalOt),
                label: 'OT',
                color: accent,
                align: CrossAxisAlignment.center,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TodayMetric extends StatelessWidget {
  const _TodayMetric({
    required this.value,
    required this.label,
    required this.color,
    required this.align,
  });

  final String value;
  final String label;
  final Color color;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 27,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _OverviewDot extends StatelessWidget {
  const _OverviewDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(bottom: 26),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _PrimaryAttendanceActionButton extends StatelessWidget {
  const _PrimaryAttendanceActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = _buttonForegroundColor(color);

    return SizedBox(
      height: 45,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        label: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: foregroundColor,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: foregroundColor,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
      ),
    );
  }
}

class _DailyReportButton extends ConsumerWidget {
  const _DailyReportButton({required this.palette});

  final AppThemePalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(todayReportsProvider);

    return reportsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (reports) {
        final morning = todayMorningReport(reports);
        final evening = todayEveningReport(reports);
        final ot = todayOtReport(reports);

        String label;
        IconData icon;
        Color bgColor;

        if (morning == null && evening == null && ot == null) {
          label = 'Báo cáo công việc';
          icon = Icons.edit_note;
          bgColor = palette.primary;
        } else {
          label = 'Quản lý báo cáo hôm nay';
          icon = Icons.check_circle_outline;
          bgColor = AppColors.online.withOpacity(0.8);
        }

        return SizedBox(
          height: 45,
          child: OutlinedButton.icon(
            onPressed: () => _showReportMenu(context, reports, palette),
            icon: Icon(icon, size: 18),
            label: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: bgColor,
              side: BorderSide(color: bgColor, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showReportMenu(
    BuildContext context,
    List<DailyReport> reports,
    AppThemePalette palette,
  ) {
    final morning = todayMorningReport(reports);
    final evening = todayEveningReport(reports);
    final ot = todayOtReport(reports);

    showModalBottomSheet(
      context: context,
      backgroundColor: palette.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Báo cáo công việc hôm nay',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(),
              // 1. Morning Report Option
              ListTile(
                leading: Icon(
                  morning != null ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: morning != null ? AppColors.online : palette.textSecondary,
                ),
                title: Text(
                  morning != null ? 'Sửa báo cáo sáng' : 'Nộp báo cáo sáng',
                  style: TextStyle(color: palette.textPrimary),
                ),
                subtitle: Text(
                  morning != null ? 'Đã nộp' : 'Chưa nộp',
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showMorningReportSheet(context, existingReport: morning);
                },
              ),
              // 2. Evening Report Option
              ListTile(
                leading: Icon(
                  evening != null ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: evening != null ? AppColors.online : palette.textSecondary,
                ),
                title: Text(
                  evening != null ? 'Sửa báo cáo cuối ngày' : 'Nộp báo cáo cuối ngày',
                  style: TextStyle(
                    color: morning != null ? palette.textPrimary : palette.textHint,
                  ),
                ),
                subtitle: Text(
                  evening != null
                      ? 'Đã nộp'
                      : (morning != null ? 'Chưa nộp' : 'Yêu cầu nộp báo cáo sáng trước'),
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
                enabled: morning != null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  showEveningReportSheet(
                    context,
                    morningReport: morning!,
                    existingReport: evening,
                  );
                },
              ),
              // 3. OT Report Option
              ListTile(
                leading: Icon(
                  ot != null ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: ot != null ? AppColors.online : palette.textSecondary,
                ),
                title: Text(
                  ot != null ? 'Sửa báo cáo OT ngoài giờ' : 'Nộp báo cáo OT ngoài giờ',
                  style: TextStyle(color: palette.textPrimary),
                ),
                subtitle: Text(
                  ot != null ? 'Đã nộp' : 'Báo cáo công việc làm ngoài giờ',
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showOtReportSheet(context, existingReport: ot);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodaySessionsSection extends StatelessWidget {
  const _TodaySessionsSection({required this.sessions, required this.palette});

  final List<dynamic> sessions;
  final AppThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phiên hôm nay',
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        if (sessions.isEmpty)
          Text(
            'Chưa có phiên chấm công nào hôm nay.',
            style: TextStyle(color: palette.textSecondary, fontSize: 14),
          )
        else
          Column(
            children: [
              for (var index = 0; index < sessions.length; index++) ...[
                _TodaySessionRow(session: sessions[index], palette: palette),
                if (index != sessions.length - 1)
                  Divider(height: 1, color: palette.surfaceVariant),
              ],
            ],
          ),
      ],
    );
  }
}

class _TodaySessionRow extends StatelessWidget {
  const _TodaySessionRow({required this.session, required this.palette});

  final dynamic session;
  final AppThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final map = session is Map<String, dynamic> ? session : <String, dynamic>{};
    final checkin = _formatAttendanceTime(map['checkin_at']);
    final checkout = map['checkout_at'] != null
        ? _formatAttendanceTime(map['checkout_at'])
        : 'đang làm';
    final isCompleted = map['checkout_at'] != null;
    final duration = _formatHourValue(map['total_hours'], fallback: '0h');
    final statusLabel = isCompleted ? 'Đã chấm' : 'Đang làm';
    final statusColor = _sessionStatusColor(palette, isCompleted: isCompleted);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '$checkin – $checkout',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              duration,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary, fontSize: 14),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              statusLabel,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: statusColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem {
  const _SummaryItem(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class AttendanceMonthlySummarySection extends StatelessWidget {
  const AttendanceMonthlySummarySection({
    super.key,
    required this.summary,
    required this.palette,
    required this.isWide,
  });

  final AttendanceSummary summary;
  final AppThemePalette palette;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final items = [
      _SummaryItem(
        'Tổng công',
        _formatSummaryNumber(summary.totalDays),
        Icons.today,
        palette.primary,
      ),
      _SummaryItem(
        'Nghỉ có lương',
        _formatSummaryNumber(summary.paidLeaveDays),
        Icons.beach_access,
        AppColors.online,
      ),
      _SummaryItem(
        'Nghỉ không lương',
        _formatSummaryNumber(summary.unpaidLeaveDays),
        Icons.money_off,
        AppColors.warning,
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items
          .map(
            (item) => SizedBox(
              width: isWide ? 220 : double.infinity,
              child: Card(
                color: palette.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Icon(item.icon, color: item.color, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              item.value,
                              style: TextStyle(
                                color: item.color,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class LeaveBalanceOverviewCard extends StatelessWidget {
  const LeaveBalanceOverviewCard({
    super.key,
    required this.balanceAsync,
    required this.wfhBalanceAsync,
    required this.palette,
  });

  final AsyncValue<LeaveBalance> balanceAsync;
  final AsyncValue<WfhBalance> wfhBalanceAsync;
  final AppThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return balanceAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text(
        'Không tải được phép năm.',
        style: TextStyle(color: palette.textSecondary, fontSize: 14),
      ),
      data: (balance) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phép năm ${balance.year}',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 14,
            runSpacing: 8,
            children: [
              _LeaveInlineMetric(
                prefix: 'Đã dùng',
                value:
                    '${formatLeaveBalanceDays(balance.usedPaidDays)} / ${formatLeaveBalanceDays(balance.allocatedDays)} ngày',
                highlightColor: _hrAccentColor(palette),
              ),
              Container(width: 1, height: 20, color: palette.surfaceVariant),
              _LeaveInlineMetric(
                prefix: 'Còn lại',
                value:
                    '${formatLeaveBalanceDays(balance.remainingPaidDays)} ngày',
                highlightColor: _hrAccentColor(palette),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildWfhSection(),
        ],
      ),
    );
  }

  Widget _buildWfhSection() {
    return wfhBalanceAsync.when(
      loading: () => Row(
        children: [
          Icon(
            Icons.home_work_outlined,
            size: 18,
            color: palette.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            'Đang tải quota WFH...',
            style: TextStyle(color: palette.textSecondary, fontSize: 13),
          ),
        ],
      ),
      error: (error, _) => Row(
        children: [
          Icon(
            Icons.home_work_outlined,
            size: 18,
            color: palette.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            'WFH: chưa tải được quota',
            style: TextStyle(color: palette.textSecondary, fontSize: 13),
          ),
        ],
      ),
      data: (balance) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WFH ${balance.year}',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 14,
            runSpacing: 8,
            children: [
              _LeaveInlineMetric(
                prefix: 'Đã dùng',
                value:
                    '${formatLeaveBalanceDays(balance.usedDays)} / ${formatLeaveBalanceDays(balance.allocatedDays)} ngày',
                highlightColor: _hrAccentColor(palette),
              ),
              Container(width: 1, height: 20, color: palette.surfaceVariant),
              _LeaveInlineMetric(
                prefix: 'Còn lại',
                value: '${formatLeaveBalanceDays(balance.remainingDays)} ngày',
                highlightColor: _hrAccentColor(palette),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatSummaryNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

class _LeaveInlineMetric extends StatelessWidget {
  const _LeaveInlineMetric({
    required this.prefix,
    required this.value,
    required this.highlightColor,
  });

  final String prefix;
  final String value;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: palette.textSecondary,
          fontSize: 14,
          height: 1.35,
        ),
        children: [
          TextSpan(text: '$prefix '),
          TextSpan(
            text: value,
            style: TextStyle(
              color: highlightColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _sectionDivider(AppThemePalette palette) {
  return Divider(
    height: 1,
    color: palette.surfaceVariant.withValues(alpha: 0.8),
  );
}

Color _hrAccentColor(AppThemePalette palette) {
  return palette.primary;
}

Color _sessionStatusColor(
  AppThemePalette palette, {
  required bool isCompleted,
}) {
  return isCompleted ? palette.primaryDark : palette.primary;
}

Color _buttonForegroundColor(Color background) {
  return background.computeLuminance() > 0.45
      ? const Color(0xFF171717)
      : Colors.white;
}

String _formatHourValue(dynamic value, {String fallback = '0h'}) {
  if (value == null) return fallback;
  final number = value is num
      ? value.toDouble()
      : double.tryParse(value.toString());
  if (number == null) return fallback;
  if (number == number.roundToDouble()) {
    return '${number.toInt()}h';
  }
  return '${number.toStringAsFixed(1)}h';
}

String _formatAttendanceTime(dynamic value) {
  if (value == null) return '--:--';
  final dt = DateTime.tryParse(value.toString());
  if (dt == null) return '--:--';
  final local = dt.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

// --- My Tasks Section (shows only today's reported tasks) ---

class _MyTasksSection extends ConsumerStatefulWidget {
  const _MyTasksSection();

  @override
  ConsumerState<_MyTasksSection> createState() => _MyTasksSectionState();
}

class _MyTasksSectionState extends ConsumerState<_MyTasksSection> {
  String? _selectedStage;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final reportsAsync = ref.watch(todayReportsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(Icons.task_alt, size: 20, color: palette.primary),
            const SizedBox(width: 8),
            Text(
              'Công việc hôm nay',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Content
        reportsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Không tải được báo cáo: $e',
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ),
          data: (reports) {
            final morning = todayMorningReport(reports);
            final evening = todayEveningReport(reports);

            if (morning == null) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        size: 36,
                        color: palette.textHint,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Chưa báo cáo công việc hôm nay',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hãy nhấn "Báo cáo sáng" để bắt đầu',
                        style: TextStyle(
                          color: palette.textHint,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Merge tasks from morning report, overlay evening status
            final reportedTasks = _buildReportedTasks(morning, evening);

            if (reportedTasks.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Không có task nào trong báo cáo',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 13,
                  ),
                ),
              );
            }

            // Extract all tasks for filtering
            final allTasks = reportedTasks
                .expand((g) => g.tasks)
                .toList();
            final stages = _extractStages(allTasks);

            // Search field
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Task count
                Text(
                  '${allTasks.length} tasks đã báo cáo',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                // Search field
                SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Tìm task...',
                      hintStyle: TextStyle(
                        color: palette.textSecondary.withOpacity(0.6),
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 18,
                        color: palette.textSecondary,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: palette.textSecondary,
                              ),
                            )
                          : null,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 0),
                      isDense: true,
                      filled: true,
                      fillColor: palette.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: palette.surfaceVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: palette.surfaceVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: palette.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (v) =>
                        setState(() => _searchQuery = v),
                  ),
                ),
                const SizedBox(height: 10),
                // Stage filter chips
                if (stages.length > 1) ...[
                  SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _TaskStageFilterChip(
                          label: 'Tất cả',
                          isSelected: _selectedStage == null,
                          palette: palette,
                          onTap: () =>
                              setState(() => _selectedStage = null),
                        ),
                        for (final stage in stages) ...[
                          const SizedBox(width: 6),
                          _TaskStageFilterChip(
                            label: stage,
                            isSelected:
                                _selectedStage?.toUpperCase() ==
                                    stage.toUpperCase(),
                            palette: palette,
                            onTap: () => setState(
                              () => _selectedStage =
                                  _selectedStage == stage
                                      ? null
                                      : stage,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                // Task list grouped by project
                for (final group in reportedTasks) ...[
                  // Project header
                  if (reportedTasks.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 4,
                        bottom: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.folder_outlined,
                            size: 15,
                            color: palette.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              group.projectName,
                              style: TextStyle(
                                color: palette.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Tasks in this project
                  ..._filterReportedTasks(group.tasks).map(
                    (rt) => _ReportedTaskCard(
                      reportTask: rt,
                      palette: palette,
                      onTap: () {
                        final isWide = MediaQuery.of(context).size.width >= 768;
                        if (isWide) {
                          showDialog(
                            context: context,
                            builder: (dialogCtx) => Dialog(
                              backgroundColor: palette.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: SizedBox(
                                width: 640,
                                height: 800,
                                child: TaskDetailScreen(
                                  taskId: rt.task.id,
                                  asDialog: true,
                                ),
                              ),
                            ),
                          );
                        } else {
                          context.push('/tasks/${rt.task.id}');
                        }
                      },
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  /// Merge morning tasks with evening status overlay
  List<_ReportedTaskGroup> _buildReportedTasks(
    DailyReport morning,
    DailyReport? evening,
  ) {
    // Build evening task lookup: taskId → DailyReportTask
    final eveningTaskMap = <int, DailyReportTask>{};
    if (evening != null) {
      for (final project in evening.projects) {
        for (final task in project.tasks) {
          eveningTaskMap[task.task.id] = task;
        }
      }
    }

    final groups = <_ReportedTaskGroup>[];
    for (final project in morning.projects) {
      final tasks = <DailyReportTask>[];
      for (final morningTask in project.tasks) {
        // Overlay evening status if available
        final eveningTask = eveningTaskMap[morningTask.task.id];
        tasks.add(eveningTask ?? morningTask);
      }
      groups.add(_ReportedTaskGroup(
        projectName: project.projectName,
        tasks: tasks,
      ));
    }
    return groups;
  }

  /// Filter reported tasks by stage and search
  List<DailyReportTask> _filterReportedTasks(List<DailyReportTask> tasks) {
    var filtered = tasks;
    if (_selectedStage != null) {
      filtered = filtered
          .where(
            (rt) =>
                rt.task.stage != null &&
                rt.task.stage!.name.toUpperCase() ==
                    _selectedStage!.toUpperCase(),
          )
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered
          .where((rt) => rt.task.name.toLowerCase().contains(q))
          .toList();
    }
    return filtered;
  }

  List<String> _extractStages(List<DailyReportTask> tasks) {
    final stages = <String>{};
    for (final rt in tasks) {
      if (rt.task.stage != null && rt.task.stage!.name.isNotEmpty) {
        stages.add(rt.task.stage!.name.toUpperCase());
      }
    }
    const order = [
      'BACKLOG',
      'MUST',
      'CODING',
      'STAGING',
      'PRODUCTION',
      'COMPLETED',
    ];
    final sorted = stages.toList()
      ..sort((a, b) {
        final ia = order.indexOf(a);
        final ib = order.indexOf(b);
        if (ia == -1 && ib == -1) return a.compareTo(b);
        if (ia == -1) return 1;
        if (ib == -1) return -1;
        return ia.compareTo(ib);
      });
    return sorted;
  }
}

class _ReportedTaskGroup {
  final String projectName;
  final List<DailyReportTask> tasks;

  const _ReportedTaskGroup({
    required this.projectName,
    required this.tasks,
  });
}

class _ReportedTaskCard extends StatelessWidget {
  const _ReportedTaskCard({
    required this.reportTask,
    required this.palette,
    required this.onTap,
  });

  final DailyReportTask reportTask;
  final AppThemePalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final task = reportTask.task;
    final stageColor = _reportedTaskStageColor(task.stage?.name, palette);
    final hasPriority = task.priority > 0;
    final hasEveningStatus = reportTask.status != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasEveningStatus && reportTask.isDone
                ? AppColors.online.withOpacity(0.3)
                : palette.surfaceVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task name
            Text(
              task.name,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Bottom row: stage badge + evening status + priority
            Row(
              children: [
                // Stage badge
                if (task.stage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: stageColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      task.stage!.name.toUpperCase(),
                      style: TextStyle(
                        color: stageColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                // Evening status badge
                if (hasEveningStatus) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: reportTask.isDone
                          ? AppColors.online.withOpacity(0.15)
                          : Colors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      reportTask.isDone
                          ? '✓ Done'
                          : 'Doing ${reportTask.progress ?? 0}%',
                      style: TextStyle(
                        color: reportTask.isDone
                            ? AppColors.online
                            : Colors.blue,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                // QC stats
                if (reportTask.qcDone != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'D:${reportTask.qcDone} M:${reportTask.qcMiss ?? 0} F:${reportTask.qcFail ?? 0}',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const Spacer(),
                // Priority star
                if (hasPriority)
                  Icon(
                    Icons.star,
                    size: 16,
                    color: task.priority >= 2
                        ? Colors.amber
                        : palette.textSecondary,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Color _reportedTaskStageColor(String? stageName, AppThemePalette palette) {
  if (stageName == null) return palette.textSecondary;
  switch (stageName.toUpperCase()) {
    case 'BACKLOG':
      return Colors.blueGrey;
    case 'MUST':
      return Colors.orange;
    case 'CODING':
      return Colors.blue;
    case 'STAGING':
      return Colors.purple;
    case 'PRODUCTION':
      return Colors.teal;
    case 'COMPLETED':
      return AppColors.online;
    default:
      return palette.textSecondary;
  }
}



class _TaskStageFilterChip extends StatelessWidget {
  const _TaskStageFilterChip({
    required this.label,
    required this.isSelected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final AppThemePalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _chipColor(label);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : palette.surfaceVariant,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : palette.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Color _chipColor(String label) {
    switch (label.toUpperCase()) {
      case 'BACKLOG':
        return Colors.blueGrey;
      case 'MUST':
        return Colors.orange;
      case 'CODING':
        return Colors.blue;
      case 'STAGING':
        return Colors.purple;
      case 'PRODUCTION':
        return Colors.teal;
      case 'COMPLETED':
        return AppColors.online;
      default:
        return palette.primary;
    }
  }
}
