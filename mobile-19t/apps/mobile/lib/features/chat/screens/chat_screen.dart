import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../auth/providers/auth_notifier.dart';
import '../data/encrypted_message_adapter.dart';
import '../providers/chat_providers.dart';
import '../widgets/message_item.dart';
import '../widgets/message_input_bar.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/pinned_message_bar.dart';
import '../screens/image_preview_screen.dart';
import '../screens/bookmarked_messages_screen.dart';
import '../screens/pinned_messages_screen.dart';
import '../screens/conversation_reminders_screen.dart';
import '../screens/forward_chat_picker_screen.dart';
import '../providers/chat_reminder_provider.dart';
import '../widgets/message_context_menu.dart';
import '../widgets/poc_system_message_card.dart';
import '../widgets/message_seen_by_sheet.dart';
import '../screens/image_viewer_screen.dart';
import '../screens/video_preview_screen.dart';
import '../screens/video_player_screen.dart';
import '../screens/direct_chat_info_screen.dart';
import '../screens/group_info_screen.dart';
import '../widgets/chat_avatar.dart';
import '../../call/providers/call_notifier.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_interaction.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/network/connection_banner_policy.dart';
import '../../../core/network/websocket_provider.dart';
import '../../../core/network/websocket_manager.dart';

const _scrollToBottomFabThreshold = 0.12;
const _wideConversationPaneMinWidth = 720.0;

@visibleForTesting
const double wideConversationFrameMaxWidth = 1200;

@visibleForTesting
bool shouldUseWideConversationFrame(double paneWidth) {
  return paneWidth >= _wideConversationPaneMinWidth;
}

@visibleForTesting
class ChatConversationFrame extends StatelessWidget {
  const ChatConversationFrame({
    super.key,
    required this.availableWidth,
    required this.child,
    this.expand = false,
  });

  final double availableWidth;
  final Widget child;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final framedChild = expand
        ? SizedBox.expand(child: child)
        : SizedBox(width: double.infinity, child: child);

    if (!shouldUseWideConversationFrame(availableWidth)) {
      return child;
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: wideConversationFrameMaxWidth,
        ),
        child: framedChild,
      ),
    );
  }
}

class _ChatWallpaper extends StatelessWidget {
  const _ChatWallpaper({required this.palette});

  final AppThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final patternColor = palette.isLight
        ? palette.primary.withValues(alpha: 0.10)
        : palette.primary.withValues(alpha: 0.18);
    final topGlow = palette.primary.withValues(
      alpha: palette.isLight ? 0.05 : 0.09,
    );
    final bottomGlow = palette.primaryDark.withValues(
      alpha: palette.isLight ? 0.06 : 0.10,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.backgroundTop,
            palette.background,
            palette.backgroundBottom,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: palette.isLight ? 0.92 : 0.8,
              child: SvgPicture.asset(
                'assets/Images/background.svg',
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(patternColor, BlendMode.srcIn),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [topGlow, Colors.transparent, bottomGlow],
                    stops: const [0, 0.45, 1],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessageReminder {
  final String id;
  final String messageId;
  final String creatorUserId;
  final String scope;
  final String status;
  final DateTime? remindAt;

  const _ChatMessageReminder({
    required this.id,
    required this.messageId,
    required this.creatorUserId,
    required this.scope,
    required this.status,
    required this.remindAt,
  });

  factory _ChatMessageReminder.fromJson(Map<String, dynamic> json) {
    return _ChatMessageReminder(
      id: json['id'] as String? ?? '',
      messageId: json['message_id'] as String? ?? '',
      creatorUserId: json['creator_user_id'] as String? ?? '',
      scope: _normalizeReminderScope(json['scope'] as String?),
      status: json['status'] as String? ?? 'pending',
      remindAt: DateTime.tryParse(
        json['remind_at'] as String? ?? '',
      )?.toLocal(),
    );
  }

  bool canManage(String currentUserId) =>
      creatorUserId == currentUserId && status == 'pending';
}

class _ReminderDraft {
  final DateTime remindAt;
  final String scope;

  const _ReminderDraft({required this.remindAt, required this.scope});
}

class _ReminderSheetAction {
  final String type;
  final _ChatMessageReminder? reminder;

  const _ReminderSheetAction._(this.type, this.reminder);

  const _ReminderSheetAction.add() : this._('add', null);
  const _ReminderSheetAction.edit(_ChatMessageReminder reminder)
    : this._('edit', reminder);
  const _ReminderSheetAction.cancel(_ChatMessageReminder reminder)
    : this._('cancel', reminder);
}

String _normalizeReminderScope(String? scope) {
  return scope == 'everyone' ? 'everyone' : 'everyone';
}

@visibleForTesting
bool isChatNearBottom(
  Iterable<ItemPosition> positions, {
  double threshold = _scrollToBottomFabThreshold,
}) {
  for (final position in positions) {
    if (position.index == 0) {
      return position.itemTrailingEdge <= 1 + threshold;
    }
  }
  return false;
}

@visibleForTesting
bool shouldShowScrollToBottomFab(
  Iterable<ItemPosition> positions, {
  double threshold = _scrollToBottomFabThreshold,
}) =>
    positions.isNotEmpty && !isChatNearBottom(positions, threshold: threshold);

@visibleForTesting
bool shouldDismissComposerOnMessageListDrag({required bool hasDragDetails}) {
  return hasDragDetails;
}

@visibleForTesting
bool shouldDismissComposerOnScreenTap({
  required Offset globalPosition,
  required Rect? composerBounds,
}) {
  if (composerBounds == null) return true;
  return !composerBounds.contains(globalPosition);
}

@visibleForTesting
class ChatSearchNavigationState {
  final List<String> matchIds;
  final int currentIndex;

  const ChatSearchNavigationState({
    required this.matchIds,
    required this.currentIndex,
  });

  String? get currentMessageId {
    if (currentIndex < 0 || currentIndex >= matchIds.length) return null;
    return matchIds[currentIndex];
  }
}

@visibleForTesting
List<String> findLoadedConversationSearchMatchIds({
  required String query,
  required Iterable<LocalMessage> loadedMessages,
}) {
  final normalizedQuery = _normalizeChatSearchText(query);
  if (normalizedQuery.isEmpty) return const [];

  final matchIds = <String>[];
  final seenIds = <String>{};

  for (final message in loadedMessages) {
    if (!seenIds.add(message.id)) continue;
    if (message.deletedAt != null) continue;
    if (message.type != 'text') continue;
    final content = _normalizeChatSearchText(message.content ?? '');
    if (content.contains(normalizedQuery)) {
      matchIds.add(message.id);
    }
  }

  return matchIds;
}

String _normalizeChatSearchText(String input) {
  return input.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
}

@visibleForTesting
ChatSearchNavigationState buildChatSearchNavigationState({
  required Iterable<String> rawMatchIds,
  required Iterable<LocalMessage> loadedMessages,
  String? selectedMessageId,
  bool resetToFirst = false,
}) {
  final loadedMessageIds = loadedMessages.map((message) => message.id).toSet();
  final seenIds = <String>{};
  final matchIds = <String>[];

  for (final messageId in rawMatchIds) {
    if (!loadedMessageIds.contains(messageId) || !seenIds.add(messageId)) {
      continue;
    }
    matchIds.add(messageId);
  }

  if (matchIds.isEmpty) {
    return const ChatSearchNavigationState(matchIds: [], currentIndex: -1);
  }

  if (resetToFirst || selectedMessageId == null) {
    return ChatSearchNavigationState(matchIds: matchIds, currentIndex: 0);
  }

  final currentIndex = matchIds.indexOf(selectedMessageId);
  return ChatSearchNavigationState(
    matchIds: matchIds,
    currentIndex: currentIndex >= 0 ? currentIndex : 0,
  );
}

@visibleForTesting
int cycleChatSearchIndex({
  required int currentIndex,
  required int matchCount,
  required bool forward,
}) {
  if (matchCount <= 0) return -1;
  final normalizedIndex = currentIndex >= 0 && currentIndex < matchCount
      ? currentIndex
      : 0;
  if (forward) {
    return (normalizedIndex + 1) % matchCount;
  }
  return (normalizedIndex - 1 + matchCount) % matchCount;
}

@visibleForTesting
int findMessageIndexById(String messageId, Iterable<LocalMessage> messages) {
  var index = 0;
  for (final message in messages) {
    if (message.id == messageId) return index;
    index += 1;
  }
  return -1;
}

@visibleForTesting
bool areMessagesOnSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

@visibleForTesting
int renderedTimelineIndexForMessage(
  String messageId,
  List<LocalMessage> messages,
) {
  var renderedIndex = 0;
  for (var i = 0; i < messages.length; i++) {
    final message = messages[i];
    if (message.id == messageId) return renderedIndex;
    renderedIndex += 1;

    final next = i + 1 < messages.length ? messages[i + 1] : null;
    final shouldInsertDateSeparator = switch ((message.type, next?.type)) {
      ('system', null) => true,
      ('system', _) when next != null => !areMessagesOnSameDay(
        message.createdAt,
        next.createdAt,
      ),
      (_, 'system') => false,
      (_, _) when next != null => !areMessagesOnSameDay(
        message.createdAt,
        next.createdAt,
      ),
      _ => false,
    };

    if (shouldInsertDateSeparator) {
      renderedIndex += 1;
    }
  }

  return -1;
}

@visibleForTesting
int renderedTimelineItemCount(List<LocalMessage> messages) {
  if (messages.isEmpty) return 0;

  var count = 0;
  for (var i = 0; i < messages.length; i++) {
    count += 1;
    final message = messages[i];
    final next = i + 1 < messages.length ? messages[i + 1] : null;
    final shouldInsertDateSeparator = switch ((message.type, next?.type)) {
      ('system', null) => true,
      ('system', _) when next != null => !areMessagesOnSameDay(
        message.createdAt,
        next.createdAt,
      ),
      (_, 'system') => false,
      (_, _) when next != null => !areMessagesOnSameDay(
        message.createdAt,
        next.createdAt,
      ),
      _ => false,
    };

    if (shouldInsertDateSeparator) {
      count += 1;
    }
  }

  return count;
}

@visibleForTesting
bool shouldTriggerOlderHistoryLoad({
  required int maxVisibleIndex,
  required int renderedItemCount,
  required bool isLoadingMore,
  required bool isResolvingHistoricalJump,
  required bool hasMoreHistory,
}) {
  if (renderedItemCount <= 0 ||
      isLoadingMore ||
      isResolvingHistoricalJump ||
      !hasMoreHistory) {
    return false;
  }
  return maxVisibleIndex >= renderedItemCount - 5;
}

enum HistoricalJumpResolution { found, loadMore, exhausted }

@visibleForTesting
HistoricalJumpResolution evaluateHistoricalJumpResolution({
  required String messageId,
  required Iterable<LocalMessage> messages,
  required int previousMessageCount,
  required bool hasMoreHistory,
}) {
  if (findMessageIndexById(messageId, messages) >= 0) {
    return HistoricalJumpResolution.found;
  }
  if (messages.length > previousMessageCount || hasMoreHistory) {
    return HistoricalJumpResolution.loadMore;
  }
  return HistoricalJumpResolution.exhausted;
}

@visibleForTesting
bool shouldRetriggerInitialMessageJump({
  required String oldConversationId,
  required String newConversationId,
  required String? oldInitialMessageId,
  required String? newInitialMessageId,
}) {
  final trimmedMessageId = newInitialMessageId?.trim();
  if (oldConversationId != newConversationId) return false;
  if (trimmedMessageId == null || trimmedMessageId.isEmpty) return false;
  return oldInitialMessageId != trimmedMessageId;
}

@visibleForTesting
bool isRenderedIndexVisible({
  required int targetIndex,
  required Iterable<ItemPosition> positions,
}) {
  for (final position in positions) {
    if (position.index != targetIndex) continue;
    if (position.itemTrailingEdge > 0 && position.itemLeadingEdge < 1) {
      return true;
    }
  }
  return false;
}

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String? initialMessageId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    this.initialMessageId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _itemScrollController = ItemScrollController();
  final _itemPositionsListener = ItemPositionsListener.create();
  final _composerRegionKey = GlobalKey();
  final _showNewMessageFabNotifier = ValueNotifier<bool>(false);
  bool _isLoadingMore = false;
  bool _isResolvingHistoricalJump = false;
  bool _didJumpToInitial = false;
  bool _didInitialBottomSnap = false;

  // Highlight
  final _highlightedMessageIdNotifier = ValueNotifier<String?>(null);
  String? _historicalJumpTargetId;
  Map<String, List<MessageSeenByUser>> _seenPlacementCache = const {};
  Timer? _highlightTimer;

  // In-conversation search
  bool _isSearchMode = false;
  final _searchQueryController = TextEditingController();
  Timer? _searchDebounce;
  List<String> _searchRawMatchIds = [];
  List<String> _searchMatchIds = [];
  int _searchCurrentIndex = -1;

  // Typing indicator
  final _typingUsersNotifier = ValueNotifier<Map<String, int>>({});
  final _devInspectorEnabledNotifier = ValueNotifier<bool>(false);
  final _wsDebugEntriesNotifier = ValueNotifier<List<WsDebugLogEntry>>(
    const [],
  );
  Timer? _typingCleanupTimer;
  Timer? _devTapResetTimer;
  WebSocketManager? _wsManager;
  StreamSubscription<WsDebugLogEntry>? _wsDebugLogSubscription;
  ProviderSubscription<AsyncValue<WsConnectionState>>?
  _wsConnectionSubscription;
  int _devTapCount = 0;

  // Reply state
  LocalMessage? _replyingTo;
  LocalMessage? _editingMessage;

  // Selection mode for forwarding
  bool _isSelectionMode = false;
  final Set<String> _selectedMessageIds = {};

  // Web info panel state
  bool _showInfoPanel = false;

  void _openInfoPanel({required bool isGroup}) {
    final isWide = MediaQuery.of(context).size.width >= 768;
    if (isWide) {
      setState(() => _showInfoPanel = !_showInfoPanel);
    } else {
      if (isGroup) {
        context.push('/group/${widget.conversationId}/info');
      } else {
        context.push('/chat/${widget.conversationId}/info');
      }
    }
  }

  bool get _isNearBottom {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return true;
    return isChatNearBottom(positions);
  }

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      BrowserContextMenu.disableContextMenu();
    }
    _itemPositionsListener.itemPositions.addListener(_onPositionsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recoverRoomRealtimeOnEntry();
    });
    // Subscribe to typing events
    _wsManager = ref.read(webSocketManagerProvider);
    _wsManager?.on('typing', _handleTyping);
    _wsDebugLogSubscription = _wsManager?.debugLogStream.listen(_appendWsLog);
    _typingCleanupTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _cleanupTypingUsers(),
    );
    _wsConnectionSubscription = ref.listenManual<AsyncValue<WsConnectionState>>(
      webSocketConnectionProvider,
      _handleWsConnectionState,
    );
  }

  @override
  void dispose() {
    if (kIsWeb) {
      BrowserContextMenu.enableContextMenu();
    }
    _highlightTimer?.cancel();
    _searchDebounce?.cancel();
    _searchQueryController.dispose();
    _typingCleanupTimer?.cancel();
    _devTapResetTimer?.cancel();
    _wsDebugLogSubscription?.cancel();
    _wsConnectionSubscription?.close();
    _wsManager?.off('typing', _handleTyping);
    _wsManager = null;
    _showNewMessageFabNotifier.dispose();
    _highlightedMessageIdNotifier.dispose();
    _typingUsersNotifier.dispose();
    _devInspectorEnabledNotifier.dispose();
    _wsDebugEntriesNotifier.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _replyingTo = null;
      _editingMessage = null;
      _isSelectionMode = false;
      _selectedMessageIds.clear();
      _typingUsersNotifier.value = {};
      _didInitialBottomSnap = false;
      _didJumpToInitial = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _recoverRoomRealtimeOnEntry();
      });
      return;
    }

    final initialMessageId = widget.initialMessageId?.trim();
    if (shouldRetriggerInitialMessageJump(
      oldConversationId: oldWidget.conversationId,
      newConversationId: widget.conversationId,
      oldInitialMessageId: oldWidget.initialMessageId,
      newInitialMessageId: initialMessageId,
    )) {
      _didJumpToInitial = false;
      final messages =
          ref.read(chatMessagesProvider(widget.conversationId)).valueOrNull ??
          const <LocalMessage>[];
      if (messages.isNotEmpty) {
        _scheduleInitialMessageJump(initialMessageId!);
      }
    }
  }

  void _onPositionsChanged() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    final maxIndex = positions
        .map((p) => p.index)
        .reduce((a, b) => a > b ? a : b);
    final messages = ref
        .read(chatMessagesProvider(widget.conversationId))
        .valueOrNull;
    final hasMoreHistory = ref
        .read(chatHistoryPaginationProvider(widget.conversationId))
        .hasMore;
    final renderedItemCount = messages == null
        ? 0
        : renderedTimelineItemCount(messages);
    if (messages != null &&
        shouldTriggerOlderHistoryLoad(
          maxVisibleIndex: maxIndex,
          renderedItemCount: renderedItemCount,
          isLoadingMore: _isLoadingMore,
          isResolvingHistoricalJump: _isResolvingHistoricalJump,
          hasMoreHistory: hasMoreHistory,
        )) {
      _loadMore();
    }
    final shouldShowFab = shouldShowScrollToBottomFab(positions);
    if (shouldShowFab != _showNewMessageFabNotifier.value) {
      _showNewMessageFabNotifier.value = shouldShowFab;
    }
  }

  void _recoverRoomRealtimeOnEntry() {
    final manager = _wsManager;
    if (manager != null) {
      final notifier = ref.read(
        recentConnectionRecoveryStartedAtProvider.notifier,
      );
      notifier.state = nextConnectionRecoveryStartedAt(
        connectionState: manager.state,
        now: DateTime.now(),
        currentRecoveryStartedAt: notifier.state,
      );
    }
    _appendLocalWsLog('Room entry requested realtime recovery');
    ref
        .read(chatMessagesProvider(widget.conversationId).notifier)
        .recoverRealtimeOnRoomEntry();
  }

  void _handleWsConnectionState(
    AsyncValue<WsConnectionState>? previous,
    AsyncValue<WsConnectionState> next,
  ) {
    final nextState = next.valueOrNull;
    if (nextState == null) return;
    final activeConversationId = ref.read(activeChatConversationIdProvider);
    if (!shouldSynchronizeVisibleChatRoomOnReconnect(
      conversationId: widget.conversationId,
      activeConversationId: activeConversationId,
      previousState: previous?.valueOrNull,
      nextState: nextState,
    )) {
      return;
    }
    _appendLocalWsLog('Room resync after websocket reconnect');
    unawaited(
      ref
          .read(chatMessagesProvider(widget.conversationId).notifier)
          .synchronizeAfterRealtimeReconnect(),
    );
  }

  void _appendLocalWsLog(String message) {
    final manager = _wsManager;
    _appendWsLog(
      WsDebugLogEntry(
        timestamp: DateTime.now(),
        message: message,
        state: manager?.state ?? WsConnectionState.disconnected,
      ),
    );
  }

  void _appendWsLog(WsDebugLogEntry entry) {
    final current = _wsDebugEntriesNotifier.value;
    final next = List<WsDebugLogEntry>.from(current)
      ..add(entry)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (next.length > 14) {
      next.removeRange(14, next.length);
    }
    _wsDebugEntriesNotifier.value = List.unmodifiable(next);
  }

  void _handleAppBarDevTap({required bool isGroup}) {
    _devTapCount++;
    _devTapResetTimer?.cancel();

    if (_devTapCount >= 5) {
      _devTapCount = 0;
      final enabled = !_devInspectorEnabledNotifier.value;
      _devInspectorEnabledNotifier.value = enabled;
      _appendLocalWsLog(
        enabled ? 'Dev inspector enabled' : 'Dev inspector disabled',
      );
      if (mounted) {
        showTopSnackBar(
          context,
          message: enabled
              ? 'Da bat che do dev chat room'
              : 'Da tat che do dev chat room',
        );
      }
      return;
    }

    _devTapResetTimer = Timer(const Duration(milliseconds: 360), () {
      final tapCount = _devTapCount;
      _devTapCount = 0;
      if (tapCount == 1 && isGroup && mounted) {
        _dismissComposerFocus();
        _openInfoPanel(isGroup: true);
      }
    });
  }

  String _formatWsDebugTimestamp(DateTime timestamp) {
    final local = timestamp.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final ss = local.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  Widget _buildDevInspectorBanner(AppThemePalette palette) {
    return ValueListenableBuilder<bool>(
      valueListenable: _devInspectorEnabledNotifier,
      builder: (context, enabled, _) {
        if (!enabled) return const SizedBox.shrink();
        return ValueListenableBuilder<List<WsDebugLogEntry>>(
          valueListenable: _wsDebugEntriesNotifier,
          builder: (context, entries, child) {
            final state = _wsManager?.state ?? WsConnectionState.disconnected;
            final stateColor = switch (state) {
              WsConnectionState.connected => const Color(0xFF34D399),
              WsConnectionState.connecting => const Color(0xFFFBBF24),
              WsConnectionState.disconnected => const Color(0xFFFB7185),
            };
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.isLight
                    ? Colors.white.withValues(alpha: 0.96)
                    : const Color(0xFF101A17).withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: stateColor.withValues(alpha: 0.55)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: palette.isLight ? 0.06 : 0.18,
                    ),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: stateColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Dev WS: ${state.name}',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'tap x5 de tat',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (entries.isEmpty)
                    Text(
                      'Chua co log websocket.',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                      ),
                    )
                  else
                    ...entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '[${_formatWsDebugTimestamp(entry.timestamp)}] ${entry.message}',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleTyping(Map<String, dynamic> data) {
    final userId = data['user_id'] as String?;
    final convId = data['conv_id'] as String?;
    final timestamp = data['timestamp'] as int?;
    if (userId == null || convId == null || timestamp == null) return;
    if (convId != widget.conversationId) return;
    final currentUserId = ref.read(authNotifierProvider).valueOrNull?.user?.id;
    if (userId == currentUserId) return;

    final updated = Map<String, int>.from(_typingUsersNotifier.value);
    updated[userId] = timestamp;
    _typingUsersNotifier.value = updated;
  }

  void _cleanupTypingUsers() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final current = _typingUsersNotifier.value;
    final toRemove = <String>[];
    current.forEach((userId, timestamp) {
      if (now - timestamp > 5000) toRemove.add(userId);
    });
    if (toRemove.isNotEmpty) {
      final updated = Map<String, int>.from(current);
      for (final id in toRemove) {
        updated.remove(id);
      }
      _typingUsersNotifier.value = updated;
    }
  }

  void _highlightMessage(String messageId) {
    _highlightTimer?.cancel();
    _highlightedMessageIdNotifier.value = messageId;
    _highlightTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) _highlightedMessageIdNotifier.value = null;
    });
  }

  Future<bool> _scrollToLoadedMessage(
    String messageId,
    List<LocalMessage> messages,
  ) async {
    final idx = renderedTimelineIndexForMessage(messageId, messages);
    if (idx < 0) return false;
    if (!_itemScrollController.isAttached) return false;
    await _itemScrollController.scrollTo(
      index: idx,
      alignment: 0.35,
      duration: prefersDesktopUi(context) ? AppMotion.fast : AppMotion.medium,
      curve: AppMotion.enterCurve,
    );
    if (mounted &&
        !isRenderedIndexVisible(
          targetIndex: idx,
          positions: _itemPositionsListener.itemPositions.value,
        )) {
      await _itemScrollController.scrollTo(
        index: idx,
        alignment: 0.1,
        duration: AppMotion.fast,
        curve: AppMotion.enterCurve,
      );
    }
    _highlightMessage(messageId);
    return true;
  }

  Future<void> _waitForLoadingMoreToFinish() async {
    while (mounted && _isLoadingMore) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
  }

  void _scheduleInitialMessageJump(String messageId) {
    _didJumpToInitial = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToMessage(messageId);
    });
  }

  Future<void> _scrollToMessage(String messageId) async {
    await _waitForLoadingMoreToFinish();
    if (!mounted) return;

    var messages =
        ref.read(chatMessagesProvider(widget.conversationId)).valueOrNull ?? [];
    if (await _scrollToLoadedMessage(messageId, messages)) {
      return;
    }

    if (_isResolvingHistoricalJump) {
      return;
    }

    setState(() {
      _isResolvingHistoricalJump = true;
      _historicalJumpTargetId = messageId;
    });

    try {
      while (mounted) {
        final previousMessageCount = messages.length;
        await _loadMore();
        if (!mounted) return;

        messages =
            ref.read(chatMessagesProvider(widget.conversationId)).valueOrNull ??
            [];
        final hasMoreHistory = ref
            .read(chatHistoryPaginationProvider(widget.conversationId))
            .hasMore;
        final resolution = evaluateHistoricalJumpResolution(
          messageId: messageId,
          messages: messages,
          previousMessageCount: previousMessageCount,
          hasMoreHistory: hasMoreHistory,
        );

        if (resolution == HistoricalJumpResolution.found) {
          await _scrollToLoadedMessage(messageId, messages);
          return;
        }

        if (resolution == HistoricalJumpResolution.exhausted) {
          showTopSnackBar(
            context,
            message: 'Không tìm thấy tin nhắn trong lịch sử cuộc trò chuyện',
          );
          return;
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingHistoricalJump = false;
          _historicalJumpTargetId = null;
        });
      }
    }
  }

  void _setReplyingTo(LocalMessage message) {
    setState(() {
      _editingMessage = null;
      _replyingTo = message;
    });
  }

  void _setEditingMessage(LocalMessage message) {
    setState(() {
      _replyingTo = null;
      _editingMessage = message;
    });
  }

  void _showMessageActions(LocalMessage message) {
    final convDetail = ref.read(
      conversationDetailProvider(widget.conversationId),
    );
    final conv = convDetail.valueOrNull;
    final convType = conv?.type ?? 'DIRECT';
    final authState = ref.read(authNotifierProvider);
    final currentUserId = authState.valueOrNull?.user?.id ?? '';
    final members =
        ref
            .read(conversationMembersProvider(widget.conversationId))
            .valueOrNull ??
        {};
    final myRole = members[currentUserId]?['role'];
    final isPinned = ref
        .read(pinnedMessagesProvider(widget.conversationId).notifier)
        .isPinned(message.id);
    final isBookmarked = ref
        .read(bookmarkedMessagesProvider(widget.conversationId).notifier)
        .isBookmarked(message.id);

    showMessageContextMenu(
      context: context,
      message: message,
      isMine: message.senderId == currentUserId,
      conversationId: widget.conversationId,
      conversationType: convType,
      userRole: myRole,
      isPinned: isPinned,
      isBookmarked: isBookmarked,
      onReaction: (emoji) {
        ref
            .read(chatMessagesProvider(widget.conversationId).notifier)
            .toggleReaction(message.id, emoji);
      },
      onPin: () async {
        try {
          await ref
              .read(pinnedMessagesProvider(widget.conversationId).notifier)
              .pinMessage(message.id);
        } catch (e) {
          if (mounted) {
            showTopSnackBar(context, message: 'Không thể ghim: $e');
          }
        }
      },
      onUnpin: () async {
        try {
          await ref
              .read(pinnedMessagesProvider(widget.conversationId).notifier)
              .unpinMessage(message.id);
        } catch (e) {
          if (mounted) {
            showTopSnackBar(context, message: 'Không thể bỏ ghim: $e');
          }
        }
      },
      onBookmark: () async {
        try {
          await ref
              .read(bookmarkedMessagesProvider(widget.conversationId).notifier)
              .bookmarkMessage(message.id);
        } catch (e) {
          if (mounted) {
            showTopSnackBar(context, message: 'Không thể đánh dấu: $e');
          }
        }
      },
      onUnbookmark: () async {
        try {
          await ref
              .read(bookmarkedMessagesProvider(widget.conversationId).notifier)
              .unbookmarkMessage(message.id);
        } catch (e) {
          if (mounted) {
            showTopSnackBar(context, message: 'Không thể bỏ đánh dấu: $e');
          }
        }
      },
      onReply: () => _setReplyingTo(message),
      onEdit: () => _setEditingMessage(message),
      onCopy: () {
        final copyableText = copyableMessageText(message);
        if (copyableText == null) {
          showTopSnackBar(context, message: 'Không có nội dung để sao chép');
          return;
        }
        Clipboard.setData(ClipboardData(text: copyableText));
        showTopSnackBar(context, message: 'Đã sao chép');
      },
      onForward: () => _enterSelectionMode(message.id),
      onSeenBy: () => showMessageSeenBySheet(
        context: context,
        conversationId: widget.conversationId,
        messageId: message.id,
      ),
      onReminder: () => _showReminderManager(message, currentUserId),
      onCreatePoc: () => context.push(
        '/pocs/new?conversationId=${Uri.encodeComponent(widget.conversationId)}&messageId=${Uri.encodeComponent(message.id)}',
      ),
      onRecall: () async {
        try {
          await ref
              .read(chatMessagesProvider(widget.conversationId).notifier)
              .recallMessage(message.id);
          if (mounted && _editingMessage?.id == message.id) {
            setState(() => _editingMessage = null);
          }
        } catch (e) {
          if (mounted) {
            showTopSnackBar(context, message: 'Không thể thu hồi: $e');
          }
        }
      },
    );
  }

  Future<void> _showReminderManager(
    LocalMessage message,
    String currentUserId,
  ) async {
    final repo = ref.read(chatRepositoryProvider);

    try {
      final reminderMaps = await repo.getMessageReminders(
        widget.conversationId,
        message.id,
      );
      final reminders = reminderMaps.map(_ChatMessageReminder.fromJson).toList()
        ..sort((a, b) {
          final aTime = a.remindAt?.millisecondsSinceEpoch ?? 0;
          final bTime = b.remindAt?.millisecondsSinceEpoch ?? 0;
          return aTime.compareTo(bTime);
        });

      if (!mounted) return;

      final action = await showModalBottomSheet<_ReminderSheetAction>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: AppColors.surface,
        builder: (sheetContext) {
          final mediaQuery = MediaQuery.of(sheetContext);
          final maxHeight = mediaQuery.size.height * 0.8;

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nhắc hẹn',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message.content?.trim().isNotEmpty == true
                          ? message.content!.trim()
                          : 'Tin nhắn này chưa có nội dung văn bản hiển thị.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: reminders.isEmpty
                          ? const Align(
                              alignment: Alignment.topLeft,
                              child: Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'Chưa có nhắc hẹn nào cho tin nhắn này.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: reminders.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final reminder = reminders[index];
                                return Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 4,
                                    ),
                                    title: Text(
                                      _formatReminderDateTime(
                                        reminder.remindAt,
                                      ),
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${_formatReminderScopeLabel(reminder.scope)} • ${_formatReminderStatusLabel(reminder.status)}',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    trailing: reminder.canManage(currentUserId)
                                        ? PopupMenuButton<String>(
                                            icon: const Icon(
                                              Icons.more_vert,
                                              color: AppColors.textSecondary,
                                            ),
                                            onSelected: (value) {
                                              Navigator.pop(
                                                sheetContext,
                                                value == 'edit'
                                                    ? _ReminderSheetAction.edit(
                                                        reminder,
                                                      )
                                                    : _ReminderSheetAction.cancel(
                                                        reminder,
                                                      ),
                                              );
                                            },
                                            itemBuilder: (context) => const [
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: Text('Sửa'),
                                              ),
                                              PopupMenuItem(
                                                value: 'cancel',
                                                child: Text('Hủy'),
                                              ),
                                            ],
                                          )
                                        : null,
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(
                          sheetContext,
                          const _ReminderSheetAction.add(),
                        ),
                        icon: const Icon(Icons.add_alert_outlined),
                        label: const Text('Tạo nhắc hẹn'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      if (!mounted || action == null) return;

      switch (action.type) {
        case 'add':
          final draft = await _showReminderEditor();
          if (draft == null) return;
          await repo.createMessageReminder(
            widget.conversationId,
            messageId: message.id,
            scope: draft.scope,
            remindAt: draft.remindAt,
          );
          if (!mounted) return;
          ref.invalidate(conversationRemindersProvider(widget.conversationId));
          showTopSnackBar(context, message: 'Đã tạo nhắc hẹn');
          await _showReminderManager(message, currentUserId);
          return;
        case 'edit':
          final reminder = action.reminder;
          if (reminder == null) return;
          final draft = await _showReminderEditor(existing: reminder);
          if (draft == null) return;
          await repo.updateMessageReminder(
            widget.conversationId,
            reminder.id,
            scope: draft.scope,
            remindAt: draft.remindAt,
          );
          if (!mounted) return;
          ref.invalidate(conversationRemindersProvider(widget.conversationId));
          showTopSnackBar(context, message: 'Đã cập nhật nhắc hẹn');
          await _showReminderManager(message, currentUserId);
          return;
        case 'cancel':
          final reminder = action.reminder;
          if (reminder == null) return;
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Hủy nhắc hẹn'),
              content: const Text('Bạn có chắc muốn hủy nhắc hẹn này không?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Đóng'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Hủy nhắc'),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
          await repo.cancelMessageReminder(widget.conversationId, reminder.id);
          if (!mounted) return;
          ref.invalidate(conversationRemindersProvider(widget.conversationId));
          showTopSnackBar(context, message: 'Đã hủy nhắc hẹn');
          await _showReminderManager(message, currentUserId);
          return;
      }
    } catch (e) {
      if (!mounted) return;
      showTopSnackBar(context, message: 'Không thể xử lý nhắc hẹn: $e');
    }
  }

  Future<_ReminderDraft?> _showReminderEditor({
    _ChatMessageReminder? existing,
  }) async {
    var selectedScope = _normalizeReminderScope(existing?.scope);
    var selectedDateTime =
        existing?.remindAt ?? DateTime.now().add(const Duration(hours: 1));

    return showDialog<_ReminderDraft>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final colorScheme = Theme.of(context).colorScheme;

            Future<void> pickDateTime() async {
              final current = selectedDateTime;
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: current,
                firstDate: DateUtils.dateOnly(DateTime.now()),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (pickedDate == null) return;
              if (!context.mounted) return;

              final pickedTime = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(current),
              );
              if (pickedTime == null) return;

              setDialogState(() {
                selectedDateTime = DateTime(
                  pickedDate.year,
                  pickedDate.month,
                  pickedDate.day,
                  pickedTime.hour,
                  pickedTime.minute,
                );
              });
            }

            return AlertDialog(
              title: Text(existing == null ? 'Tạo nhắc hẹn' : 'Sửa nhắc hẹn'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedScope,
                    dropdownColor: colorScheme.surface,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Thông báo cho',
                      labelStyle: TextStyle(color: colorScheme.onSurface),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: const [
                      // DropdownMenuItem(
                      //   value: 'self',
                      //   child: Text('Chỉ mình tôi'),
                      // ),
                      DropdownMenuItem(
                        value: 'everyone',
                        child: Text('everyone'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedScope = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: pickDateTime,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        border: Border.all(color: colorScheme.outline),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule_outlined,
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _formatReminderDateTime(selectedDateTime),
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Đóng'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!selectedDateTime.isAfter(DateTime.now())) {
                      showTopSnackBar(
                        context,
                        message: 'Vui lòng chọn thời gian trong tương lai',
                      );
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      _ReminderDraft(
                        remindAt: selectedDateTime,
                        scope: selectedScope,
                      ),
                    );
                  },
                  child: Text(existing == null ? 'Tạo' : 'Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatReminderDateTime(DateTime? value) {
    if (value == null) return 'Chưa có thời gian';
    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatShortDate(value)} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value), alwaysUse24HourFormat: true)}';
  }

  String _formatReminderScopeLabel(String scope) =>
      _normalizeReminderScope(scope);

  String _formatReminderStatusLabel(String status) {
    switch (status) {
      case 'fired':
        return 'Đã nhắc';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return 'Đang chờ';
    }
  }

  void _enterSelectionMode(String messageId) {
    setState(() {
      _isSelectionMode = true;
      _selectedMessageIds.clear();
      _selectedMessageIds.add(messageId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  void _toggleMessageSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
        if (_selectedMessageIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedMessageIds.add(messageId);
      }
    });
  }

  Future<bool> _loadMore() async {
    final initialPagination = ref.read(
      chatHistoryPaginationProvider(widget.conversationId),
    );
    if (!initialPagination.hasMore) return false;
    if (_isLoadingMore) {
      await _waitForLoadingMoreToFinish();
      final pagination = ref.read(
        chatHistoryPaginationProvider(widget.conversationId),
      );
      return pagination.hasMore ||
          (ref
                  .read(chatMessagesProvider(widget.conversationId))
                  .valueOrNull
                  ?.isNotEmpty ??
              false);
    }
    setState(() => _isLoadingMore = true);
    final initialCount =
        ref
            .read(chatMessagesProvider(widget.conversationId))
            .valueOrNull
            ?.length ??
        0;
    var beforeCount = initialCount;
    var afterCount = initialCount;
    var previousCursor = initialPagination.nextCursor;

    do {
      await ref
          .read(chatMessagesProvider(widget.conversationId).notifier)
          .loadMore();
      afterCount =
          ref
              .read(chatMessagesProvider(widget.conversationId))
              .valueOrNull
              ?.length ??
          0;
      final pagination = ref.read(
        chatHistoryPaginationProvider(widget.conversationId),
      );
      final shouldRetryWithoutUserScroll =
          afterCount <= beforeCount &&
          pagination.hasMore &&
          pagination.nextCursor != null &&
          pagination.nextCursor != previousCursor;
      if (!shouldRetryWithoutUserScroll) {
        break;
      }
      beforeCount = afterCount;
      previousCursor = pagination.nextCursor;
    } while (mounted);

    if (mounted) {
      setState(() {
        _isLoadingMore = false;
      });
    }
    final pagination = ref.read(
      chatHistoryPaginationProvider(widget.conversationId),
    );
    return afterCount > initialCount || pagination.hasMore;
  }

  void _syncSearchNavigationState(
    List<LocalMessage> messages, {
    bool resetToFirst = false,
  }) {
    final selectedMessageId =
        _searchCurrentIndex >= 0 && _searchCurrentIndex < _searchMatchIds.length
        ? _searchMatchIds[_searchCurrentIndex]
        : null;
    final navigationState = buildChatSearchNavigationState(
      rawMatchIds: _searchRawMatchIds,
      loadedMessages: messages,
      selectedMessageId: selectedMessageId,
      resetToFirst: resetToFirst,
    );

    if (listEquals(_searchMatchIds, navigationState.matchIds) &&
        _searchCurrentIndex == navigationState.currentIndex) {
      return;
    }

    setState(() {
      _searchMatchIds = navigationState.matchIds;
      _searchCurrentIndex = navigationState.currentIndex;
    });
  }

  // --- In-conversation search ---

  void _onSearchQueryChanged(String query) {
    _searchDebounce?.cancel();
    if (query.length < 2) {
      setState(() {
        _searchRawMatchIds = [];
        _searchMatchIds = [];
        _searchCurrentIndex = -1;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _performInConversationSearch(query);
    });
  }

  Future<void> _performInConversationSearch(String query) async {
    final messages =
        ref.read(chatMessagesProvider(widget.conversationId)).valueOrNull ?? [];
    final rawMatchIds = findLoadedConversationSearchMatchIds(
      query: query,
      loadedMessages: messages,
    ).toList();

    // Server fallback if local results are sparse
    if (rawMatchIds.length < 5) {
      try {
        final repo = ref.read(chatRepositoryProvider);
        final adapter = ref.read(encryptedMessageAdapterProvider);
        final keyRepository = ref.read(conversationKeyRepositoryProvider);
        final activeKey = await keyRepository.resolveActiveKey(
          widget.conversationId,
        );
        final blindIndexTokens = await adapter.buildBlindIndexTokens(
          plaintext: query,
          key: activeKey,
        );
        final data = await repo.searchMessages(
          query: blindIndexTokens.isEmpty ? query : null,
          blindIndexTokens: blindIndexTokens,
          convId: widget.conversationId,
        );
        final serverResults = data['results'] as List? ?? [];
        final localIdSet = rawMatchIds.toSet();
        for (final r in serverResults) {
          final row = r as Map<String, dynamic>;
          final id = row['id'] as String;
          if (localIdSet.add(id)) {
            rawMatchIds.add(id);
          }
        }
      } catch (_) {
        // Server search failed, use local results only
      }
    }

    if (!mounted) return;
    final navigationState = buildChatSearchNavigationState(
      rawMatchIds: rawMatchIds,
      loadedMessages: messages,
      resetToFirst: true,
    );
    setState(() {
      _searchRawMatchIds = rawMatchIds;
      _searchMatchIds = navigationState.matchIds;
      _searchCurrentIndex = navigationState.currentIndex;
    });
    if (navigationState.currentMessageId case final currentMessageId?) {
      _scrollToLoadedMessage(currentMessageId, messages);
    }
  }

  void _searchNext() {
    if (_searchMatchIds.isEmpty) return;
    setState(() {
      _searchCurrentIndex = cycleChatSearchIndex(
        currentIndex: _searchCurrentIndex,
        matchCount: _searchMatchIds.length,
        forward: true,
      );
    });
    _scrollToLoadedMessage(
      _searchMatchIds[_searchCurrentIndex],
      ref.read(chatMessagesProvider(widget.conversationId)).valueOrNull ?? [],
    );
  }

  void _searchPrev() {
    if (_searchMatchIds.isEmpty) return;
    setState(() {
      _searchCurrentIndex = cycleChatSearchIndex(
        currentIndex: _searchCurrentIndex,
        matchCount: _searchMatchIds.length,
        forward: false,
      );
    });
    _scrollToLoadedMessage(
      _searchMatchIds[_searchCurrentIndex],
      ref.read(chatMessagesProvider(widget.conversationId)).valueOrNull ?? [],
    );
  }

  void _exitSearchMode() {
    _searchDebounce?.cancel();
    _highlightTimer?.cancel();
    setState(() {
      _isSearchMode = false;
      _searchQueryController.clear();
      _searchRawMatchIds = [];
      _searchMatchIds = [];
      _searchCurrentIndex = -1;
      _highlightedMessageIdNotifier.value = null;
    });
  }

  Future<void> _onAttachImages(List<XFile> images) async {
    // Capture reply state before async gap
    final replyTo = _replyingTo;
    final result = await Navigator.of(context).push<ImagePreviewResult>(
      MaterialPageRoute(builder: (_) => ImagePreviewScreen(images: images)),
    );
    if (result == null || result.images.isEmpty) return;
    ref
        .read(chatMessagesProvider(widget.conversationId).notifier)
        .sendImageMessage(
          result.images,
          result.caption,
          replyToId: replyTo?.id,
          replyToMessage: replyTo,
        );
  }

  void _openImageViewer(List<String> urls, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImageViewerScreen(imageUrls: urls, initialIndex: index),
      ),
    );
  }

  Future<void> _onAttachVideo(XFile video) async {
    final result = await Navigator.of(context).push<VideoPreviewResult>(
      MaterialPageRoute(builder: (_) => VideoPreviewScreen(video: video)),
    );
    if (result == null) return;
    ref
        .read(chatMessagesProvider(widget.conversationId).notifier)
        .sendVideoMessage(
          result.video,
          result.caption,
          duration: result.duration,
          width: result.width,
          height: result.height,
          fileSize: result.fileSize,
        );
  }

  Future<void> _onAttachFile(XFile file) async {
    final replyTo = _replyingTo;
    await ref
        .read(chatMessagesProvider(widget.conversationId).notifier)
        .sendFileMessage(file, replyToId: replyTo?.id, replyToMessage: replyTo);
  }

  void _openVideoPlayer(String videoUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VideoPlayerScreen(videoUrl: videoUrl)),
    );
  }

  void _dismissComposerFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Rect? _composerBounds() {
    final context = _composerRegionKey.currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    final topLeft = renderObject.localToGlobal(Offset.zero);
    return topLeft & renderObject.size;
  }

  Future<void> _callDirectMember(String? phoneNumber) async {
    final memberInfo = ref
        .read(directChatMemberInfoProvider(widget.conversationId))
        .valueOrNull;
    if (memberInfo == null) {
      showTopSnackBar(context, message: 'Không tìm thấy thông tin người nhận');
      return;
    }

    final otherUserId = memberInfo.userId;
    final otherUserName = memberInfo.name;
    final otherUserAvatar = memberInfo.avatarUrl;

    if (!mounted) return;

    try {
      await ref
          .read(callNotifierProvider.notifier)
          .startCall(
            receiverId: otherUserId,
            receiverName: otherUserName,
            receiverAvatar: otherUserAvatar,
            conversationId: widget.conversationId,
            isVideo: false, // Luôn gọi thường
          );
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, message: 'Lỗi khởi tạo cuộc gọi: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final messagesAsync = ref.watch(
      chatMessagesProvider(widget.conversationId),
    );
    ref.watch(webSocketConnectionProvider);
    final authState = ref.watch(authNotifierProvider);
    final currentUserId = authState.valueOrNull?.user?.id ?? '';
    final convDetail = ref.watch(
      conversationDetailProvider(widget.conversationId),
    );
    final membersAsync = ref.watch(
      conversationMembersProvider(widget.conversationId),
    );

    final conv = convDetail.valueOrNull;
    final isGroup = conv?.type == 'GROUP';
    final otherName = conv?.otherMemberName;
    final otherAvatar = conv?.otherMemberAvatar;
    final otherLastSeenAt = conv?.otherMemberLastSeenAt;
    final directMemberInfo = isGroup
        ? null
        : ref
              .watch(directChatMemberInfoProvider(widget.conversationId))
              .valueOrNull;

    final displayName = isGroup
        ? (conv?.name ?? 'Nhóm')
        : (otherName ?? 'Chat');
    final displayAvatar = isGroup ? conv?.avatarUrl : otherAvatar;

    final members = membersAsync.valueOrNull ?? {};
    final memberCount = members.length;

    ref.listen(chatMessagesProvider(widget.conversationId), (prev, next) {
      final prevCount = prev?.valueOrNull?.length ?? 0;
      final nextMessages = next.valueOrNull ?? [];
      final nextCount = nextMessages.length;
      if (nextCount > prevCount &&
          _isNearBottom &&
          !_isResolvingHistoricalJump) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_itemScrollController.isAttached) {
            if (!_didInitialBottomSnap &&
                prevCount == 0 &&
                widget.initialMessageId == null) {
              _itemScrollController.jumpTo(index: 0);
              _didInitialBottomSnap = true;
            } else {
              _itemScrollController.scrollTo(
                index: 0,
                duration: AppMotion.fast,
                curve: AppMotion.enterCurve,
              );
            }
          }
        });
      }
      if (_isSearchMode && _searchRawMatchIds.isNotEmpty) {
        _syncSearchNavigationState(nextMessages);
      }
      // Handle initialMessageId jump
      if (!_didJumpToInitial && widget.initialMessageId != null) {
        if (nextMessages.isNotEmpty) {
          _scheduleInitialMessageJump(widget.initialMessageId!);
        }
      }
    });

    final isWide = MediaQuery.of(context).size.width >= 768;

    final scaffold = Scaffold(
      backgroundColor: palette.isLight
          ? const Color(0xFFEFF3F8)
          : palette.background,
      appBar: _isSelectionMode
          ? _buildSelectionAppBar()
          : _isSearchMode
          ? _buildSearchAppBar()
          : _buildNormalAppBar(
              isWide: isWide,
              isGroup: isGroup,
              conv: conv,
              displayName: displayName,
              displayAvatar: displayAvatar,
              otherName: otherName,
              otherLastSeenAt: otherLastSeenAt,
              otherPhoneNumber: directMemberInfo?.phoneNumber,
              memberCount: memberCount,
            ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final paneWidth = constraints.maxWidth;

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (details) {
              if (!shouldDismissComposerOnScreenTap(
                globalPosition: details.globalPosition,
                composerBounds: _composerBounds(),
              )) {
                return;
              }
              _dismissComposerFocus();
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(child: _ChatWallpaper(palette: palette)),
                Column(
                  children: [
                    _buildDevInspectorBanner(palette),
                    if (_isResolvingHistoricalJump)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        color: palette.isLight
                            ? const Color(0xFFDDE4EE)
                            : AppColors.surfaceVariant.withValues(alpha: 0.65),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _historicalJumpTargetId == null
                                    ? 'Đang tải tin nhắn cũ...'
                                    : 'Đang tải thêm lịch sử để mở tin nhắn...',
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ChatConversationFrame(
                      availableWidth: paneWidth,
                      child: PinnedMessageBar(
                        conversationId: widget.conversationId,
                        onTap: () async {
                          _dismissComposerFocus();
                          await showPinnedMessages(
                            context,
                            conversationId: widget.conversationId,
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: ChatConversationFrame(
                        availableWidth: paneWidth,
                        expand: true,
                        child: messagesAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Center(child: Text('Error: $e')),
                          data: (messages) {
                            if (messages.isEmpty) {
                              return const Center(
                                child: Text(
                                  'Bắt đầu cuộc trò chuyện',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              );
                            }
                            return _buildMessageList(
                              messages,
                              currentUserId,
                              isGroup,
                              members,
                              otherName,
                              otherAvatar,
                            );
                          },
                        ),
                      ),
                    ),
                    ValueListenableBuilder<Map<String, int>>(
                      valueListenable: _typingUsersNotifier,
                      builder: (context, typingUsers, child) {
                        final showTyping =
                            typingUsers.isNotEmpty && !_isSelectionMode;
                        return AnimatedSwitcher(
                          duration: AppMotion.fast,
                          switchInCurve: AppMotion.enterCurve,
                          switchOutCurve: AppMotion.exitCurve,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SizeTransition(
                                sizeFactor: animation,
                                axisAlignment: -1,
                                child: child,
                              ),
                            );
                          },
                          child: showTyping
                              ? KeyedSubtree(
                                  key: const ValueKey('typing-indicator'),
                                  child: ChatConversationFrame(
                                    availableWidth: paneWidth,
                                    child: TypingIndicator(
                                      typingUserIds: typingUsers.keys.toList(),
                                      isGroup: conv?.type == 'GROUP',
                                      currentUserId: currentUserId,
                                      members: members,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey('no-typing-indicator'),
                                ),
                        );
                      },
                    ),
                    if (!_isSelectionMode)
                      KeyedSubtree(
                        key: _composerRegionKey,
                        child: ChatConversationFrame(
                          availableWidth: paneWidth,
                          child: MessageInputBar(
                            key: ValueKey(
                              'chat_message_input_bar_${widget.conversationId}',
                            ),
                            conversationId: widget.conversationId,
                            isGroup: isGroup,
                            members: members.isNotEmpty ? members : null,
                            currentUserId: currentUserId,
                            currentUserRole: _getMemberRole(
                              members,
                              currentUserId,
                            ),
                            replyTo: _replyingTo,
                            editingMessage: _editingMessage,
                            replyToSenderName: _resolveReplySenderName(
                              currentUserId,
                              isGroup,
                              members,
                              otherName,
                            ),
                            replyToSenderColor: _resolveReplySenderColor(
                              currentUserId,
                              isGroup,
                            ),
                            onCancelReply: () =>
                                setState(() => _replyingTo = null),
                            onCancelEdit: () =>
                                setState(() => _editingMessage = null),
                            onSend: (text, {linkPreview, mentions}) async {
                              final notifier = ref.read(
                                chatMessagesProvider(
                                  widget.conversationId,
                                ).notifier,
                              );
                              final editingMessage = _editingMessage;
                              try {
                                if (editingMessage != null) {
                                  await notifier.editMessage(
                                    editingMessage.id,
                                    text,
                                  );
                                  if (mounted) {
                                    setState(() => _editingMessage = null);
                                  }
                                } else {
                                  await notifier.sendMessage(
                                    text,
                                    linkPreview: linkPreview,
                                    mentions: mentions,
                                    replyToId: _replyingTo?.id,
                                    replyToMessage: _replyingTo,
                                  );
                                  if (mounted) {
                                    setState(() => _replyingTo = null);
                                  }
                                }
                              } on EditMessageException catch (e) {
                                if (context.mounted) {
                                  showTopSnackBar(context, message: e.message);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  final action = editingMessage != null
                                      ? 'sửa'
                                      : 'gửi';
                                  showTopSnackBar(
                                    context,
                                    message: 'Không thể $action tin nhắn: $e',
                                  );
                                }
                              }
                            },
                            onAttachImages: (images) {
                              _onAttachImages(images);
                              setState(() {
                                _replyingTo = null;
                                _editingMessage = null;
                              });
                            },
                            onAttachFile: (file) async {
                              await _onAttachFile(file);
                              if (!mounted) return;
                              setState(() {
                                _replyingTo = null;
                                _editingMessage = null;
                              });
                            },
                            onAttachVideo: (video) => _onAttachVideo(video),
                            onVoiceRecorded: (path, duration, waveform) {
                              ref
                                  .read(
                                    chatMessagesProvider(
                                      widget.conversationId,
                                    ).notifier,
                                  )
                                  .sendVoiceMessage(path, duration, waveform);
                            },
                            onFetchLinkPreview: (url) {
                              final repo = ref.read(chatRepositoryProvider);
                              return repo.fetchLinkPreview(url);
                            },
                            onTyping: () {
                              ref
                                  .read(webSocketManagerProvider)
                                  .sendTyping(widget.conversationId);
                            },
                          ),
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

    if (!isWide) {
      return scaffold;
    }

    final infoPanelContent = isGroup
        ? GroupInfoScreen(
            key: ValueKey('group-info-${widget.conversationId}'),
            conversationId: widget.conversationId,
            asPanel: true,
            onClose: () => setState(() => _showInfoPanel = false),
          )
        : DirectChatInfoScreen(
            key: ValueKey('direct-info-${widget.conversationId}'),
            conversationId: widget.conversationId,
            asPanel: true,
            onClose: () => setState(() => _showInfoPanel = false),
          );

    return Row(
      children: [
        Expanded(child: scaffold),
        AnimatedSwitcher(
          duration: AppMotion.medium,
          switchInCurve: AppMotion.enterCurve,
          switchOutCurve: AppMotion.exitCurve,
          transitionBuilder: (child, animation) {
            return ClipRect(
              child: FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  axis: Axis.horizontal,
                  axisAlignment: -1,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.06, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: _showInfoPanel
              ? Row(
                  key: const ValueKey('info-panel-open'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VerticalDivider(width: 1, color: palette.surfaceVariant),
                    SizedBox(
                      width: 380,
                      child: ClipRect(child: infoPanelContent),
                    ),
                  ],
                )
              : const SizedBox.shrink(key: ValueKey('info-panel-closed')),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    final palette = context.appPalette;
    return AppBar(
      backgroundColor: palette.surface,
      foregroundColor: palette.textPrimary,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.close, color: palette.textPrimary),
        onPressed: () {
          _dismissComposerFocus();
          _exitSelectionMode();
        },
      ),
      title: Text(
        '${_selectedMessageIds.length} đã chọn',
        style: TextStyle(fontSize: 16, color: palette.textPrimary),
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.forward,
            color: _selectedMessageIds.isEmpty
                ? palette.textHint
                : palette.primary,
          ),
          tooltip: 'Chuyển tiếp',
          onPressed: _selectedMessageIds.isEmpty
              ? null
              : () async {
                  _dismissComposerFocus();
                  bool? result;
                  final isWide = MediaQuery.of(context).size.width >= 768;
                  if (isWide) {
                    result = await showDialog<bool>(
                      context: context,
                      builder: (dialogCtx) => Dialog(
                        backgroundColor: palette.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: SizedBox(
                          width: 480,
                          height: 600,
                          child: ForwardChatPickerScreen(
                            sourceConvId: widget.conversationId,
                            messageIds: _selectedMessageIds.toList(),
                            asDialog: true,
                          ),
                        ),
                      ),
                    );
                  } else {
                    result = await context.push<bool>(
                      '/forward-chat-picker',
                      extra: {
                        'sourceConvId': widget.conversationId,
                        'messageIds': _selectedMessageIds.toList(),
                      },
                    );
                  }
                  if (result == true && mounted) {
                    _exitSelectionMode();
                  }
                },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: palette.surfaceVariant),
      ),
    );
  }

  PreferredSizeWidget _buildSearchAppBar() {
    final palette = context.appPalette;
    final counterText = _searchMatchIds.isEmpty
        ? '0/0'
        : '${_searchCurrentIndex + 1}/${_searchMatchIds.length}';
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          _dismissComposerFocus();
          _exitSearchMode();
        },
      ),
      title: TextField(
        controller: _searchQueryController,
        autofocus: true,
        style: TextStyle(color: palette.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Tìm kiếm...',
          hintStyle: TextStyle(color: palette.textHint),
          border: InputBorder.none,
        ),
        onChanged: _onSearchQueryChanged,
      ),
      titleSpacing: 0,
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Center(
            child: Text(
              counterText,
              style: TextStyle(color: palette.textSecondary, fontSize: 13),
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.keyboard_arrow_up, color: palette.textSecondary),
          onPressed: _searchMatchIds.isEmpty ? null : _searchPrev,
        ),
        IconButton(
          icon: Icon(Icons.keyboard_arrow_down, color: palette.textSecondary),
          onPressed: _searchMatchIds.isEmpty ? null : _searchNext,
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: palette.surfaceVariant),
      ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar({
    required bool isWide,
    required bool isGroup,
    required LocalConversation? conv,
    required String displayName,
    required String? displayAvatar,
    required String? otherName,
    required DateTime? otherLastSeenAt,
    required String? otherPhoneNumber,
    required int memberCount,
  }) {
    final palette = context.appPalette;
    final appBarBackground = palette.isLight
        ? palette.primary
        : palette.surface;
    final appBarForeground = palette.isLight
        ? Colors.white
        : palette.textPrimary;
    final appBarSecondary = palette.isLight
        ? Colors.white.withValues(alpha: 0.82)
        : palette.textSecondary;
    final onlineColor = palette.isLight
        ? const Color(0xFFB7FFD3)
        : AppColors.online;
    final pinsAsync = ref.watch(pinnedMessagesProvider(widget.conversationId));
    final pinCount = pinsAsync.valueOrNull?.length ?? 0;
    final bookmarksAsync = ref.watch(
      bookmarkedMessagesProvider(widget.conversationId),
    );
    final bookmarkCount = bookmarksAsync.valueOrNull?.length ?? 0;

    final remindersAsync = ref.watch(
      conversationRemindersProvider(widget.conversationId),
    );
    final reminderCount = remindersAsync.valueOrNull?.length ?? 0;

    return AppBar(
      backgroundColor: appBarBackground,
      foregroundColor: appBarForeground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: !isWide,
      title: Padding(
        padding: EdgeInsets.only(left: isWide ? 16 : 0),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _handleAppBarDevTap(isGroup: isGroup),
          child: Row(
            children: [
              if (conv != null) ...[
                ChatAvatar(
                  radius: 18,
                  displayName: displayName,
                  imageUrl: displayAvatar,
                  isGroup: isGroup,
                  iconSize: 18,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 16,
                        color: appBarForeground,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!isGroup && otherName != null)
                      Text(
                        _formatLastSeen(otherLastSeenAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: _isOnline(otherLastSeenAt)
                              ? onlineColor
                              : appBarSecondary,
                        ),
                      ),
                    if (isGroup)
                      Text(
                        memberCount > 0
                            ? '$memberCount thành viên'
                            : 'Nhóm chat',
                        style: TextStyle(fontSize: 12, color: appBarSecondary),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      titleSpacing: isWide ? 16 : 0,
      actions: [
        if (bookmarkCount > 0)
          GestureDetector(
            onTap: () async {
              _dismissComposerFocus();
              String? messageId;
              if (isWide) {
                messageId = await showDialog<String>(
                  context: context,
                  builder: (dialogCtx) => Dialog(
                    backgroundColor: palette.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SizedBox(
                      width: 480,
                      height: 600,
                      child: Column(
                        children: [
                          Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: palette.surface,
                              border: Border(
                                bottom: BorderSide(
                                  color: palette.surfaceVariant,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Tin nhắn đã đánh dấu',
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    color: palette.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () => Navigator.pop(dialogCtx),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: BookmarkedMessagesListScreen(
                              conversationId: widget.conversationId,
                              asDialog: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              } else {
                messageId = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => BookmarkedMessagesListScreen(
                      conversationId: widget.conversationId,
                    ),
                  ),
                );
              }
              if (messageId != null && mounted) {
                _scrollToMessage(messageId);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: 16,
                    color: appBarForeground,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '$bookmarkCount',
                    style: TextStyle(
                      color: appBarForeground,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (reminderCount > 0)
          GestureDetector(
            onTap: () async {
              _dismissComposerFocus();
              String? messageId;
              if (isWide) {
                messageId = await showDialog<String>(
                  context: context,
                  builder: (dialogCtx) => Dialog(
                    backgroundColor: palette.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SizedBox(
                      width: 480,
                      height: 600,
                      child: Column(
                        children: [
                          Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: palette.surface,
                              border: Border(
                                bottom: BorderSide(
                                  color: palette.surfaceVariant,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Lời nhắc hẹn',
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    color: palette.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () => Navigator.pop(dialogCtx),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ConversationRemindersScreen(
                              conversationId: widget.conversationId,
                              asDialog: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              } else {
                messageId = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => ConversationRemindersScreen(
                      conversationId: widget.conversationId,
                    ),
                  ),
                );
              }
              if (messageId != null && mounted) {
                _scrollToMessage(messageId);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 16,
                    color: appBarForeground,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '$reminderCount',
                    style: TextStyle(
                      color: appBarForeground,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (pinCount > 0)
          GestureDetector(
            onTap: () async {
              _dismissComposerFocus();
              await showPinnedMessages(
                context,
                conversationId: widget.conversationId,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.push_pin_rounded,
                    size: 16,
                    color: appBarForeground,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '$pinCount',
                    style: TextStyle(
                      color: appBarForeground,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (!isGroup)
          IconButton(
            icon: Icon(Icons.call_outlined, color: appBarForeground),
            tooltip: 'Gọi điện',
            onPressed: () {
              _dismissComposerFocus();
              _callDirectMember(otherPhoneNumber);
            },
          ),
        IconButton(
          icon: Icon(Icons.search, color: appBarForeground),
          tooltip: 'Tìm kiếm',
          onPressed: () {
            _dismissComposerFocus();
            setState(() => _isSearchMode = true);
          },
        ),
        IconButton(
          icon: Icon(Icons.info_outline, color: appBarForeground),
          tooltip: 'Thông tin',
          onPressed: () {
            _dismissComposerFocus();
            _openInfoPanel(isGroup: isGroup);
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          color: palette.isLight
              ? Colors.white.withValues(alpha: 0.28)
              : palette.surfaceVariant,
        ),
      ),
    );
  }

  Widget _buildMessageList(
    List<LocalMessage> messages,
    String currentUserId,
    bool isGroup,
    Map<String, Map<String, String?>> members,
    String? otherName,
    String? otherAvatar,
  ) {
    final bookmarksAsync = ref.watch(
      bookmarkedMessagesProvider(widget.conversationId),
    );
    final bookmarkedIds = {
      for (final bookmark
          in bookmarksAsync.valueOrNull ?? <BookmarkedMessageData>[])
        bookmark.messageId,
    };
    final items = _buildMessageItems(
      messages,
      currentUserId,
      isGroup,
      members,
      otherName,
      otherAvatar,
      bookmarkedIds,
    );
    return Stack(
      children: [
        NotificationListener<ScrollStartNotification>(
          onNotification: (notification) {
            if (shouldDismissComposerOnMessageListDrag(
              hasDragDetails: notification.dragDetails != null,
            )) {
              _dismissComposerFocus();
            }
            return false;
          },
          child: ScrollablePositionedList.builder(
            itemScrollController: _itemScrollController,
            itemPositionsListener: _itemPositionsListener,
            reverse: true,
            physics: appScrollPhysics(context),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: items.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (_isLoadingMore && index == items.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return items[index];
            },
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _showNewMessageFabNotifier,
          builder: (context, show, child) {
            if (!show) return const SizedBox.shrink();
            return Positioned(bottom: 8, right: 16, child: child!);
          },
          child: FloatingActionButton.small(
            backgroundColor: AppColors.gold,
            onPressed: () {
              _itemScrollController.scrollTo(
                index: 0,
                duration: prefersDesktopUi(context)
                    ? AppMotion.fast
                    : AppMotion.medium,
                curve: AppMotion.enterCurve,
              );
              _showNewMessageFabNotifier.value = false;
            },
            child: const Icon(
              Icons.arrow_downward,
              color: AppColors.background,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildMessageItems(
    List<LocalMessage> messages,
    String currentUserId,
    bool isGroup,
    Map<String, Map<String, String?>> members,
    String? otherName,
    String? otherAvatar,
    Set<String> bookmarkedIds,
  ) {
    final seenPlacementRequest = ConversationSeenByPlacementRequest(
      convId: widget.conversationId,
      currentUserId: currentUserId,
      messageIdsNewestFirst: messages
          .where(
            (message) => message.deletedAt == null && message.type != 'system',
          )
          .map((message) => message.id)
          .toList(),
    );
    final seenPlacementAsync = ref.watch(
      conversationSeenByPlacementProvider(seenPlacementRequest),
    );
    final seenPlacement = seenPlacementAsync.valueOrNull ?? _seenPlacementCache;
    final shouldReserveSeenBySpace =
        seenPlacementAsync.isLoading && seenPlacementAsync.valueOrNull == null;
    if (seenPlacementAsync.valueOrNull != null) {
      _seenPlacementCache = seenPlacementAsync.valueOrNull!;
    }

    final recentOutgoingCandidateIds = messages
        .where(
          (message) =>
              message.senderId == currentUserId &&
              message.deletedAt == null &&
              message.type != 'system',
        )
        .take(3)
        .map((message) => message.id)
        .toSet();

    final items = <Widget>[];
    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];

      if (msg.type == 'system') {
        items.add(_buildSystemMessage(msg));
        if (i + 1 < messages.length) {
          final next = messages[i + 1];
          if (!_isSameDay(msg.createdAt, next.createdAt)) {
            items.add(_buildDateSeparator(msg.createdAt));
          }
        } else {
          items.add(_buildDateSeparator(msg.createdAt));
        }
        continue;
      }

      final isMine = msg.senderId == currentUserId;
      final senderInfo = members[msg.senderId];
      final newerMsg = i > 0 ? messages[i - 1] : null;
      final olderMsg = i + 1 < messages.length ? messages[i + 1] : null;
      final isFirstInGroup = !_isSameGroup(olderMsg, msg);
      final isLastInGroup = !_isSameGroup(msg, newerMsg);

      final senderNameStr = isMine
          ? null
          : isGroup
          ? (senderInfo?['name'])
          : otherName;
      final senderAvatarStr = isMine
          ? null
          : isGroup
          ? (senderInfo?['avatar'])
          : otherAvatar;

      Color? senderColor;
      if (isGroup && !isMine) {
        senderColor =
            AppColors.senderColors[msg.senderId.hashCode.abs() %
                AppColors.senderColors.length];
      }

      // Extract reply data from metadata
      String? replyToSenderName;
      String? replyToContent;
      String? replyToType;
      Color? replyToSenderColor;
      VoidCallback? onReplyTap;

      if (msg.replyToId != null) {
        Map<String, dynamic>? meta;
        if (msg.metadata != null) {
          try {
            meta = jsonDecode(msg.metadata!) as Map<String, dynamic>;
          } catch (_) {}
        }
        final replyTo = meta?['reply_to'] as Map<String, dynamic>?;
        if (replyTo != null) {
          replyToSenderName = replyTo['sender_name'] as String?;
          final replyDeletedAt = replyTo['deleted_at'];
          replyToContent = replyDeletedAt != null
              ? 'Tin nhắn đã được thu hồi'
              : replyTo['content'] as String?;
          if (replyDeletedAt == null &&
              (replyToContent == null || replyToContent.trim().isEmpty) &&
              replyTo['encrypted_content'] != null) {
            replyToContent = encryptedMessagePreviewPlaceholder;
          }
          replyToType = replyDeletedAt != null
              ? 'recalled'
              : replyTo['type'] as String?;
          final replySenderId = replyTo['sender_id'] as String?;
          // Resolve sender name from members if not in snapshot
          if (replyToSenderName == null && replySenderId != null) {
            if (replySenderId == currentUserId) {
              replyToSenderName = 'Bạn';
            } else if (isGroup) {
              replyToSenderName = members[replySenderId]?['name'] ?? 'Unknown';
            } else {
              replyToSenderName = otherName ?? 'Unknown';
            }
          }
          // Resolve color
          if (replySenderId == currentUserId) {
            replyToSenderColor = AppColors.gold;
          } else if (isGroup && replySenderId != null) {
            replyToSenderColor =
                AppColors.senderColors[replySenderId.hashCode.abs() %
                    AppColors.senderColors.length];
          }
        } else {
          // Fallback: search current messages list
          final original = messages
              .where((m) => m.id == msg.replyToId)
              .firstOrNull;
          if (original != null) {
            if (original.senderId == currentUserId) {
              replyToSenderName = 'Bạn';
              replyToSenderColor = AppColors.gold;
            } else if (isGroup) {
              replyToSenderName =
                  members[original.senderId]?['name'] ?? 'Unknown';
              replyToSenderColor =
                  AppColors.senderColors[original.senderId.hashCode.abs() %
                      AppColors.senderColors.length];
            } else {
              replyToSenderName = otherName ?? 'Unknown';
            }
            replyToContent = original.deletedAt != null
                ? 'Tin nhắn đã được thu hồi'
                : original.content;
            replyToType = original.deletedAt != null
                ? 'recalled'
                : original.type;
          }
        }
        onReplyTap = () => _scrollToMessage(msg.replyToId!);
      }

      items.add(
        ValueListenableBuilder<String?>(
          valueListenable: _highlightedMessageIdNotifier,
          builder: (context, highlightedId, child) {
            return MessageItem(
              key: ValueKey(msg.id),
              message: msg,
              isMine: isMine,
              conversationId: widget.conversationId,
              senderName: senderNameStr,
              senderAvatar: senderAvatarStr,
              senderNameColor: senderColor,
              isFirstInGroup: isFirstInGroup,
              isLastInGroup: isLastInGroup,
              showAvatar: isGroup && !isMine,
              showSenderName: isGroup && !isMine,
              isHighlighted: highlightedId == msg.id,
              onImageTap: _openImageViewer,
              onVideoTap: _openVideoPlayer,
              replyToSenderName: replyToSenderName,
              replyToContent: replyToContent,
              replyToType: replyToType,
              replyToSenderColor: replyToSenderColor,
              onReplyTap: onReplyTap,
              onSwipeReply: () => _setReplyingTo(msg),
              onLongPressAction: () => _showMessageActions(msg),
              isSelectionMode: _isSelectionMode,
              isSelected: _selectedMessageIds.contains(msg.id),
              onSelectionTap: () => _toggleMessageSelection(msg.id),
              isBookmarked: bookmarkedIds.contains(msg.id),
              seenByUsers:
                  !_isSelectionMode &&
                      msg.deletedAt == null &&
                      msg.type != 'system'
                  ? (seenPlacement[msg.id] ?? const [])
                  : const [],
              reserveSeenBySpace:
                  isGroup &&
                  !_isSelectionMode &&
                  msg.senderId == currentUserId &&
                  recentOutgoingCandidateIds.contains(msg.id) &&
                  shouldReserveSeenBySpace,
              onSeenByTap: () => showMessageSeenBySheet(
                context: context,
                conversationId: widget.conversationId,
                messageId: msg.id,
              ),
            );
          },
        ),
      );

      if (i + 1 < messages.length) {
        final next = messages[i + 1];
        if (next.type != 'system' &&
            !_isSameDay(msg.createdAt, next.createdAt)) {
          items.add(_buildDateSeparator(msg.createdAt));
        }
      }
    }
    return items;
  }

  bool _isSameGroup(LocalMessage? a, LocalMessage? b) {
    if (a == null || b == null) return false;
    if (a.type == 'system' || b.type == 'system') return false;
    if (a.senderId != b.senderId) return false;
    return a.createdAt.difference(b.createdAt).inMinutes.abs() < 5;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return areMessagesOnSameDay(a, b);
  }

  Widget _buildDateSeparator(DateTime date) {
    final palette = context.appPalette;
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    String label;
    if (_isSameDay(date, now)) {
      label = 'Hôm nay';
    } else if (_isSameDay(date, yesterday)) {
      label = 'Hôm qua';
    } else if (date.year == now.year) {
      label = '${date.day} tháng ${date.month}';
    } else {
      label =
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: palette.isLight
                ? const Color(0xFFDDE4EE)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: palette.isLight
                  ? const Color(0xFF6E7A8D)
                  : AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSystemMessage(LocalMessage msg) {
    Map<String, dynamic>? meta;
    if (msg.metadata != null) {
      try {
        meta = jsonDecode(msg.metadata!) as Map<String, dynamic>;
      } catch (_) {}
    }

    final reminderKind =
        meta?['kind'] as String? ??
        ((msg.content?.startsWith('chat_reminder_') ?? false)
            ? msg.content
            : null);
    if (reminderKind != null && reminderKind.startsWith('chat_reminder_')) {
      return _buildReminderSystemMessage(reminderKind, meta ?? const {});
    }

    final pocKind = meta?['kind']?.toString() ?? msg.content;
    if (pocKind != null && pocKind.startsWith('poc_')) {
      if (isSupportedPocSystemMetadata(meta)) {
        return _buildPocSystemMessage(pocKind, meta ?? const {});
      }
    }

    final actorName = meta?['actor_name'] as String? ?? '';
    final memberName = meta?['member_name'] as String? ?? '';
    final newName = meta?['new_name'] as String? ?? '';

    String text;
    switch (msg.content) {
      case 'created_group':
        text = '$actorName đã tạo nhóm';
      case 'added_member':
        text = '$actorName đã thêm $memberName';
      case 'removed_member':
        text = '$actorName đã xóa $memberName';
      case 'left_group':
        text = '$actorName đã rời nhóm';
      case 'renamed_group':
        text = '$actorName đã đổi tên nhóm thành «$newName»';
      case 'changed_avatar':
        text = '$actorName đã đổi ảnh nhóm';
      case 'pinned_message':
        text = '$actorName đã ghim một tin nhắn';
      case 'unpinned_message':
        text = '$actorName đã bỏ ghim một tin nhắn';
      case 'unpinned_all_messages':
        text = '$actorName đã bỏ ghim tất cả tin nhắn';
      default:
        text = msg.content ?? '';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildPocSystemMessage(String kind, Map<String, dynamic> meta) {
    return PocSystemMessageCard(
      kind: kind,
      metadata: meta,
      onOpen: context.push,
    );
  }

  Widget _buildReminderSystemMessage(String kind, Map<String, dynamic> meta) {
    final palette = context.appPalette;
    final cardColor = palette.isLight ? Colors.white : AppColors.surfaceVariant;
    final borderColor = palette.isLight
        ? const Color(0xFFDCE4EF)
        : AppColors.textHint.withValues(alpha: 0.35);
    final titleColor = palette.isLight
        ? const Color(0xFF1A2734)
        : AppColors.textPrimary;
    final secondaryColor = palette.isLight
        ? const Color(0xFF6A788A)
        : AppColors.textSecondary;
    final creatorName = meta['creator_name'] as String? ?? 'Ai do';
    final sourceMessageId = meta['source_message_id'] as String? ?? '';
    final decryptedSourcePreview = ref
        .watch(
          reminderSourcePreviewProvider((
            convId: widget.conversationId,
            messageId: sourceMessageId,
          )),
        )
        .valueOrNull;
    final backendPreview =
        meta['source_message_preview'] as String? ?? 'Tin nhắn';
    final sourcePreview =
        decryptedSourcePreview ??
        _readableReminderSourcePreview(backendPreview) ??
        'Tin nhắn gốc';
    final scope = _formatReminderScopeLabel(
      meta['scope'] as String? ?? 'everyone',
    );
    final remindAt = DateTime.tryParse(
      meta['remind_at'] as String? ?? '',
    )?.toLocal();

    String title;
    switch (kind) {
      case 'chat_reminder_created':
        title = '$creatorName đã tạo nhắc hẹn';
      case 'chat_reminder_updated':
        title = '$creatorName đã cập nhật nhắc hẹn';
      case 'chat_reminder_cancelled':
        title = '$creatorName đã hủy nhắc hẹn';
      case 'chat_reminder_fired':
        title = 'Nhắc hẹn đến giờ';
      default:
        title = 'Nhắc hẹn';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: palette.isLight
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.alarm_outlined,
                    size: 16,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                sourcePreview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: titleColor),
              ),
              const SizedBox(height: 6),
              Text(
                '${_formatReminderDateTime(remindAt)} • $scope',
                style: TextStyle(color: secondaryColor, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _readableReminderSourcePreview(String? value) {
    final preview = value?.trim();
    if (preview == null || preview.isEmpty) return null;
    final normalized = preview.toLowerCase();
    const hiddenPlaceholders = {
      '[message]',
      '[tin nhắn mã hóa]',
      '[tin nhan ma hoa]',
      'tin nhắn mã hóa',
      'tin nhan ma hoa',
      encryptedMessagePreviewPlaceholder,
      encryptedMessageDecryptFailedPlaceholder,
    };
    if (hiddenPlaceholders.contains(preview) ||
        hiddenPlaceholders.contains(normalized)) {
      return null;
    }
    return preview;
  }

  bool _isOnline(DateTime? lastSeenAt) {
    if (lastSeenAt == null) return false;
    return DateTime.now().difference(lastSeenAt).inMinutes < 2;
  }

  String _formatLastSeen(DateTime? lastSeenAt) {
    if (lastSeenAt == null) return '';
    final diff = DateTime.now().difference(lastSeenAt);
    if (diff.inMinutes < 2) return 'Đang hoạt động';
    if (diff.inMinutes < 60) return 'Hoạt động ${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return 'Hoạt động ${diff.inHours} giờ trước';
    return 'Hoạt động ${diff.inDays} ngày trước';
  }

  String? _getMemberRole(
    Map<String, Map<String, String?>> members,
    String userId,
  ) {
    return members[userId]?['role'];
  }

  String? _resolveReplySenderName(
    String currentUserId,
    bool isGroup,
    Map<String, Map<String, String?>> members,
    String? otherName,
  ) {
    if (_replyingTo == null) return null;
    if (_replyingTo!.senderId == currentUserId) return 'Bạn';
    if (isGroup) return members[_replyingTo!.senderId]?['name'] ?? 'Unknown';
    return otherName ?? 'Unknown';
  }

  Color? _resolveReplySenderColor(String currentUserId, bool isGroup) {
    if (_replyingTo == null) return null;
    if (_replyingTo!.senderId == currentUserId) return AppColors.gold;
    if (isGroup) {
      return AppColors.senderColors[_replyingTo!.senderId.hashCode.abs() %
          AppColors.senderColors.length];
    }
    return null;
  }
}
