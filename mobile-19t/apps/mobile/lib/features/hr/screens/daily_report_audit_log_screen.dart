import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:nineteen_tech_app/features/hr/data/daily_report_audit_log_models.dart';
import 'package:nineteen_tech_app/features/hr/data/daily_report_audit_log_sse_service.dart';
import 'package:nineteen_tech_app/features/hr/providers/daily_report_providers.dart';

class DailyReportAuditLogScreen extends ConsumerStatefulWidget {
  const DailyReportAuditLogScreen({super.key});

  @override
  ConsumerState<DailyReportAuditLogScreen> createState() =>
      _DailyReportAuditLogScreenState();
}

class _DailyReportAuditLogScreenState
    extends ConsumerState<DailyReportAuditLogScreen>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  DailyReportAuditLogFilter _selectedFilter = DailyReportAuditLogFilter.all;
  String _searchQuery = '';
  List<DailyReportAuditLog> _items = const [];
  bool _isLoading = true;
  Object? _error;
  DailyReportAuditLogStreamState _streamState =
      DailyReportAuditLogStreamState.disconnected;
  StreamSubscription<DailyReportAuditLogStreamEvent>? _eventSubscription;
  StreamSubscription<DailyReportAuditLogStreamState>? _stateSubscription;
  DailyReportAuditLogSseService? _sseService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bindSseService();
      _loadHistoryAndStartRealtime();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_resumeRealtime());
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_stopRealtime());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_disposeRealtime());
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1720),
        foregroundColor: Colors.white,
        title: Text(
          'Daily Report Audit Logs',
          style: GoogleFonts.robotoMono(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _loadHistoryAndStartRealtime,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _AuditToolbar(
            controller: _searchController,
            selectedFilter: _selectedFilter,
            onFilterSelected: (filter) {
              setState(() => _selectedFilter = filter);
              _loadHistoryAndStartRealtime();
            },
            onSearchChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF60A5FA),
              backgroundColor: const Color(0xFF111827),
              onRefresh: _loadHistoryAndStartRealtime,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final filtered = _items
        .where((item) => item.matchesSearch(_searchQuery))
        .toList(growable: false);

    if (_isLoading) {
      return const _AuditLoadingState();
    }

    if (_error != null) {
      return _AuditErrorState(
        message: '$_error',
        onRetry: _loadHistoryAndStartRealtime,
      );
    }

    if (filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        children: [
          _LiveStatusBanner(
            count: _items.length,
            streamState: _streamState,
            filter: _selectedFilter,
          ),
          const SizedBox(height: 12),
          const _AuditEmptyPanel(),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      children: [
        _LiveStatusBanner(
          count: _items.length,
          streamState: _streamState,
          filter: _selectedFilter,
        ),
        const SizedBox(height: 12),
        ...List.generate(filtered.length, (index) {
          final item = filtered[index];
          return Padding(
            padding: EdgeInsets.only(bottom: index == filtered.length - 1 ? 0 : 10),
            child: _AuditLogCard(
              item: item,
              onTap: () => _showAuditLogDetails(context, item),
            ),
          );
        }),
      ],
    );
  }

  void _bindSseService() {
    final service = ref.read(dailyReportAuditLogSseServiceProvider);
    _sseService = service;
    _eventSubscription?.cancel();
    _stateSubscription?.cancel();
    _eventSubscription = service.events.listen(_handleRealtimeEvent);
    _stateSubscription = service.stateStream.listen((state) {
      if (!mounted) return;
      setState(() => _streamState = state);
    });
  }

  Future<void> _loadHistoryAndStartRealtime() async {
    final query = _buildApiQuery();
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final page = await ref
          .read(dailyReportRepositoryProvider)
          .getAuditLogs(query: query);
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _isLoading = false;
        _error = null;
      });
      await _sseService?.restart(query: query);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error;
      });
      await _sseService?.restart(query: query);
    }
  }

  Future<void> _resumeRealtime() async {
    if (_sseService == null) {
      _bindSseService();
    }
    await _sseService?.start(query: _buildApiQuery());
  }

  Future<void> _stopRealtime() async {
    await _sseService?.stop();
  }

  Future<void> _disposeRealtime() async {
    await _eventSubscription?.cancel();
    await _stateSubscription?.cancel();
    await _sseService?.stop();
  }

  void _handleRealtimeEvent(DailyReportAuditLogStreamEvent event) {
    if (!mounted) return;
    setState(() {
      switch (event) {
        case DailyReportAuditLogSnapshotStreamEvent():
          _items = mergeDailyReportAuditLogs(const [], event.items);
          break;
        case DailyReportAuditLogInsertStreamEvent():
          _items = mergeDailyReportAuditLogs(_items, [event.item]);
          break;
      }
    });
  }

  DailyReportAuditLogQuery _buildApiQuery() {
    return _queryForFilter(
      const DailyReportAuditLogQuery(limit: 20),
      _selectedFilter,
    );
  }

  Future<void> _showAuditLogDetails(
    BuildContext context,
    DailyReportAuditLog item,
  ) {
    final metadataJson = const JsonEncoder.withIndent(
      '  ',
    ).convert(item.metadata);
    final rawJson = const JsonEncoder.withIndent('  ').convert(item.raw);

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1720),
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.82,
              minChildSize: 0.45,
              maxChildSize: 0.95,
              builder: (context, controller) {
                return ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      auditEventTypeLabel(item.eventType),
                      style: GoogleFonts.robotoMono(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _AuditInfoLine(label: 'Event type', value: item.eventType),
                    _AuditInfoLine(
                      label: 'Status',
                      value: item.status?.isNotEmpty == true ? item.status! : '-',
                    ),
                    _AuditInfoLine(
                      label: 'Reason',
                      value: item.reason ?? '-',
                    ),
                    _AuditInfoLine(
                      label: 'Report ID',
                      value: item.entityId.isNotEmpty ? item.entityId : '-',
                    ),
                    _AuditInfoLine(
                      label: 'User ID',
                      value: item.userId.isNotEmpty ? item.userId : '-',
                    ),
                    _AuditInfoLine(label: 'Created', value: _formatLogTime(item)),
                    const SizedBox(height: 16),
                    _JsonTerminalBlock(title: 'metadata', content: metadataJson),
                    const SizedBox(height: 12),
                    _JsonTerminalBlock(title: 'raw', content: rawJson),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Đóng'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

DailyReportAuditLogQuery _queryForFilter(
  DailyReportAuditLogQuery base,
  DailyReportAuditLogFilter filter,
) {
  return switch (filter) {
    DailyReportAuditLogFilter.all => base.copyWith(
      clearEventType: true,
      clearStatus: true,
    ),
    DailyReportAuditLogFilter.submitted => base.copyWith(
      eventType: 'daily_report.submitted',
      status: 'success',
    ),
    DailyReportAuditLogFilter.advanced => base.copyWith(
      eventType: 'daily_report.stage_sync.advanced',
      status: 'advanced',
    ),
    DailyReportAuditLogFilter.skipped => base.copyWith(
      eventType: 'daily_report.stage_sync.skipped',
      status: 'skipped',
    ),
    DailyReportAuditLogFilter.failed => base.copyWith(
      eventType: 'daily_report.stage_sync.failed',
      status: 'failed',
    ),
  };
}

class _LiveStatusBanner extends StatelessWidget {
  const _LiveStatusBanner({
    required this.count,
    required this.streamState,
    required this.filter,
  });

  final int count;
  final DailyReportAuditLogStreamState streamState;
  final DailyReportAuditLogFilter filter;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (streamState) {
      DailyReportAuditLogStreamState.connected => ('LIVE', const Color(0xFF34D399)),
      DailyReportAuditLogStreamState.connecting => ('CONNECTING', const Color(0xFF60A5FA)),
      DailyReportAuditLogStreamState.reconnecting => (
        'RECONNECTING',
        const Color(0xFFF59E0B),
      ),
      DailyReportAuditLogStreamState.disconnected => (
        'OFFLINE',
        const Color(0xFF94A3B8),
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _StatusBadge(label: label, color: color),
          _InlineTerminalTag(label: 'count', value: '$count'),
          _InlineTerminalTag(label: 'filter', value: filter.label),
          Text(
            'History + SSE stream',
            style: GoogleFonts.robotoMono(
              color: const Color(0xFFCBD5E1),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditToolbar extends StatelessWidget {
  const _AuditToolbar({
    required this.controller,
    required this.selectedFilter,
    required this.onFilterSelected,
    required this.onSearchChanged,
  });

  final TextEditingController controller;
  final DailyReportAuditLogFilter selectedFilter;
  final ValueChanged<DailyReportAuditLogFilter> onFilterSelected;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final mono = GoogleFonts.robotoMono();

    return Container(
      color: const Color(0xFF0F1720),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onChanged: onSearchChanged,
            style: mono.copyWith(color: const Color(0xFFE5E7EB)),
            decoration: InputDecoration(
              hintText: 'Search report id / task name / task id',
              hintStyle: mono.copyWith(color: const Color(0xFF6B7280)),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF60A5FA),
              ),
              filled: true,
              fillColor: const Color(0xFF111827),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1F2937)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF60A5FA)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: DailyReportAuditLogFilter.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = DailyReportAuditLogFilter.values[index];
                final selected = filter == selectedFilter;
                return FilterChip(
                  label: Text(filter.label, style: mono),
                  selected: selected,
                  labelStyle: mono.copyWith(
                    color: selected ? Colors.white : const Color(0xFFCBD5E1),
                    fontWeight: FontWeight.w600,
                  ),
                  selectedColor: _filterColor(filter).withValues(alpha: 0.25),
                  checkmarkColor: _filterColor(filter),
                  backgroundColor: const Color(0xFF111827),
                  side: BorderSide(
                    color: selected
                        ? _filterColor(filter).withValues(alpha: 0.8)
                        : const Color(0xFF1F2937),
                  ),
                  onSelected: (_) => onFilterSelected(filter),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditLogCard extends StatelessWidget {
  const _AuditLogCard({required this.item, required this.onTap});

  final DailyReportAuditLog item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = auditStatusColor(item);
    final mono = GoogleFonts.robotoMono();
    final friendlyReason = auditReasonLabel(item.reason);
    final metadataPreview = item.metadata.isEmpty
        ? null
        : const JsonEncoder.withIndent('  ').convert(item.metadata);

    return Material(
      color: const Color(0xFF111827),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
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
                          auditEventTypeLabel(item.eventType),
                          style: mono.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.eventType,
                          style: mono.copyWith(
                            color: const Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StatusBadge(
                    label: auditStatusLabel(item),
                    color: accent,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InlineTerminalTag(
                    label: 'report',
                    value: item.entityId.isNotEmpty ? item.entityId : '-',
                  ),
                  if ((item.taskId ?? '').isNotEmpty)
                    _InlineTerminalTag(label: 'taskId', value: item.taskId!),
                  if ((item.taskName ?? '').isNotEmpty)
                    _InlineTerminalTag(label: 'task', value: item.taskName!),
                  if ((item.projectId ?? '').isNotEmpty)
                    _InlineTerminalTag(
                      label: 'projectId',
                      value: item.projectId!,
                    ),
                  if ((item.projectName ?? '').isNotEmpty)
                    _InlineTerminalTag(
                      label: 'project',
                      value: item.projectName!,
                    ),
                  if ((item.reportType ?? '').isNotEmpty)
                    _InlineTerminalTag(
                      label: 'reportType',
                      value: item.reportType!,
                    ),
                ],
              ),
              if (friendlyReason != null) ...[
                const SizedBox(height: 12),
                Text(
                  'reason: $friendlyReason',
                  style: mono.copyWith(
                    color: const Color(0xFFFDE68A),
                    fontSize: 12,
                  ),
                ),
              ],
              if ((item.metadataError ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'error: ${item.metadataError}',
                  style: mono.copyWith(
                    color: const Color(0xFFFCA5A5),
                    fontSize: 12,
                  ),
                ),
              ],
              if (item.hasStageInfo) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0F14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (item.fromStageId != null)
                        _InlineTerminalTag(
                          label: 'fromStageId',
                          value: item.fromStageId!,
                        ),
                      if (item.toStageId != null)
                        _InlineTerminalTag(
                          label: 'toStageId',
                          value: item.toStageId!,
                        ),
                      if (item.toStageName != null)
                        _InlineTerminalTag(
                          label: 'toStageName',
                          value: item.toStageName!,
                        ),
                      if (item.expectedStageId != null)
                        _InlineTerminalTag(
                          label: 'expectedStageId',
                          value: item.expectedStageId!,
                        ),
                      if (item.liveStageId != null)
                        _InlineTerminalTag(
                          label: 'liveStageId',
                          value: item.liveStageId!,
                        ),
                    ],
                  ),
                ),
              ],
              if (metadataPreview != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0F14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: Text(
                    metadataPreview,
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                    style: mono.copyWith(
                      color: const Color(0xFFD1FAE5),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: Color(0xFF60A5FA),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatLogTime(item),
                      style: mono.copyWith(
                        color: const Color(0xFF93C5FD),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    'view raw',
                    style: mono.copyWith(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.robotoMono(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InlineTerminalTag extends StatelessWidget {
  const _InlineTerminalTag({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Text(
        '$label=$value',
        style: GoogleFonts.robotoMono(
          color: const Color(0xFFD1D5DB),
          fontSize: 11,
        ),
      ),
    );
  }
}

class _AuditLoadingState extends StatelessWidget {
  const _AuditLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: const [
        SizedBox(height: 80),
        Center(
          child: CircularProgressIndicator(color: Color(0xFF60A5FA)),
        ),
      ],
    );
  }
}

class _AuditErrorState extends StatelessWidget {
  const _AuditErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF7F1D1D)),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFF87171),
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                'Không tải được audit logs',
                style: GoogleFonts.robotoMono(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.robotoMono(
                  color: const Color(0xFFFCA5A5),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB91C1C),
                ),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuditEmptyState extends StatelessWidget {
  const _AuditEmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: const [SizedBox(height: 12), _AuditEmptyPanel()],
    );
  }
}

class _AuditEmptyPanel extends StatelessWidget {
  const _AuditEmptyPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 80),
        Icon(
          Icons.terminal_rounded,
          size: 48,
          color: Colors.white.withValues(alpha: 0.35),
        ),
        const SizedBox(height: 12),
        Text(
          'No audit logs found',
          textAlign: TextAlign.center,
          style: GoogleFonts.robotoMono(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Không có log phù hợp với bộ lọc hoặc từ khóa hiện tại.',
          textAlign: TextAlign.center,
          style: GoogleFonts.robotoMono(
            color: const Color(0xFF94A3B8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _AuditInfoLine extends StatelessWidget {
  const _AuditInfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.robotoMono(
            fontSize: 13,
            color: const Color(0xFFE5E7EB),
            height: 1.5,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: Color(0xFF60A5FA)),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _JsonTerminalBlock extends StatelessWidget {
  const _JsonTerminalBlock({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.robotoMono(
              color: const Color(0xFF60A5FA),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            content,
            style: GoogleFonts.robotoMono(
              color: const Color(0xFFD1FAE5),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

String auditEventTypeLabel(String eventType) {
  return switch (eventType) {
    'daily_report.submitted' => 'Submitted',
    'daily_report.stage_sync.advanced' => 'Advanced',
    'daily_report.stage_sync.skipped' => 'Skipped',
    'daily_report.stage_sync.failed' => 'Failed',
    _ => eventType,
  };
}

String? auditReasonLabel(String? reason) {
  if (reason == null || reason.trim().isEmpty) {
    return null;
  }
  return switch (reason.trim()) {
    'stale_snapshot' => 'Snapshot task bi stale so với trạng thái live',
    'invalid_task_id' => 'Task ID không hợp lệ',
    'missing_expected_stage' => 'Thiếu expected stage',
    'missing_live_stage' => 'Thiếu live stage',
    'already_in_expected_stage' => 'Task đã ở đúng stage mong đợi',
    'odoo_sync_error' => 'Đồng bộ stage sang Odoo thất bại',
    _ => reason,
  };
}

String auditStatusLabel(DailyReportAuditLog item) {
  final normalized = item.status?.trim().toLowerCase() ?? '';
  if (normalized.isNotEmpty) {
    return switch (normalized) {
      'success' => 'SUCCESS',
      'advanced' => 'ADVANCED',
      'skipped' => 'SKIPPED',
      'failed' => 'FAILED',
      _ => normalized.toUpperCase(),
    };
  }

  return switch (item.eventType) {
    'daily_report.submitted' => 'SUBMITTED',
    'daily_report.stage_sync.advanced' => 'ADVANCED',
    'daily_report.stage_sync.skipped' => 'SKIPPED',
    'daily_report.stage_sync.failed' => 'FAILED',
    _ => 'LOG',
  };
}

Color auditStatusColor(DailyReportAuditLog item) {
  final normalized = item.status?.trim().toLowerCase() ?? '';
  if (normalized == 'failed') return const Color(0xFFF87171);
  if (normalized == 'skipped') return const Color(0xFFF59E0B);
  if (normalized == 'advanced' || normalized == 'success') {
    return const Color(0xFF34D399);
  }

  return switch (item.eventType) {
    'daily_report.stage_sync.failed' => const Color(0xFFF87171),
    'daily_report.stage_sync.skipped' => const Color(0xFFF59E0B),
    'daily_report.stage_sync.advanced' => const Color(0xFF34D399),
    'daily_report.submitted' => const Color(0xFF60A5FA),
    _ => const Color(0xFF94A3B8),
  };
}

Color _filterColor(DailyReportAuditLogFilter filter) {
  return switch (filter) {
    DailyReportAuditLogFilter.all => const Color(0xFF94A3B8),
    DailyReportAuditLogFilter.submitted => const Color(0xFF60A5FA),
    DailyReportAuditLogFilter.advanced => const Color(0xFF34D399),
    DailyReportAuditLogFilter.skipped => const Color(0xFFF59E0B),
    DailyReportAuditLogFilter.failed => const Color(0xFFF87171),
  };
}

String _formatLogTime(DailyReportAuditLog item) {
  final value = item.createdAt?.toLocal();
  if (value == null) return '-';
  return DateFormat('HH:mm:ss dd/MM/yyyy').format(value);
}
