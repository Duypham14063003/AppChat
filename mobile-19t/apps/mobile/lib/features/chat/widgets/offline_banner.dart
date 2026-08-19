import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/connection_banner_policy.dart';
import '../../../core/network/websocket_manager.dart';
import '../../../core/network/websocket_provider.dart';
import '../../../core/theme/app_colors.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wsState = ref.watch(webSocketConnectionProvider);
    final connectionState = wsState.valueOrNull ?? WsConnectionState.connected;
    final recoveryStartedAt = ref.watch(
      recentConnectionRecoveryStartedAtProvider,
    );
    final now =
        ref.watch(connectionBannerNowProvider).valueOrNull ?? DateTime.now();
    final presentation = resolveConnectionBannerPresentation(
      connectionState: connectionState,
      now: now,
      recoveryStartedAt: recoveryStartedAt,
    );

    if (!presentation.isVisible) {
      return const SizedBox.shrink();
    }

    final isSoft = presentation.severity == ConnectionBannerSeverity.soft;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: isSoft
          ? AppColors.gold.withOpacity(0.1)
          : AppColors.warning.withOpacity(0.2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (presentation.showSpinner)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.gold.withOpacity(0.7),
                ),
              ),
            )
          else
            const Icon(Icons.cloud_off, size: 14, color: AppColors.warning),
          const SizedBox(width: 8),
          Text(
            presentation.message ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSoft
                  ? AppColors.gold.withOpacity(0.8)
                  : AppColors.warning,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
