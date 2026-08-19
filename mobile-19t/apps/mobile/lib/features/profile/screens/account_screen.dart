import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:nineteen_tech_app/core/theme/app_typography.dart';
import 'package:nineteen_tech_app/core/notifications/push_notification_service.dart';
import 'package:nineteen_tech_app/core/theme/app_colors.dart';
import 'package:nineteen_tech_app/core/theme/theme_color_presets.dart';
import 'package:nineteen_tech_app/core/utils/snackbar_utils.dart';
import 'package:nineteen_tech_app/features/auth/data/auth_repository.dart';
import 'package:nineteen_tech_app/features/auth/providers/auth_notifier.dart';
import 'package:nineteen_tech_app/features/hr/providers/hr_providers.dart';
import 'package:nineteen_tech_app/shared/widgets/heart_header_badge.dart';

final accountDeviceIdProvider = FutureProvider<String?>((ref) async {
  final storage = ref.read(secureTokenStorageProvider);
  return storage.getDeviceId();
});

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  int _tapCount = 0;

  void _onHeaderTap() {
    setState(() {
      _tapCount++;
    });
    if (_tapCount == 5) {
      _tapCount = 0;
      _showDebugDialog();
    }
  }

  void _resetTapCount() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _tapCount = 0);
      }
    });
  }

  Future<void> _sendTestApnsPush(String voipToken) async {
    try {
      developer.log(
        '🔧 [APNS] Sending immediate APNS push with VoIP token: '
        '${voipToken.substring(0, 20)}...',
      );
      final dio = Dio();
      final response = await dio.post(
        'http://192.168.1.67:3002/api/v1/test-apns',
        data: {
          'token': voipToken,
          'type': 'call_invite',
          'callerName': 'Test User',
        },
      );

      if (!mounted) return;

      final success = response.data?['success'] ?? false;
      final message = response.data?['message'] ?? 'Response received';

      developer.log('🔧 [APNS] Response: success=$success, message=$message');

      showTopSnackBar(
        context,
        message: success
            ? '✅ APNS push sent! Check your device.'
            : '❌ $message',
        backgroundColor: success ? AppColors.online : AppColors.danger,
      );
    } catch (e) {
      developer.log('🔧 [APNS] Error: $e');
      if (!mounted) return;
      showTopSnackBar(
        context,
        message: '❌ Failed to send: ${e.toString()}',
        backgroundColor: AppColors.danger,
      );
    }
  }

  Future<void> _sendTestApnsPushDelayed(String voipToken) async {
    try {
      developer.log(
        '⏱️ [APNS-DELAYED] Scheduled APNS push in 30s with VoIP token: '
        '${voipToken.substring(0, 20)}...',
      );

      showTopSnackBar(
        context,
        message:
            '⏱️ APNS push scheduled for 30 seconds - close app now to test!',
        backgroundColor: AppColors.warning,
      );

      await Future.delayed(const Duration(seconds: 30));
      developer.log('⏱️ [APNS-DELAYED] Sending delayed APNS push...');

      final dio = Dio();
      final response = await dio.post(
        'http://192.168.1.67:3002/api/v1/test-apns',
        data: {
          'token': voipToken,
          'type': 'call_invite',
          'callerName': 'Delayed Test User',
        },
      );

      final success = response.data?['success'] ?? false;
      developer.log('⏱️ [APNS-DELAYED] Response: success=$success');
    } catch (e) {
      developer.log('⏱️ [APNS-DELAYED] Error: $e');
    }
  }

  Future<void> _triggerIncomingCall(String voipToken) async {
    try {
      developer.log(
        '📞 [INCOMING-CALL] Triggering incoming call with VoIP token: '
        '${voipToken.substring(0, 20)}...',
      );

      final dio = Dio();
      final response = await dio.post(
        'http://192.168.1.67:3002/api/v1/test-apns',
        data: {
          'token': voipToken,
          'type': 'call_invite',
          'callerName': 'John Doe',
          'callId': 'test-call-${DateTime.now().millisecondsSinceEpoch}',
        },
      );

      if (!mounted) return;

      final success = response.data?['success'] ?? false;
      developer.log('📞 [INCOMING-CALL] Response: success=$success');

      showTopSnackBar(
        context,
        message: success
            ? '📞 Incoming call triggered! Expect ringtone...'
            : '❌ Failed to trigger call',
        backgroundColor: success ? AppColors.info : AppColors.danger,
      );
    } catch (e) {
      developer.log('📞 [INCOMING-CALL] Error: $e');
      if (!mounted) return;
      showTopSnackBar(
        context,
        message: '❌ Failed: ${e.toString()}',
        backgroundColor: AppColors.danger,
      );
    }
  }

  Future<void> _showDebugDialog() async {
    final storage = ref.read(secureTokenStorageProvider);
    final fcmToken = await storage.getFcmToken();
    final voipToken = await storage.getVoipToken();
    final deviceId = await storage.getDeviceId();
    final authState = ref.read(authNotifierProvider);

    if (!mounted) return;

    final palette = context.appPalette;
    final user = authState.when(
      data: (auth) => auth.user,
      loading: () => null,
      error: (_, __) => null,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text(
          '🔧 Debug Info',
          style: AppTypography.titleLarge.copyWith(color: palette.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DebugRow(
                label: 'Role',
                value: user?.roles.isEmpty ?? true
                    ? 'No role'
                    : user!.roles.join(', '),
              ),
              _DebugRow(label: 'User ID', value: user?.id ?? 'N/A'),
              _DebugRow(label: 'Device ID', value: deviceId ?? 'N/A'),
              _DebugRow(
                label: 'FCM Token',
                value: fcmToken?.substring(0, 30) ?? 'N/A',
                isMono: true,
              ),
              _DebugRow(
                label: 'VoIP Token',
                value: voipToken?.substring(0, 30) ?? 'N/A',
                isMono: true,
              ),
              if (voipToken != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'APNS Test Cases',
                    style: AppTypography.labelLarge.copyWith(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: double.maxFinite,
                    child: FilledButton(
                      onPressed: () => _sendTestApnsPush(voipToken),
                      child: const Text('📲 Send APNS Now'),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SizedBox(
                    width: double.maxFinite,
                    child: FilledButton(
                      onPressed: () {
                        _sendTestApnsPushDelayed(voipToken);
                        Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.warning.withValues(
                          alpha: 0.8,
                        ),
                      ),
                      child: const Text('⏱️ Send APNS in 30s (close app!)'),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SizedBox(
                    width: double.maxFinite,
                    child: FilledButton(
                      onPressed: () => _triggerIncomingCall(voipToken),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.info.withValues(alpha: 0.8),
                      ),
                      child: const Text('📞 Trigger Incoming Call'),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.maxFinite,
                    child: FilledButton.tonal(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: voipToken));
                        Navigator.pop(context);
                        showTopSnackBar(context, message: 'Copied VoIP token');
                      },
                      child: const Text('Copy VoIP Token'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: AppTypography.labelLarge.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    scheduleRewardWalletFreshnessCheck(ref);
    final authState = ref.watch(authNotifierProvider);
    final isWide = MediaQuery.of(context).size.width >= 768;
    final palette = context.appPalette;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: authState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(message: error.toString()),
          data: (auth) {
            final user = auth.user;
            if (user == null) {
              return const _ErrorState(
                message: 'Không tìm thấy dữ liệu tài khoản.',
              );
            }

            final content = ListView(
              padding: EdgeInsets.fromLTRB(
                isWide ? 32 : 20,
                16,
                isWide ? 32 : 20,
                28,
              ),
              children: [
                _AccountTopBar(
                  user: user,
                  onEditPressed: () =>
                      _showEditProfileSheet(context, ref, user),
                  onLeaderboardPressed: () =>
                      context.push('/rewards/leaderboard'),
                  onLogoutPressed: () => _confirmLogout(context),
                  onAdminConfigsPressed: () =>
                      context.push('/rewards/admin/configs'),
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () {
                    _onHeaderTap();
                    _resetTapCount();
                  },
                  child: _HeaderCard(user: user),
                ),
                const SizedBox(height: 18),
                _HeartWarehouseCard(isWide: isWide),
                const SizedBox(height: 18),
                const _WorkOverviewSection(),
                const SizedBox(height: 18),
                _ProfileDetailSection(
                  title: 'Thông tin cá nhân',
                  rows: [
                    _DetailRowData(label: 'Họ tên', value: user.name),
                    _DetailRowData(label: 'Email', value: user.email),
                    _DetailRowData(
                      label: 'Số điện thoại',
                      value: _fallbackText(user.phoneNumber),
                    ),
                    _DetailRowData(
                      label: 'Phòng ban',
                      value: _fallbackText(user.department),
                    ),
                    _DetailRowData(
                      label: 'Chức danh',
                      value: _fallbackText(user.jobTitle),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('open-employee-payment-profile'),
                    onPressed: () => context.push('/hr/employees/me'),
                    icon: const Icon(Icons.account_balance_outlined),
                    label: const Text('Thông tin ngân hàng & QR'),
                  ),
                ),
                const SizedBox(height: 16),
                const _InfoSection(
                  title: 'Tùy chỉnh hiển thị',
                  children: [_ThemePresetSection()],
                ),
                // const SizedBox(height: 16),
                // _ProfileDetailSection(
                //   title: 'Tài khoản & thiết bị',
                //   rows: [
                //     _DetailRowData(
                //       label: 'Vai trò',
                //       value: user.roles.isEmpty
                //           ? 'Chưa có role'
                //           : user.roles.join(', '),
                //     ),
                //     _DetailRowData(
                //       label: 'Trạng thái',
                //       value: _fallbackText(
                //         _employmentStatusLabel(user.employmentStatus),
                //       ),
                //     ),
                //     _DetailRowData(
                //       label: 'Device ID',
                //       value: deviceIdAsync.when(
                //         loading: () => 'Đang tải...',
                //         error: (_, _) => 'Không đọc được',
                //         data: (value) => value ?? 'Chưa có',
                //       ),
                //       mono: true,
                //     ),
                //   ],
                // ),
                // if (kDebugMode) ...[
                //   const SizedBox(height: 16),
                //   const _PushDebugSection(),
                // ],
              ],
            );

            if (!isWide) return content;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: content,
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final palette = context.appPalette;
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: palette.surface,
          title: Text(
            'Đăng xuất',
            style: AppTypography.titleLarge.copyWith(
              color: palette.textPrimary,
            ),
          ),
          content: Text(
            'Bạn có chắc muốn đăng xuất khỏi thiết bị này không?',
            style: AppTypography.bodyMedium.copyWith(
              color: palette.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Hủy',
                style: AppTypography.labelLarge.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Đăng xuất',
                style: AppTypography.labelLarge.copyWith(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await ref.read(authNotifierProvider.notifier).logout();
    }
  }

  Future<void> _showEditProfileSheet(
    BuildContext context,
    WidgetRef ref,
    UserInfo user,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditProfileSheet(user: user),
    );
  }
}

enum _AccountMenuAction { edit, leaderboard, logout, adminConfigs }

class _AccountTopBar extends StatelessWidget {
  const _AccountTopBar({
    required this.user,
    required this.onEditPressed,
    required this.onLeaderboardPressed,
    required this.onLogoutPressed,
    required this.onAdminConfigsPressed,
  });

  final UserInfo user;
  final VoidCallback onEditPressed;
  final VoidCallback onLeaderboardPressed;
  final VoidCallback onLogoutPressed;
  final VoidCallback onAdminConfigsPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final department = _cleanText(user.department);
    final employmentStatus = _employmentStatusLabel(user.employmentStatus);
    final meta = [department, employmentStatus].whereType<String>().join(' • ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Xin chào',
                style: AppTypography.headlineMedium.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // const SizedBox(height: 6),
              // Text(
              //   user.name,
              //   style: AppTypography.headlineLarge.copyWith(
              //     color: palette.textPrimary,
              //     fontWeight: FontWeight.w800,
              //     height: 1.04,
              //   ),
              // ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  meta,
                  style: AppTypography.bodyLarge.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        // const HeartHeaderBadge(compact: true),
        const SizedBox(width: 10),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: palette.surface,
            shape: BoxShape.circle,
            border: _profileSurfaceBorder(palette),
            boxShadow: _profileFloatingShadow(palette, blur: 18, offsetY: 8),
          ),
          child: PopupMenuButton<_AccountMenuAction>(
            tooltip: 'Tùy chọn hồ sơ',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: palette.surface,
            icon: Icon(Icons.more_horiz_rounded, color: palette.textPrimary),
            onSelected: (action) {
              switch (action) {
                case _AccountMenuAction.edit:
                  onEditPressed();
                  return;
                case _AccountMenuAction.leaderboard:
                  onLeaderboardPressed();
                  return;
                case _AccountMenuAction.logout:
                  onLogoutPressed();
                  return;
                case _AccountMenuAction.adminConfigs:
                  onAdminConfigsPressed();
                  return;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<_AccountMenuAction>(
                value: _AccountMenuAction.edit,
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, color: palette.textPrimary),
                    const SizedBox(width: 10),
                    Text(
                      'Chỉnh sửa hồ sơ',
                      style: AppTypography.bodyMedium.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<_AccountMenuAction>(
                value: _AccountMenuAction.leaderboard,
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      color: palette.textPrimary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Bảng xếp hạng',
                      style: AppTypography.bodyMedium.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (user.roles.contains('admin'))
                PopupMenuItem<_AccountMenuAction>(
                  value: _AccountMenuAction.adminConfigs,
                  child: Row(
                    children: [
                      Icon(
                        Icons.settings_suggest_outlined,
                        color: palette.textPrimary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Cấu hình thưởng',
                        style: AppTypography.bodyMedium.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              PopupMenuItem<_AccountMenuAction>(
                value: _AccountMenuAction.logout,
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded, color: AppColors.danger),
                    const SizedBox(width: 10),
                    Text(
                      'Đăng xuất',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PushDebugSection extends ConsumerStatefulWidget {
  const _PushDebugSection();

  @override
  ConsumerState<_PushDebugSection> createState() => _PushDebugSectionState();
}

class _PushDebugSectionState extends ConsumerState<_PushDebugSection> {
  String? _fcmToken;
  String? _status;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStoredToken();
    });
  }

  Future<void> _loadStoredToken() async {
    final storage = ref.read(secureTokenStorageProvider);
    final token = await storage.getFcmToken();
    if (!mounted) return;
    setState(() => _fcmToken = token);
  }

  Future<void> _runAction(
    Future<String> Function(PushNotificationService service, String deviceId)
    action,
  ) async {
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
      _status = null;
    });

    final service = ref.read(pushNotificationServiceProvider);
    final storage = ref.read(secureTokenStorageProvider);
    final deviceId = await storage.getOrCreateDeviceId();

    try {
      final status = await action(service, deviceId);
      if (!mounted) return;
      setState(() => _status = status);
      showTopSnackBar(context, message: status);
    } catch (e) {
      final status = 'Push debug failed: $e';
      if (!mounted) return;
      setState(() => _status = status);
      showTopSnackBar(
        context,
        message: status,
        backgroundColor: AppColors.danger,
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<String> _getFcmToken(
    PushNotificationService service,
    String deviceId,
  ) async {
    final token = await service.getCurrentToken();
    if (!mounted) {
      return token == null
          ? 'Không lấy được FCM token'
          : 'Đã lấy FCM token cho device $deviceId';
    }
    setState(() => _fcmToken = token);
    return token == null
        ? 'Không lấy được FCM token'
        : 'Đã lấy FCM token cho device $deviceId';
  }

  Future<String> _refreshFcmToken(
    PushNotificationService service,
    String deviceId,
  ) async {
    final token = await service.refreshCurrentToken();
    if (mounted) {
      setState(() => _fcmToken = token);
    }
    return token == null
        ? 'Refresh FCM token thất bại'
        : 'Đã refresh FCM token cho device $deviceId';
  }

  Future<String> _updateFcmToken(
    PushNotificationService service,
    String deviceId,
  ) async {
    final token = _fcmToken ?? await service.getCurrentToken();
    if (mounted) {
      setState(() => _fcmToken = token);
    }
    final result = await service.updateCurrentToken(
      deviceId: deviceId,
      token: token,
    );
    final prefix = result.success ? 'Update thành công' : 'Update thất bại';
    return '$prefix: ${result.message}';
  }

  Future<String> _copyBackendTestCommand(
    PushNotificationService service,
    String deviceId,
  ) async {
    final token = _fcmToken ?? await service.getCurrentToken();
    if (mounted) {
      setState(() => _fcmToken = token);
    }

    if (token == null || token.isEmpty) {
      return 'Không có FCM token để copy command';
    }

    final command =
        'GOOGLE_APPLICATION_CREDENTIALS="\$PWD/t-mobile-9b640-firebase-adminsdk-fbsvc-d34a610e1a.json" '
        'FIREBASE_PROJECT_ID=t-mobile-9b640 '
        'FCM_TOKEN="$token" '
        'node -e "const admin=require(\'firebase-admin\'); '
        'admin.initializeApp({credential: admin.credential.applicationDefault(), projectId: process.env.FIREBASE_PROJECT_ID}); '
        'admin.messaging().send({token: process.env.FCM_TOKEN, notification:{title:\'Test push\', body:\'Push test from backend-mobile-19t\'}, data:{type:\'manual_test\'}})'
        '.then(id=>{console.log(\'push-ok\', id); process.exit(0);})'
        '.catch(err=>{console.error(\'push-failed\', err.message); process.exit(1);});"';
    await Clipboard.setData(ClipboardData(text: command));
    return 'Đã copy lệnh test backend cho device $deviceId';
  }

  @override
  Widget build(BuildContext context) {
    final deviceIdAsync = ref.watch(accountDeviceIdProvider);

    return _InfoSection(
      title: 'Push Debug',
      children: [
        _InfoTile(
          icon: Icons.bug_report_outlined,
          label: 'Device ID dùng để test',
          value: deviceIdAsync.when(
            loading: () => 'Đang tải...',
            error: (_, _) => 'Không đọc được',
            data: (value) => value ?? 'Chưa có',
          ),
          mono: true,
        ),
        _InfoTile(
          icon: Icons.key_outlined,
          label: 'FCM Token hiện tại',
          value: _fcmToken ?? 'Chưa lấy token',
          mono: true,
        ),
        if (_status != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 12),
            child: Text(
              _status!,
              style: AppTypography.bodySmall.copyWith(
                color: context.appPalette.primary,
              ),
            ),
          ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _DebugActionButton(
              label: 'Get FCM Token',
              icon: Icons.vpn_key_outlined,
              onPressed: _isBusy ? null : () => _runAction(_getFcmToken),
            ),
            _DebugActionButton(
              label: 'Refresh FCM Token',
              icon: Icons.refresh_rounded,
              onPressed: _isBusy ? null : () => _runAction(_refreshFcmToken),
            ),
            _DebugActionButton(
              label: 'Update FCM Token',
              icon: Icons.cloud_upload_outlined,
              onPressed: _isBusy ? null : () => _runAction(_updateFcmToken),
            ),
            _DebugActionButton(
              label: 'Copy backend test command',
              icon: Icons.copy_all_outlined,
              onPressed: _isBusy
                  ? null
                  : () => _runAction(_copyBackendTestCommand),
            ),
          ],
        ),
      ],
    );
  }
}

class _ThemePresetSection extends ConsumerWidget {
  const _ThemePresetSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPreset = ref.watch(themePresetProvider);
    final appPalette = context.appPalette;

    return Column(
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
                    'Bảng màu giao diện',
                    style: AppTypography.bodyLarge.copyWith(
                      color: appPalette.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            PopupMenuButton<AppThemePreset>(
              tooltip: 'Chọn bảng màu',
              color: appPalette.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (preset) async {
                await ref.read(themePresetProvider.notifier).setPreset(preset);
              },
              itemBuilder: (context) => AppThemePreset.values.map((preset) {
                final palette = preset.palette;
                final isSelected = preset == currentPreset;
                return PopupMenuItem<AppThemePreset>(
                  value: preset,
                  child: Row(
                    children: [
                      _ThemePalettePreview(
                        palette: palette,
                        size: 28,
                        radius: 10,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          palette.name,
                          style: AppTypography.bodyMedium.copyWith(
                            color: appPalette.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_rounded, color: appPalette.primary),
                    ],
                  ),
                );
              }).toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: appPalette.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: _profileSurfaceBorder(appPalette),
                  boxShadow: _profileFloatingShadow(
                    appPalette,
                    blur: 16,
                    offsetY: 7,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ThemePalettePreview(
                      palette: currentPreset.palette,
                      size: 26,
                      radius: 9,
                    ),
                    const SizedBox(width: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 116),
                      child: Text(
                        currentPreset.palette.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelLarge.copyWith(
                          color: appPalette.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: appPalette.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          currentPreset.palette.description,
          style: AppTypography.bodySmall.copyWith(
            color: appPalette.textSecondary,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _ThemePalettePreview extends StatelessWidget {
  const _ThemePalettePreview({
    required this.palette,
    this.size = 72,
    this.radius = 18,
  });

  final AppThemePalette palette;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final previewColors = [
      palette.primary,
      palette.primaryLight,
      palette.surfaceVariant,
      palette.card,
    ];

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.backgroundTop, palette.backgroundBottom],
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: previewColors.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: size * 0.08,
          mainAxisSpacing: size * 0.08,
        ),
        itemBuilder: (context, index) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: previewColors[index],
              borderRadius: BorderRadius.circular(size * 0.12),
            ),
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.user});

  final UserInfo user;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final initials = _buildInitials(user.name, user.email);
    final avatarUrl = user.avatarUrl;
    final titleLine = _cleanText(user.department) ?? _cleanText(user.jobTitle);
    final statusLabel = _employmentStatusLabel(user.employmentStatus);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: palette.surface,
        border: _profileSurfaceBorder(palette),
        boxShadow: _profileCardShadow(palette),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [palette.primaryLight, palette.primaryDark],
              ),
            ),
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? Text(
                    initials,
                    style: AppTypography.headlineMedium.copyWith(
                      color: palette.isLight
                          ? Colors.white
                          : palette.background,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) {
                      return Text(
                        initials,
                        style: AppTypography.headlineSmall.copyWith(
                          color: palette.isLight
                              ? Colors.white
                              : palette.background,
                          fontWeight: FontWeight.w800,
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account',
                  style: AppTypography.bodyMedium.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.name,
                  style: AppTypography.headlineMedium.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (titleLine != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    titleLine,
                    style: AppTypography.titleMedium.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                ],
                if (statusLabel != null) ...[
                  const SizedBox(height: 12),
                  _SoftStatusChip(label: statusLabel),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildInitials(String name, String email) {
    final source = name.trim().isNotEmpty ? name.trim() : email.trim();
    final parts = source
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

class _HeartWarehouseCard extends ConsumerWidget {
  const _HeartWarehouseCard({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appPalette;
    const accent = Color(0xFFC78A12);
    final hintText = palette.isLight
        ? const Color(0xFF7D7A74)
        : palette.textSecondary;
    final points = ref.watch(authNotifierProvider).valueOrNull?.points;

    return Container(
      padding: EdgeInsets.all(isWide ? 18 : 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: palette.surface,
        border: Border.all(
          color: accent.withValues(alpha: palette.isLight ? 0.4 : 0.55),
        ),
        boxShadow: _profileCardShadow(palette),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _HeartWarehouseVisual(isWide: isWide),
          SizedBox(width: isWide ? 16 : 10),
          Expanded(
            child: _HeartWarehouseContent(
              hintText: hintText,
              pointsLabel: formatHeartPoints(points),
            ),
          ),
          SizedBox(width: isWide ? 14 : 10),
          _HeartWarehouseActions(isWide: isWide, accent: accent),
        ],
      ),
    );
  }
}

class _HeartWarehouseVisual extends StatelessWidget {
  const _HeartWarehouseVisual({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFC78A12);
    const softAccent = Color(0xFFFFF7E8);

    return Container(
      width: isWide ? 112 : 86,
      height: isWide ? 112 : 86,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [softAccent, Color(0x99FFF7E8), Colors.transparent],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: isWide ? 16 : 12,
            right: isWide ? 16 : 10,
            child: Icon(
              Icons.auto_awesome,
              color: accent,
              size: isWide ? 14 : 12,
            ),
          ),
          Positioned(
            bottom: isWide ? 16 : 8,
            left: isWide ? 8 : 4,
            child: Icon(
              Icons.auto_awesome,
              color: accent,
              size: isWide ? 15 : 13,
            ),
          ),
          SizedBox(
            width: isWide ? 84 : 64,
            height: isWide ? 84 : 64,
            child: Lottie.asset(
              'assets/animation/heart.json',
              repeat: true,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeartWarehouseContent extends StatelessWidget {
  const _HeartWarehouseContent({
    required this.hintText,
    required this.pointsLabel,
  });

  final Color hintText;
  final String pointsLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    const accent = Color(0xFFC78A12);
    final compact = MediaQuery.of(context).size.width < 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Flexible(
              child: Text(
                'Kho tim',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleMedium.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w400,
                  fontSize: compact ? 12 : 18,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
        SizedBox(height: compact ? 4 : 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: pointsLabel,
                  style: AppTypography.headlineMedium.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    fontSize: compact ? 14 : 32,
                  ),
                ),
                TextSpan(
                  text: ' Tim',
                  style: AppTypography.titleMedium.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 14 : 18,
                  ),
                ),
              ],
            ),
          ),
        ),
        // const SizedBox(height: 8),
        // Text(
        //   'Cố gắng mỗi ngày, tích lũy tym từ những đóng góp tuyệt vời ✨',
        //   style: AppTypography.bodyMedium.copyWith(
        //     color: hintText,
        //     height: 1.45,
        //   ),
        // ),
      ],
    );
  }
}

class _HeartWarehouseActions extends StatelessWidget {
  const _HeartWarehouseActions({required this.isWide, required this.accent});

  final bool isWide;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: isWide ? 156 : 132,
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push('/rewards/shop'),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: isWide ? 12 : 10),
                // shape: RoundedRectangleBorder(
                //   borderRadius: BorderRadius.circular(14),
                // ),
              ),
              icon: Icon(Icons.card_giftcard_outlined, size: isWide ? 18 : 15),
              label: Text(
                'Đổi quà',
                style: AppTypography.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // radius: BorderRadius.circular(14),
          ),
          SizedBox(height: isWide ? 10 : 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/rewards/transactions'),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent.withValues(alpha: 0.35)),
                padding: EdgeInsets.symmetric(vertical: isWide ? 12 : 10),
                // shape: RoundedRectangleBorder(
                //   borderRadius: BorderRadius.circular(14),
                // ),
              ),
              icon: Icon(Icons.history, size: isWide ? 18 : 15),
              label: Text(
                'Lịch sử tim',
                style: AppTypography.labelMedium.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkOverviewSection extends ConsumerStatefulWidget {
  const _WorkOverviewSection();

  @override
  ConsumerState<_WorkOverviewSection> createState() =>
      _WorkOverviewSectionState();
}

class _WorkOverviewSectionState extends ConsumerState<_WorkOverviewSection> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final config = ref
        .read(authNotifierProvider)
        .valueOrNull
        ?.payrollStartConfig;
    _selectedMonth = resolveCurrentPayrollMonth(config ?? 1);
  }

  String get _monthKey =>
      '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';

  List<DateTime> get _monthOptions {
    final config = ref
        .read(authNotifierProvider)
        .valueOrNull
        ?.payrollStartConfig;
    final current = resolveCurrentPayrollMonth(config ?? 1);
    return List<DateTime>.generate(
      6,
      (index) => DateTime(current.year, current.month - index),
      growable: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final summaryAsync = ref.watch(attendanceSummaryProvider(_monthKey));
    final configAsync = ref.watch(payrollConfigProvider);
    final standardDays = _resolveStandardDays(configAsync.valueOrNull);

    return Container(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tổng quan công việc',
                  style: AppTypography.titleSmall.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              PopupMenuButton<DateTime>(
                tooltip: 'Chọn tháng',
                color: palette.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (month) {
                  setState(
                    () => _selectedMonth = DateTime(month.year, month.month),
                  );
                },
                itemBuilder: (context) => _monthOptions.map((month) {
                  final isSelected =
                      month.year == _selectedMonth.year &&
                      month.month == _selectedMonth.month;
                  return PopupMenuItem<DateTime>(
                    value: month,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _monthLabel(month),
                            style: AppTypography.bodyMedium.copyWith(
                              color: palette.textPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_rounded, color: palette.primary),
                      ],
                    ),
                  );
                }).toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: _profileSurfaceBorder(palette),
                    boxShadow: _profileFloatingShadow(
                      palette,
                      blur: 16,
                      offsetY: 7,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _monthLabel(_selectedMonth),
                        style: AppTypography.bodyMedium.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: palette.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          summaryAsync.when(
            loading: () => _WorkSummaryRow(
              items: [
                _WorkSummaryItem(
                  value: '--',
                  label: 'Tổng ngày công',
                  helper: '/ $standardDays ngày làm việc',
                ),
                _WorkSummaryItem(
                  value: '--',
                  label: 'Ngày off',
                  helper: '/ $standardDays ngày làm việc',
                ),
                const _WorkSummaryItem(
                  value: '--',
                  label: 'Giờ OT',
                  helper: 'Tổng trong tháng',
                ),
              ],
            ),
            error: (error, stackTrace) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WorkSummaryRow(
                  items: [
                    _WorkSummaryItem(
                      value: '--',
                      label: 'Tổng ngày công',
                      helper: '/ $standardDays ngày làm việc',
                    ),
                    _WorkSummaryItem(
                      value: '--',
                      label: 'Ngày off',
                      helper: '/ $standardDays ngày làm việc',
                    ),
                    const _WorkSummaryItem(
                      value: '--',
                      label: 'Giờ OT',
                      helper: 'Tổng trong tháng',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Chưa tải được số liệu tháng này từ HR.',
                  style: AppTypography.bodySmall.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
            data: (summary) {
              final totalOff = summary.paidLeaveDays + summary.unpaidLeaveDays;
              return _WorkSummaryRow(
                items: [
                  _WorkSummaryItem(
                    value: _formatMetric(summary.totalDays),
                    label: 'Tổng ngày công',
                    helper: '/ $standardDays ngày làm việc',
                  ),
                  _WorkSummaryItem(
                    value: _formatMetric(totalOff),
                    label: 'Ngày off',
                    helper: '/ $standardDays ngày làm việc',
                  ),
                  _WorkSummaryItem(
                    value: '${_formatMetric(summary.totalOt)}h',
                    label: 'Giờ OT',
                    helper: 'Tổng trong tháng',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _monthLabel(DateTime month) {
    final config = ref
        .read(authNotifierProvider)
        .valueOrNull
        ?.payrollStartConfig;
    final current = resolveCurrentPayrollMonth(config ?? 1);
    if (month.year == current.year && month.month == current.month) {
      return 'Tháng này';
    }
    if (month.year == current.year) {
      return 'Tháng ${month.month}';
    }
    return 'Tháng ${month.month}/${month.year}';
  }
}

class _WorkSummaryRow extends StatelessWidget {
  const _WorkSummaryRow({required this.items});

  final List<_WorkSummaryItem> items;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return IntrinsicHeight(
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            Expanded(child: _WorkMetricCard(item: items[index])),
            if (index != items.length - 1)
              VerticalDivider(
                width: 22,
                thickness: 1,
                color: palette.surfaceVariant,
              ),
          ],
        ],
      ),
    );
  }
}

class _WorkMetricCard extends StatelessWidget {
  const _WorkMetricCard({required this.item});

  final _WorkSummaryItem item;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.value,
          style: AppTypography.headlineMedium.copyWith(
            color: palette.primary,
            fontWeight: FontWeight.w600,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          item.label,
          style: AppTypography.bodyMedium.copyWith(
            color: palette.textPrimary,
            fontWeight: FontWeight.w500,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          item.helper,
          style: AppTypography.caption.copyWith(
            color: palette.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _WorkSummaryItem {
  const _WorkSummaryItem({
    required this.value,
    required this.label,
    required this.helper,
  });

  final String value;
  final String label;
  final String helper;
}

class _ProfileDetailSection extends StatelessWidget {
  const _ProfileDetailSection({required this.title, required this.rows});

  final String title;
  final List<_DetailRowData> rows;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Container(
      padding: const EdgeInsets.all(10),
      // decoration: BoxDecoration(
      //   color: palette.surface.withValues(alpha: 0.96),
      //   borderRadius: BorderRadius.circular(24),
      //   border: _profileSurfaceBorder(palette),
      //   boxShadow: _profileCardShadow(palette),
      // ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.titleMedium.copyWith(
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < rows.length; index++) ...[
            _ProfileDetailRow(data: rows[index]),
            if (index != rows.length - 1)
              Divider(height: 1, color: palette.surfaceVariant),
          ],
        ],
      ),
    );
  }
}

class _DetailRowData {
  const _DetailRowData({
    required this.label,
    required this.value,
    this.mono = false,
  });

  final String label;
  final String value;
  final bool mono;
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({required this.data});

  final _DetailRowData data;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              data.label,
              style: AppTypography.bodyLarge.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: data.mono
                ? SelectableText(
                    data.value,
                    textAlign: TextAlign.right,
                    style: AppTypography.labelMedium.copyWith(
                      color: palette.textPrimary,
                      height: 1.35,
                    ),
                  )
                : Text(
                    data.value,
                    textAlign: TextAlign.right,
                    style: AppTypography.bodyLarge.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SoftStatusChip extends StatelessWidget {
  const _SoftStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: palette.isLight ? 0.10 : 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.labelMedium.copyWith(
          color: palette.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.user});

  final UserInfo user;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  String? _statusMessage;
  String? _errorMessage;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  String? _previewAvatarUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _phoneController = TextEditingController(
      text: widget.user.phoneNumber ?? '',
    );
    _previewAvatarUrl = widget.user.avatarUrl;
  }

  @override
  void didUpdateWidget(covariant _EditProfileSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.name != widget.user.name &&
        _nameController.text != widget.user.name) {
      _nameController.text = widget.user.name;
    }
    if (oldWidget.user.phoneNumber != widget.user.phoneNumber &&
        _phoneController.text != (widget.user.phoneNumber ?? '')) {
      _phoneController.text = widget.user.phoneNumber ?? '';
    }
    if (oldWidget.user.avatarUrl != widget.user.avatarUrl) {
      _previewAvatarUrl = widget.user.avatarUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_isSaving || _isUploadingAvatar) return;

    setState(() {
      _isUploadingAvatar = true;
      _statusMessage = null;
      _errorMessage = null;
    });

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (image == null) {
        if (!mounted) return;
        setState(() => _isUploadingAvatar = false);
        return;
      }

      final updatedUser = await ref
          .read(authNotifierProvider.notifier)
          .uploadAvatar(image);

      if (!mounted) return;
      setState(() {
        _previewAvatarUrl = updatedUser.avatarUrl;
        _statusMessage = 'Đã cập nhật ảnh đại diện.';
      });
      showTopSnackBar(context, message: 'Đã cập nhật avatar');
    } on DioException catch (e) {
      final message = e.response?.data is Map
          ? (e.response!.data as Map)['message'] as String?
          : null;
      if (!mounted) return;
      setState(() {
        _errorMessage = message ?? 'Upload ảnh thất bại.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    final trimmedName = _nameController.text.trim();
    final trimmedPhone = _phoneController.text.trim();

    if (trimmedName.isEmpty) {
      setState(() {
        _errorMessage = 'Tên hiển thị không được để trống.';
        _statusMessage = null;
      });
      return;
    }

    if (trimmedPhone.isEmpty) {
      setState(() {
        _errorMessage = 'Số điện thoại không được để trống.';
        _statusMessage = null;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _statusMessage = null;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authNotifierProvider.notifier)
          .updateProfile(name: trimmedName, phoneNumber: trimmedPhone);
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Cập nhật thông tin cá nhân thành công.';
      });
      showTopSnackBar(context, message: 'Đã lưu thông tin cá nhân');
      Navigator.of(context).pop();
    } on DioException catch (e) {
      final message = e.response?.data is Map
          ? (e.response!.data as Map)['message'] as String?
          : null;
      if (!mounted) return;
      setState(() {
        _errorMessage = message ?? 'Cập nhật thông tin thất bại.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final avatarUrl = _previewAvatarUrl?.trim() ?? '';
    final initials = _buildInitials(
      _nameController.text.trim().isEmpty
          ? widget.user.name
          : _nameController.text.trim(),
      widget.user.email,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, bottomInset + 12),
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(28),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Chỉnh sửa hồ sơ',
                        style: AppTypography.headlineSmall.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Đổi tên bằng nút lưu. Nhấn vào avatar để upload ảnh đại diện mới ngay.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: palette.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: GestureDetector(
                    onTap: _isUploadingAvatar || _isSaving
                        ? null
                        : _pickAndUploadAvatar,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 108,
                          height: 108,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                palette.primaryLight,
                                palette.primaryDark,
                              ],
                            ),
                            border: Border.all(
                              color: palette.primary.withValues(alpha: 0.35),
                              width: 2,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          alignment: Alignment.center,
                          child: avatarUrl.isEmpty
                              ? Text(
                                  initials,
                                  style: AppTypography.headlineMedium.copyWith(
                                    color: palette.isLight
                                        ? Colors.white
                                        : palette.background,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              : Image.network(
                                  avatarUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) {
                                    return Text(
                                      initials,
                                      style: AppTypography.headlineMedium
                                          .copyWith(
                                            color: palette.isLight
                                                ? Colors.white
                                                : palette.background,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    );
                                  },
                                ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: palette.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: palette.surface,
                                width: 3,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: _isUploadingAvatar
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: palette.isLight
                                          ? Colors.black
                                          : palette.background,
                                    ),
                                  )
                                : Icon(
                                    Icons.camera_alt_outlined,
                                    size: 18,
                                    color: palette.isLight
                                        ? Colors.black
                                        : palette.background,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    onPressed: _isUploadingAvatar || _isSaving
                        ? null
                        : _pickAndUploadAvatar,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      _isUploadingAvatar
                          ? 'Đang tải ảnh...'
                          : 'Đổi ảnh đại diện',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: palette.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  style: AppTypography.bodyLarge.copyWith(
                    color: palette.textPrimary,
                  ),
                  decoration: _buildInputDecoration(
                    context,
                    label: 'Tên hiển thị',
                    hint: 'Nguyen Van A',
                    icon: Icons.person_outline,
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _isSaving ? null : _saveProfile(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.phone,
                  style: AppTypography.bodyLarge.copyWith(
                    color: palette.textPrimary,
                  ),
                  decoration: _buildInputDecoration(
                    context,
                    label: 'Số điện thoại',
                    hint: '0901234567',
                    icon: Icons.phone_outlined,
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _isSaving ? null : _saveProfile(),
                ),
                const SizedBox(height: 12),
                if (_statusMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _statusMessage!,
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.green.shade600,
                      ),
                    ),
                  ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _errorMessage!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isUploadingAvatar || _isSaving
                            ? null
                            : _pickAndUploadAvatar,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.textPrimary,
                          side: BorderSide(
                            color: palette.primary.withValues(alpha: 0.35),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: _isUploadingAvatar
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: palette.primary,
                                ),
                              )
                            : const Icon(Icons.photo_library_outlined),
                        label: Text(
                          _isUploadingAvatar ? 'Đang upload...' : 'Đổi avatar',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.primary,
                          foregroundColor: palette.isLight
                              ? Colors.black
                              : palette.background,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: _isSaving
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: palette.isLight
                                      ? Colors.black
                                      : palette.background,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_isSaving ? 'Đang lưu...' : 'Lưu'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildInitials(String name, String email) {
    final source = name.trim().isNotEmpty ? name.trim() : email.trim();
    final parts = source
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

InputDecoration _buildInputDecoration(
  BuildContext context, {
  required String label,
  required String hint,
  required IconData icon,
}) {
  final palette = context.appPalette;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: palette.surfaceVariant),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon, color: palette.primary),
    filled: true,
    fillColor: palette.card,
    labelStyle: AppTypography.bodyMedium.copyWith(color: palette.textSecondary),
    hintStyle: AppTypography.bodyMedium.copyWith(color: palette.textHint),
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: palette.primary, width: 1.4),
    ),
    errorBorder: border.copyWith(
      borderSide: const BorderSide(color: AppColors.danger),
    ),
    focusedErrorBorder: border.copyWith(
      borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
    ),
  );
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Container(
      padding: const EdgeInsets.all(10),
      // decoration: BoxDecoration(
      //   color: palette.surface.withValues(alpha: 0.94),
      //   borderRadius: BorderRadius.circular(24),
      //   border: _profileSurfaceBorder(palette),
      //   boxShadow: _profileCardShadow(palette),
      // ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.titleMedium.copyWith(
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.mono = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: palette.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.bodySmall.copyWith(
                    color: palette.textHint,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  value,
                  style:
                      (mono
                              ? AppTypography.labelMedium
                              : AppTypography.bodyLarge)
                          .copyWith(color: palette.textPrimary, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HintTile extends StatelessWidget {
  const _HintTile({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: palette.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyMedium.copyWith(
                color: palette.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.danger,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(Icons.logout_rounded, color: Colors.white),
        label: Text(
          'Đăng xuất',
          style: AppTypography.labelLarge.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

class _DebugActionButton extends StatelessWidget {
  const _DebugActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.textPrimary,
        side: BorderSide(color: palette.primary.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: AppTypography.labelLarge.copyWith(color: palette.textPrimary),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_outlined, size: 56, color: palette.textHint),
            const SizedBox(height: 12),
            Text(
              message,
              style: AppTypography.bodyMedium.copyWith(
                color: palette.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

String? _cleanText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

String _fallbackText(String? value, {String empty = 'Chưa cập nhật'}) {
  return _cleanText(value) ?? empty;
}

String? _employmentStatusLabel(String? status) {
  switch (_cleanText(status)?.toLowerCase()) {
    case 'official':
      return 'Nhân viên chính thức';
    case 'probation':
      return 'Nhân viên thử việc';
    case 'intern':
      return 'Thực tập sinh';
    case 'contractor':
      return 'Cộng tác viên';
    case 'part_time':
      return 'Bán thời gian';
    case 'full_time':
      return 'Toàn thời gian';
    case null:
      return null;
    default:
      return _titleCase(status!);
  }
}

String _titleCase(String value) {
  return value
      .split(RegExp(r'[_\s]+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

int _resolveStandardDays(Map<String, dynamic>? config) {
  final raw =
      config?['standard_days_per_month'] ??
      config?['working_days_per_month'] ??
      config?['standardDaysPerMonth'];
  if (raw is num) return raw.toInt();
  if (raw is String) {
    return int.tryParse(raw) ?? 22;
  }
  return 22;
}

// Debug Helper Widget
class _DebugRow extends StatelessWidget {
  const _DebugRow({
    required this.label,
    required this.value,
    this.isMono = false,
  });

  final String label;
  final String value;
  final bool isMono;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: palette.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.maxFinite,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: palette.surfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              value,
              style:
                  (isMono ? AppTypography.bodySmall : AppTypography.bodySmall)
                      .copyWith(
                        color: palette.textPrimary,
                        fontFamily: isMono ? 'monospace' : null,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatMetric(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}

BoxBorder? _profileSurfaceBorder(AppThemePalette palette) {
  if (palette.isLight) return null;
  return Border.all(color: palette.surfaceVariant.withValues(alpha: 0.34));
}

List<BoxShadow>? _profileCardShadow(AppThemePalette palette) {
  if (!palette.isLight) return null;
  return [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.035),
      blurRadius: 30,
      offset: const Offset(0, 14),
    ),
  ];
}

List<BoxShadow>? _profileFloatingShadow(
  AppThemePalette palette, {
  double blur = 16,
  double offsetY = 7,
}) {
  if (!palette.isLight) return null;
  return [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.028),
      blurRadius: blur,
      offset: Offset(0, offsetY),
    ),
  ];
}
