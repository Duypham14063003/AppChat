import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nineteen_tech_app/features/auth/providers/auth_notifier.dart';
import 'package:nineteen_tech_app/features/auth/screens/login_screen.dart';
import 'package:nineteen_tech_app/features/auth/screens/splash_screen.dart';
import 'package:nineteen_tech_app/features/chat/screens/chat_list_screen.dart';
import 'package:nineteen_tech_app/features/chat/screens/chat_screen.dart';
import 'package:nineteen_tech_app/features/chat/screens/bookmarked_messages_screen.dart';
import 'package:nineteen_tech_app/features/chat/screens/global_bookmarked_messages_screen.dart';
import 'package:nineteen_tech_app/features/chat/screens/contact_picker_screen.dart';
import 'package:nineteen_tech_app/features/chat/screens/group_create_members_screen.dart';
import 'package:nineteen_tech_app/features/chat/screens/group_create_name_screen.dart';
import 'package:nineteen_tech_app/features/chat/screens/direct_chat_info_screen.dart';
import 'package:nineteen_tech_app/features/chat/screens/group_info_screen.dart';
import 'package:nineteen_tech_app/features/chat/screens/forward_chat_picker_screen.dart';
import 'package:nineteen_tech_app/features/chat/screens/pinned_messages_screen.dart';
import 'package:nineteen_tech_app/features/hr/data/hr_models.dart';
import 'package:nineteen_tech_app/features/hr/hr_role_utils.dart';
import 'package:nineteen_tech_app/features/hr/screens/leave_list_screen.dart';
import 'package:nineteen_tech_app/features/hr/screens/attendance_screen.dart';
import 'package:nineteen_tech_app/features/hr/screens/attendance_history_screen.dart';
import 'package:nineteen_tech_app/features/hr/screens/hr_overview_screen.dart';
import 'package:nineteen_tech_app/features/hr/screens/employee_management_screens.dart';
import 'package:nineteen_tech_app/features/hr/screens/daily_report_audit_log_screen.dart';
import 'package:nineteen_tech_app/features/hr/screens/leave_create_screen.dart';
import 'package:nineteen_tech_app/features/hr/screens/leave_detail_screen.dart';
import 'package:nineteen_tech_app/features/hr/screens/payroll_config_screen.dart';
import 'package:nineteen_tech_app/features/hr/screens/reward_admin_config_screen.dart';
import 'package:nineteen_tech_app/features/hr/screens/weekly_schedule_screen.dart';
import 'package:nineteen_tech_app/features/profile/screens/account_screen.dart';
import 'package:nineteen_tech_app/features/profile/screens/reward_leaderboard_screen.dart';
import 'package:nineteen_tech_app/features/profile/screens/reward_shop_screen.dart';
import 'package:nineteen_tech_app/features/profile/screens/reward_transactions_screen.dart';
import 'package:nineteen_tech_app/features/task/screens/task_list_screen.dart';
import 'package:nineteen_tech_app/features/task/screens/task_detail_screen.dart';
import 'package:nineteen_tech_app/features/poc/screens/work_shell_screen.dart';
import 'package:nineteen_tech_app/features/poc/screens/poc_assignment_screen.dart';
import 'package:nineteen_tech_app/features/poc/screens/poc_capacity_screen.dart';
import 'package:nineteen_tech_app/features/poc/screens/poc_detail_screen.dart';
import 'package:nineteen_tech_app/features/poc/screens/poc_form_screen.dart';
import 'package:nineteen_tech_app/features/poc/screens/poc_weekly_report_screen.dart';
import 'package:nineteen_tech_app/features/call/screens/call_screen.dart';
import 'package:nineteen_tech_app/features/call/screens/incoming_call_screen.dart';
import 'package:nineteen_tech_app/features/call/screens/outgoing_call_screen.dart';
import 'main_shell.dart';
import 'animated_page_route.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final _routerRefreshNotifierProvider = Provider<_RouterRefreshNotifier>((ref) {
  final notifier = _RouterRefreshNotifier();
  ref.listen<AsyncValue<AuthState>>(authNotifierProvider, (previous, next) {
    notifier.refresh();
  });
  ref.onDispose(notifier.dispose);
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(_routerRefreshNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final location = state.matchedLocation;
      final isOnSplash = location == '/splash';
      final isOnLogin = location == '/login';

      return authState.when(
        loading: () {
          if (isOnSplash || isOnLogin) return null;
          return '/splash';
        },
        error: (e, _) => isOnLogin ? null : '/login',
        data: (auth) {
          final isAuthenticated = auth.status == AuthStatus.authenticated;
          final roles = auth.user?.roles ?? const <String>[];
          final canManageEmployees = canManageEmployeesForRoles(roles);
          if (isOnSplash) {
            return isAuthenticated ? '/chat' : '/login';
          }
          if (!isAuthenticated && !isOnLogin) return '/login';
          if (isAuthenticated && isOnLogin) return '/chat';
          if ((location.startsWith('/employees') ||
                  location.startsWith('/hr/employees')) &&
              !canManageEmployees) {
            return '/hr';
          }
          return null;
        },
      );
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => const ChatListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => ChatScreen(
                      conversationId: state.pathParameters['id']!,
                      initialMessageId: state.uri.queryParameters['messageId'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/hr',
                builder: (context, state) {
                  final authState = ref.watch(authNotifierProvider);
                  return authState.when(
                    loading: () => const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => const AttendanceScreen(),
                    data: (auth) {
                      final roles = auth.user?.roles ?? const <String>[];
                      if (roles.contains('admin')) {
                        return const LeaveListScreen();
                      }
                      return const AttendanceScreen();
                    },
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/employees',
                builder: (context, state) => const EmployeeDirectoryScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => EmployeeDetailScreen(
                      employeeId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'profile/edit',
                        builder: (context, state) => EmployeeProfileEditScreen(
                          employeeId: state.pathParameters['id']!,
                        ),
                      ),
                      GoRoute(
                        path: 'contracts',
                        builder: (context, state) => EmployeeContractsScreen(
                          employeeId: state.pathParameters['id']!,
                          employeeName:
                              state.uri.queryParameters['name'] ?? 'Nhân viên',
                        ),
                        routes: [
                          GoRoute(
                            path: 'new',
                            builder: (context, state) =>
                                EmployeeContractFormScreen(
                                  employeeId: state.pathParameters['id']!,
                                  mode: EmployeeContractFormMode.create,
                                ),
                          ),
                          GoRoute(
                            path: ':contractId',
                            builder: (context, state) =>
                                EmployeeContractDetailScreen(
                                  employeeId: state.pathParameters['id']!,
                                  contractId:
                                      state.pathParameters['contractId']!,
                                ),
                            routes: [
                              GoRoute(
                                path: 'edit',
                                builder: (context, state) =>
                                    EmployeeContractFormScreen(
                                      employeeId: state.pathParameters['id']!,
                                      contractId:
                                          state.pathParameters['contractId']!,
                                      mode: EmployeeContractFormMode.edit,
                                    ),
                              ),
                              GoRoute(
                                path: 'renew',
                                builder: (context, state) =>
                                    EmployeeContractFormScreen(
                                      employeeId: state.pathParameters['id']!,
                                      contractId:
                                          state.pathParameters['contractId']!,
                                      mode: EmployeeContractFormMode.renew,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/overview',
                builder: (context, state) => const HrOverviewScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tasks',
                builder: (context, state) => const WorkShellScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const AccountScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/bookmarks',
        builder: (context, state) => const GlobalBookmarkedMessagesScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/pocs/new',
        builder: (context, state) => PocFormScreen(
          initialConversationId: state.uri.queryParameters['conversationId'],
          sourceMessageId: state.uri.queryParameters['messageId'],
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/pocs/capacity',
        builder: (context, state) => PocCapacityScreen(
          initialWeek: DateTime.tryParse(
            state.uri.queryParameters['week'] ?? '',
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/pocs/week',
        builder: (context, state) => PocWeeklyReportScreen(
          initialWeek: DateTime.tryParse(
            state.uri.queryParameters['week'] ?? '',
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/pocs/:id/assign',
        builder: (context, state) =>
            PocAssignmentScreen(pocId: state.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/pocs/:id',
        builder: (context, state) =>
            PocDetailScreen(pocId: state.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/forward-chat-picker',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            final sourceConvId = extra['sourceConvId'] as String? ?? '';
            final messageIds =
                (extra['messageIds'] as List?)?.cast<String>() ?? const [];
            return ForwardChatPickerScreen(
              sourceConvId: sourceConvId,
              messageIds: messageIds,
            );
          }

          final legacyMessageIds = extra as List<String>? ?? const [];
          return ForwardChatPickerScreen(
            sourceConvId: '',
            messageIds: legacyMessageIds,
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/chat/:id/info',
        pageBuilder: (context, state) => state.animatedPage(
          child: DirectChatInfoScreen(
            conversationId: state.pathParameters['id']!,
          ),
          type: TransitionType.slideFromRight,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/chat/:id/pins',
        pageBuilder: (context, state) => state.animatedPage(
          child: PinnedMessagesListScreen(
            conversationId: state.pathParameters['id']!,
          ),
          type: TransitionType.slideFromRight,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/chat/:id/bookmarks',
        pageBuilder: (context, state) => state.animatedPage(
          child: BookmarkedMessagesListScreen(
            conversationId: state.pathParameters['id']!,
          ),
          type: TransitionType.slideFromRight,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/contacts/pick',
        pageBuilder: (context, state) => state.animatedPage(
          child: const ContactPickerScreen(),
          type: TransitionType.slideFromBottom,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/group/create/members',
        pageBuilder: (context, state) => state.animatedPage(
          child: const GroupCreateMembersScreen(),
          type: TransitionType.slideFromBottom,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/group/create/name',
        pageBuilder: (context, state) {
          final memberIds = state.extra as List<String>? ?? [];
          return state.animatedPage(
            child: GroupCreateNameScreen(memberIds: memberIds),
            type: TransitionType.slideFromRight,
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/group/:id/info',
        pageBuilder: (context, state) => state.animatedPage(
          child: GroupInfoScreen(conversationId: state.pathParameters['id']!),
          type: TransitionType.slideFromRight,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/hr/history',
        builder: (context, state) => const AttendanceHistoryScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/hr/daily-reports/audit-logs',
        builder: (context, state) => const DailyReportAuditLogScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/hr/employees',
        builder: (context, state) => const EmployeeDirectoryScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/hr/employees/me',
        builder: (context, state) =>
            const EmployeeDetailScreen(employeeId: 'me', isSelf: true),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/hr/employees/:id',
        builder: (context, state) =>
            EmployeeDetailScreen(employeeId: state.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/hr/employees/:id/profile/edit',
        builder: (context, state) => EmployeeProfileEditScreen(
          employeeId: state.pathParameters['id']!,
          isSelf: state.pathParameters['id'] == 'me',
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/hr/employees/:id/contracts',
        builder: (context, state) => EmployeeContractsScreen(
          employeeId: state.pathParameters['id']!,
          employeeName: state.uri.queryParameters['name'] ?? 'Nhân viên',
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/hr/employees/:id/contracts/new',
        builder: (context, state) => EmployeeContractFormScreen(
          employeeId: state.pathParameters['id']!,
          mode: EmployeeContractFormMode.create,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/hr/employees/:id/contracts/:contractId',
        builder: (context, state) => EmployeeContractDetailScreen(
          employeeId: state.pathParameters['id']!,
          contractId: state.pathParameters['contractId']!,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/hr/employees/:id/contracts/:contractId/edit',
        builder: (context, state) => EmployeeContractFormScreen(
          employeeId: state.pathParameters['id']!,
          contractId: state.pathParameters['contractId']!,
          mode: EmployeeContractFormMode.edit,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/hr/employees/:id/contracts/:contractId/renew',
        builder: (context, state) => EmployeeContractFormScreen(
          employeeId: state.pathParameters['id']!,
          contractId: state.pathParameters['contractId']!,
          mode: EmployeeContractFormMode.renew,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/hr/leaves',
        builder: (context, state) => const LeaveListScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/hr/leaves/create',
        builder: (context, state) => const LeaveCreateScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/hr/leaves/:id',
        builder: (context, state) => LeaveDetailScreen(
          leaveId: state.pathParameters['id']!,
          leaveData: state.extra as LeaveRequest?,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/hr/config',
        builder: (context, state) => const PayrollConfigScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/hr/weekly-schedule',
        builder: (context, state) => const WeeklyScheduleScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/rewards/admin/configs',
        builder: (context, state) => const RewardAdminConfigScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/rewards/shop',
        builder: (context, state) => const RewardShopScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/rewards/leaderboard',
        builder: (context, state) => const RewardLeaderboardScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/rewards/transactions',
        builder: (context, state) => const RewardTransactionsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/tasks/projects/:projectId',
        builder: (context, state) => TaskListScreen(
          projectId: int.parse(state.pathParameters['projectId']!),
          projectName: state.extra as String?,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/tasks/:taskId',
        builder: (context, state) => TaskDetailScreen(
          taskId: int.parse(state.pathParameters['taskId']!),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/call/active',
        builder: (context, state) => const CallScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/call/incoming',
        builder: (context, state) => const IncomingCallScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/call/outgoing',
        builder: (context, state) => const OutgoingCallScreen(),
      ),
      // Redirect root to /chat
      GoRoute(path: '/', redirect: (_, state) => '/chat'),
    ],
  );
});

class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}
