import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_notifier.dart';
import '../../features/hr/hr_role_utils.dart';
import 'chat_route_utils.dart';
import '../../features/chat/screens/chat_list_screen.dart';
import '../theme/theme_color_presets.dart';

List<String> _rootTabRoutes({
  required bool isAdmin,
  required bool canManageEmployees,
}) {
  return ['/chat', '/hr', if (isAdmin) '/overview', '/tasks', '/profile'];
}

List<int> _rootTabBranchIndices({
  required bool isAdmin,
  required bool canManageEmployees,
}) {
  return [0, 1, if (isAdmin) 3, 4, 5];
}

@visibleForTesting
int rootTabIndexForLocation(
  String location,
  bool isAdmin, {
  bool canManageEmployees = false,
}) {
  final routes = _rootTabRoutes(
    isAdmin: isAdmin,
    canManageEmployees: canManageEmployees,
  );
  return routes.indexWhere((route) => location.startsWith(route));
}

@visibleForTesting
bool shouldShowRootBottomNavigation(
  String location,
  bool isAdmin, {
  bool canManageEmployees = false,
}) {
  return _rootTabRoutes(
    isAdmin: isAdmin,
    canManageEmployees: canManageEmployees,
  ).any((route) => location == route);
}

class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final auth = authState.valueOrNull;
    final roles = auth?.user?.roles ?? const <String>[];
    final isAdmin = roles.contains('admin');
    final canManageEmployees = canManageEmployeesForRoles(roles);
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 768;
    final currentUri = GoRouterState.of(context).uri;
    final location = currentUri.path;
    final isChatRoute = location.startsWith('/chat');
    final showBottomNavigation = shouldShowRootBottomNavigation(
      location,
      isAdmin,
      canManageEmployees: canManageEmployees,
    );

    if (isWide) {
      return _buildWideLayout(
        isAdmin: isAdmin,
        canManageEmployees: canManageEmployees,
        isChatRoute: isChatRoute,
        location: location,
        routeKey: currentUri.toString(),
      );
    }
    return _buildNarrowLayout(
      isAdmin: isAdmin,
      canManageEmployees: canManageEmployees,
      showBottomNavigation: showBottomNavigation,
      routeKey: currentUri.toString(),
    );
  }

  void _onDestinationSelected(
    int index,
    bool isAdmin,
    bool canManageEmployees,
  ) {
    final branchIndex = _branchIndexForNavIndex(
      index,
      isAdmin,
      canManageEmployees,
    );
    if (branchIndex == widget.navigationShell.currentIndex) return;
    HapticFeedback.selectionClick();
    widget.navigationShell.goBranch(branchIndex);
  }

  int _navIndexForBranchIndex(
    int branchIndex,
    bool isAdmin,
    bool canManageEmployees,
  ) {
    final branches = _rootTabBranchIndices(
      isAdmin: isAdmin,
      canManageEmployees: canManageEmployees,
    );
    final index = branches.indexOf(branchIndex);
    return index < 0 ? 0 : index;
  }

  int _branchIndexForNavIndex(
    int navIndex,
    bool isAdmin,
    bool canManageEmployees,
  ) {
    final branches = _rootTabBranchIndices(
      isAdmin: isAdmin,
      canManageEmployees: canManageEmployees,
    );
    if (navIndex < 0 || navIndex >= branches.length) return 0;
    return branches[navIndex];
  }

  Widget _buildWideLayout({
    required bool isAdmin,
    required bool canManageEmployees,
    required bool isChatRoute,
    required String location,
    required String routeKey,
  }) {
    final palette = context.appPalette;
    final currentIndex = widget.navigationShell.currentIndex;
    final selectedIndex = _navIndexForBranchIndex(
      currentIndex,
      isAdmin,
      canManageEmployees,
    );
    final selectedConvId = conversationIdForChatLocation(location);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex >= 0 ? selectedIndex : 0,
            backgroundColor: palette.surface,
            indicatorColor: palette.primary.withValues(alpha: 0.15),
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (index) =>
                _onDestinationSelected(index, isAdmin, canManageEmployees),
            destinations: [
              NavigationRailDestination(
                icon: Icon(Icons.chat_outlined, color: palette.textSecondary),
                selectedIcon: Icon(Icons.chat, color: palette.primary),
                label: const Text('Chat'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outlined, color: palette.textSecondary),
                selectedIcon: Icon(Icons.people, color: palette.primary),
                label: const Text('HR'),
              ),
              if (isAdmin)
                NavigationRailDestination(
                  icon: _AdminOverviewNavIcon(
                    palette: palette,
                    selected: false,
                  ),
                  selectedIcon: _AdminOverviewNavIcon(
                    palette: palette,
                    selected: true,
                  ),
                  label: const Text('BXH'),
                ),
              NavigationRailDestination(
                icon: Icon(Icons.work_outline, color: palette.textSecondary),
                selectedIcon: Icon(Icons.work, color: palette.primary),
                label: const Text('Work'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_outlined, color: palette.textSecondary),
                selectedIcon: Icon(Icons.person, color: palette.primary),
                label: const Text('Profile'),
              ),
            ],
          ),
          if (isChatRoute) ...[
            SizedBox(
              width: 320,
              child: ChatListScreen(
                isEmbedded: true,
                selectedConversationId: selectedConvId,
              ),
            ),
            VerticalDivider(width: 1, color: palette.surfaceVariant),
            Expanded(
              child: selectedConvId != null
                  ? KeyedSubtree(
                      key: ValueKey(selectedConvId),
                      child: widget.navigationShell,
                    )
                  : const _EmptyChatPanel(),
            ),
          ] else
            Expanded(
              child: KeyedSubtree(
                key: ValueKey(routeKey),
                child: widget.navigationShell,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout({
    required bool isAdmin,
    required bool canManageEmployees,
    required bool showBottomNavigation,
    required String routeKey,
  }) {
    final palette = context.appPalette;
    final currentIndex = widget.navigationShell.currentIndex;
    final selectedIndex = _navIndexForBranchIndex(
      currentIndex,
      isAdmin,
      canManageEmployees,
    );

    return Scaffold(
      body: KeyedSubtree(
        key: ValueKey(routeKey),
        child: widget.navigationShell,
      ),
      bottomNavigationBar: showBottomNavigation
          ? NavigationBar(
              selectedIndex: selectedIndex >= 0 ? selectedIndex : 0,
              animationDuration: const Duration(milliseconds: 300),
              onDestinationSelected: (index) =>
                  _onDestinationSelected(index, isAdmin, canManageEmployees),
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.chat_outlined, color: palette.textSecondary),
                  selectedIcon: Icon(Icons.chat, color: palette.primary),
                  label: 'Chat',
                ),
                NavigationDestination(
                  icon: Icon(
                    Icons.people_outlined,
                    color: palette.textSecondary,
                  ),
                  selectedIcon: Icon(Icons.people, color: palette.primary),
                  label: 'HR',
                ),
                if (isAdmin)
                  NavigationDestination(
                    icon: _AdminOverviewNavIcon(
                      palette: palette,
                      selected: false,
                    ),
                    selectedIcon: _AdminOverviewNavIcon(
                      palette: palette,
                      selected: true,
                    ),
                    label: 'BXH',
                  ),
                NavigationDestination(
                  icon: Icon(Icons.work_outline, color: palette.textSecondary),
                  selectedIcon: Icon(Icons.work, color: palette.primary),
                  label: 'Work',
                ),
                NavigationDestination(
                  icon: Icon(
                    Icons.person_outlined,
                    color: palette.textSecondary,
                  ),
                  selectedIcon: Icon(Icons.person, color: palette.primary),
                  label: 'Profile',
                ),
              ],
            )
          : null,
    );
  }
}

class _AdminOverviewNavIcon extends StatelessWidget {
  const _AdminOverviewNavIcon({required this.palette, required this.selected});

  final AppThemePalette palette;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Icon(
      selected ? Icons.emoji_events_rounded : Icons.emoji_events_outlined,
      color: selected ? palette.primary : palette.textSecondary,
    );
  }
}

class _EmptyChatPanel extends StatelessWidget {
  const _EmptyChatPanel();

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_outlined, size: 64, color: palette.textHint),
            const SizedBox(height: 16),
            Text(
              'Chọn cuộc trò chuyện',
              style: TextStyle(color: palette.textSecondary, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
