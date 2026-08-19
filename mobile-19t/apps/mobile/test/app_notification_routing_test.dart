import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nineteen_tech_app/app.dart';
import 'package:nineteen_tech_app/core/network/connection_banner_policy.dart';
import 'package:nineteen_tech_app/core/network/websocket_manager.dart';
import 'package:nineteen_tech_app/features/auth/providers/auth_notifier.dart';

void main() {
  group('routeForNotificationData', () {
    test('routes chat notifications to the conversation screen', () {
      expect(
        routeForNotificationData({'conv_id': 'conv-123'}),
        '/chat/conv-123',
      );
    });

    test('routes HR reminder notifications to the attendance screen', () {
      expect(routeForNotificationData({'type': 'hr_checkin_reminder'}), '/hr');
      expect(routeForNotificationData({'type': 'hr_checkout_reminder'}), '/hr');
      expect(routeForNotificationData({'type': 'hr_auto_checkout'}), '/hr');
    });

    test('routes PoC pushes and weekly deep links', () {
      expect(
        routeForNotificationData({'type': 'poc', 'poc_id': 'poc-123'}),
        '/pocs/poc-123',
      );
      expect(
        routeForNotificationData({
          'type': 'poc_weekly_summary',
          'deep_link': '/pocs/week?week=2026-08-10',
        }),
        '/pocs/week?week=2026-08-10',
      );
    });

    test(
      'routes HR contract action reminders to the contract detail screen',
      () {
        expect(
          routeForNotificationData({
            'type': 'hr_contract_action_reminder',
            'user_id': 'user-123',
            'contract_id': 'contract-456',
          }),
          '/hr/employees/user-123/contracts/contract-456',
        );
      },
    );

    test(
      'falls back to HR when contract action reminder payload is incomplete',
      () {
        expect(
          routeForNotificationData({'type': 'hr_contract_action_reminder'}),
          '/hr',
        );
      },
    );

    test('returns null for unsupported payloads', () {
      expect(routeForNotificationData({'type': 'unknown'}), isNull);
    });
  });

  group('navigationModeForNotificationRoute', () {
    test('uses go navigation for chat conversation routes', () {
      expect(
        navigationModeForNotificationRoute('/chat/conv-123'),
        NotificationNavigationMode.go,
      );
    });

    test('uses go navigation for shell destinations', () {
      expect(
        navigationModeForNotificationRoute('/hr'),
        NotificationNavigationMode.go,
      );
    });
  });

  group('shouldSkipNotificationNavigation', () {
    test('skips re-entry when target route is already current', () {
      expect(
        shouldSkipNotificationNavigation(
          currentLocation: '/chat/conv-123',
          targetRoute: '/chat/conv-123',
        ),
        isTrue,
      );
    });

    test('does not skip when target route differs from current', () {
      expect(
        shouldSkipNotificationNavigation(
          currentLocation: '/chat',
          targetRoute: '/chat/conv-123',
        ),
        isFalse,
      );
    });
  });

  group('shouldRefreshAttendanceForNotificationData', () {
    test('refreshes attendance for auto-checkout notifications only', () {
      expect(
        shouldRefreshAttendanceForNotificationData({
          'type': 'hr_auto_checkout',
        }),
        isTrue,
      );
      expect(
        shouldRefreshAttendanceForNotificationData({
          'type': 'hr_checkin_reminder',
        }),
        isFalse,
      );
      expect(
        shouldRefreshAttendanceForNotificationData({
          'type': 'hr_checkout_reminder',
        }),
        isFalse,
      );
    });
  });

  group('shouldSyncChatListOnResume', () {
    test('refreshes chat list only when app returns to foreground', () {
      expect(shouldSyncChatListOnResume(AppLifecycleState.resumed), isTrue);
      expect(shouldSyncChatListOnResume(AppLifecycleState.inactive), isFalse);
      expect(shouldSyncChatListOnResume(AppLifecycleState.paused), isFalse);
      expect(shouldSyncChatListOnResume(AppLifecycleState.detached), isFalse);
    });
  });

  group('shouldRecoverWebSocketForAuthState', () {
    test(
      'recovers authenticated sessions whenever websocket is not connected',
      () {
        const authenticated = AsyncData(
          AuthState(status: AuthStatus.authenticated),
        );

        expect(
          shouldRecoverWebSocketForAuthState(
            authState: authenticated,
            wsState: WsConnectionState.disconnected,
          ),
          isTrue,
        );
        expect(
          shouldRecoverWebSocketForAuthState(
            authState: authenticated,
            wsState: WsConnectionState.connecting,
          ),
          isTrue,
        );
        expect(
          shouldRecoverWebSocketForAuthState(
            authState: authenticated,
            wsState: WsConnectionState.connected,
          ),
          isFalse,
        );
      },
    );

    test('does not recover unauthenticated or unresolved sessions', () {
      expect(
        shouldRecoverWebSocketForAuthState(
          authState: const AsyncData(AuthState.unauthenticated),
          wsState: WsConnectionState.disconnected,
        ),
        isFalse,
      );
      expect(
        shouldRecoverWebSocketForAuthState(
          authState: const AsyncLoading<AuthState>(),
          wsState: WsConnectionState.disconnected,
        ),
        isFalse,
      );
    });
  });

  group('shouldStartConnectionRecoveryWindow', () {
    test('starts only while websocket is not connected', () {
      expect(
        shouldStartConnectionRecoveryWindow(WsConnectionState.disconnected),
        isTrue,
      );
      expect(
        shouldStartConnectionRecoveryWindow(WsConnectionState.connecting),
        isTrue,
      );
      expect(
        shouldStartConnectionRecoveryWindow(WsConnectionState.connected),
        isFalse,
      );
    });
  });

  group('connection banner presentation policy', () {
    final baseTime = DateTime(2026, 7, 15, 14, 30);

    test('preserves the original recovery start while outage is ongoing', () {
      final originalStart = baseTime.subtract(const Duration(seconds: 5));

      expect(
        nextConnectionRecoveryStartedAt(
          connectionState: WsConnectionState.disconnected,
          now: baseTime,
          currentRecoveryStartedAt: originalStart,
        ),
        originalStart,
      );
    });

    test(
      'starts a recovery window when a non-connected state has no timer',
      () {
        expect(
          nextConnectionRecoveryStartedAt(
            connectionState: WsConnectionState.connecting,
            now: baseTime,
            currentRecoveryStartedAt: null,
          ),
          baseTime,
        );
      },
    );

    test('suppresses transient reconnect states during the grace period', () {
      final presentation = resolveConnectionBannerPresentation(
        connectionState: WsConnectionState.disconnected,
        now: baseTime,
        recoveryStartedAt: baseTime.subtract(const Duration(seconds: 1)),
      );

      expect(presentation.severity, ConnectionBannerSeverity.hidden);
      expect(presentation.isVisible, isFalse);
    });

    test('shows a soft reconnect banner after the grace period', () {
      final presentation = resolveConnectionBannerPresentation(
        connectionState: WsConnectionState.disconnected,
        now: baseTime,
        recoveryStartedAt: baseTime.subtract(const Duration(seconds: 4)),
      );

      expect(presentation.severity, ConnectionBannerSeverity.soft);
      expect(presentation.message, 'Đang khôi phục kết nối...');
      expect(presentation.showSpinner, isTrue);
      expect(presentation.showRetry, isFalse);
    });

    test('escalates to a hard banner when reconnect stays unresolved', () {
      final presentation = resolveConnectionBannerPresentation(
        connectionState: WsConnectionState.disconnected,
        now: baseTime,
        recoveryStartedAt: baseTime.subtract(const Duration(seconds: 9)),
      );

      expect(presentation.severity, ConnectionBannerSeverity.hard);
      expect(presentation.message, 'Kết nối đang gián đoạn');
      expect(presentation.showSpinner, isFalse);
      expect(presentation.showRetry, isTrue);
    });

    test(
      'keeps app-shell and chat-shell decisions aligned via shared policy',
      () {
        final appShellPresentation = resolveConnectionBannerPresentation(
          connectionState: WsConnectionState.connecting,
          now: baseTime,
          recoveryStartedAt: baseTime.subtract(const Duration(seconds: 5)),
        );
        final chatShellPresentation = resolveConnectionBannerPresentation(
          connectionState: WsConnectionState.connecting,
          now: baseTime,
          recoveryStartedAt: baseTime.subtract(const Duration(seconds: 5)),
        );

        expect(chatShellPresentation.severity, appShellPresentation.severity);
        expect(chatShellPresentation.message, appShellPresentation.message);
        expect(
          chatShellPresentation.showSpinner,
          appShellPresentation.showSpinner,
        );
        expect(chatShellPresentation.showRetry, appShellPresentation.showRetry);
      },
    );
  });

  group('shouldEnableOfflineQueueForAuthStatus', () {
    test('enables queue only for authenticated sessions', () {
      expect(
        shouldEnableOfflineQueueForAuthStatus(AuthStatus.authenticated),
        isTrue,
      );
      expect(
        shouldEnableOfflineQueueForAuthStatus(AuthStatus.unauthenticated),
        isFalse,
      );
    });
  });

  group('shouldShowForegroundNotificationForData', () {
    test('suppresses chat notifications for the active conversation', () {
      expect(
        shouldShowForegroundNotificationForData(
          data: {'conv_id': 'conv-1'},
          currentLocation: '/chat/conv-1',
        ),
        isFalse,
      );
    });

    test('shows chat notifications for a different conversation', () {
      expect(
        shouldShowForegroundNotificationForData(
          data: {'conv_id': 'conv-2'},
          currentLocation: '/chat/conv-1',
        ),
        isTrue,
      );
    });

    test('shows non-chat notifications while app is open', () {
      expect(
        shouldShowForegroundNotificationForData(
          data: {'type': 'hr_checkin_reminder'},
          currentLocation: '/chat/conv-1',
        ),
        isTrue,
      );
    });
  });

  group('foregroundNotificationEventIdForData', () {
    test('prefers the generic id key when present', () {
      expect(
        foregroundNotificationEventIdForData({
          'id': 'msg-1',
          'message_id': 'msg-2',
        }),
        'msg-1',
      );
    });

    test('falls back to message_id for chat payloads', () {
      expect(
        foregroundNotificationEventIdForData({'message_id': 'msg-2'}),
        'msg-2',
      );
    });

    test('falls back to reminder_id for reminder payloads', () {
      expect(
        foregroundNotificationEventIdForData({'reminder_id': 'rem-1'}),
        'rem-1',
      );
    });

    test('falls back to leave_id for leave payloads', () {
      expect(
        foregroundNotificationEventIdForData({'leave_id': 'leave-1'}),
        'leave-1',
      );
    });

    test('returns null when no known event id exists', () {
      expect(
        foregroundNotificationEventIdForData({'type': 'hr_checkin_reminder'}),
        isNull,
      );
    });
  });

  group('rememberForegroundNotificationEvent', () {
    test('accepts first event id and rejects duplicate', () {
      final recentIds = Queue<String>();
      final recentIdSet = <String>{};

      expect(
        rememberForegroundNotificationEvent(
          recentIds: recentIds,
          recentIdSet: recentIdSet,
          messageId: 'msg-1',
          maxTracked: 3,
        ),
        isTrue,
      );
      expect(
        rememberForegroundNotificationEvent(
          recentIds: recentIds,
          recentIdSet: recentIdSet,
          messageId: 'msg-1',
          maxTracked: 3,
        ),
        isFalse,
      );
    });

    test('trims tracked ids when cache grows beyond max size', () {
      final recentIds = Queue<String>();
      final recentIdSet = <String>{};

      expect(
        rememberForegroundNotificationEvent(
          recentIds: recentIds,
          recentIdSet: recentIdSet,
          messageId: 'msg-1',
          maxTracked: 2,
        ),
        isTrue,
      );
      expect(
        rememberForegroundNotificationEvent(
          recentIds: recentIds,
          recentIdSet: recentIdSet,
          messageId: 'msg-2',
          maxTracked: 2,
        ),
        isTrue,
      );
      expect(
        rememberForegroundNotificationEvent(
          recentIds: recentIds,
          recentIdSet: recentIdSet,
          messageId: 'msg-3',
          maxTracked: 2,
        ),
        isTrue,
      );

      expect(recentIds, ['msg-2', 'msg-3']);
      expect(recentIdSet.contains('msg-1'), isFalse);
    });
  });
}
