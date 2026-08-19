import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../../chat/data/user_repository.dart';
import '../../chat/providers/chat_providers.dart';
import '../models/poc_models.dart';
import '../providers/poc_providers.dart';
import '../widgets/poc_widgets.dart';

class PocListScreen extends ConsumerStatefulWidget {
  const PocListScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  ConsumerState<PocListScreen> createState() => _PocListScreenState();
}

class _PocListScreenState extends ConsumerState<PocListScreen> {
  String _mode = 'my_pocs';
  String _search = '';
  String? _status;
  String? _developerUserId;
  String? _saleUserId;
  String? _priority;
  int _page = 1;

  PocListFilter get _filter => (
    mode: _mode,
    search: _search,
    status: _status,
    week: _mode == 'week' ? DateTime.now().toIso8601String() : null,
    developerUserId: _developerUserId,
    saleUserId: _saleUserId,
    priority: _priority,
    page: _page,
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final async = ref.watch(pocListProvider(_filter));
    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Tìm mã, khách hàng, dự án',
                        isDense: true,
                      ),
                      onSubmitted: (value) =>
                          setState(() => _search = value.trim()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String?>(
                    tooltip: 'Lọc trạng thái',
                    icon: const Icon(Icons.filter_list),
                    onSelected: (value) => setState(() {
                      _status = value;
                      _page = 1;
                    }),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: null,
                        child: Text('Tất cả trạng thái'),
                      ),
                      PopupMenuItem(
                        value: 'unassigned',
                        child: Text('Chờ phân công'),
                      ),
                      PopupMenuItem(
                        value: 'assigned',
                        child: Text('Đã phân công'),
                      ),
                      PopupMenuItem(
                        value: 'in_progress',
                        child: Text('Đang làm'),
                      ),
                      PopupMenuItem(value: 'ready', child: Text('Sẵn sàng')),
                      PopupMenuItem(
                        value: 'demonstrated',
                        child: Text('Đã demo'),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Bộ lọc nâng cao',
                    icon: const Icon(Icons.tune),
                    onPressed: _showAdvancedFilters,
                  ),
                  IconButton(
                    tooltip: 'Xem tải Dev',
                    icon: const Icon(Icons.calendar_view_week_outlined),
                    onPressed: () => context.push('/pocs/capacity'),
                  ),
                  IconButton(
                    tooltip: 'Báo cáo tuần',
                    icon: const Icon(Icons.summarize_outlined),
                    onPressed: () => context.push('/pocs/week'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) => constraints.maxWidth < 620
                    ? DropdownButtonFormField<String>(
                        initialValue: _mode,
                        decoration: const InputDecoration(
                          labelText: 'Danh sách PoC',
                          prefixIcon: Icon(Icons.view_list_outlined),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'my_pocs',
                            child: Text('PoC của tôi'),
                          ),
                          DropdownMenuItem(
                            value: 'my_requests',
                            child: Text('Yêu cầu của tôi'),
                          ),
                          DropdownMenuItem(
                            value: 'unassigned',
                            child: Text('Chờ phân công'),
                          ),
                          DropdownMenuItem(
                            value: 'week',
                            child: Text('Tuần này'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _mode = value;
                            _page = 1;
                          });
                        },
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'my_pocs',
                              label: Text('PoC của tôi'),
                            ),
                            ButtonSegment(
                              value: 'my_requests',
                              label: Text('Yêu cầu'),
                            ),
                            ButtonSegment(
                              value: 'unassigned',
                              label: Text('Chờ giao'),
                            ),
                            ButtonSegment(
                              value: 'week',
                              label: Text('Tuần này'),
                            ),
                          ],
                          selected: {_mode},
                          showSelectedIcon: false,
                          onSelectionChanged: (value) => setState(() {
                            _mode = value.first;
                            _page = 1;
                          }),
                        ),
                      ),
              ),
            ],
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ErrorState(
              error: error,
              onRetry: () => ref.invalidate(pocListProvider(_filter)),
            ),
            data: (page) => _PocResults(
              page: page,
              currentPage: _page,
              onPageChanged: (page) => setState(() => _page = page),
              onRefresh: () async {
                ref.invalidate(pocListProvider(_filter));
                await ref.read(pocListProvider(_filter).future);
              },
            ),
          ),
        ),
      ],
    );
    return Scaffold(
      backgroundColor: palette.background,
      appBar: widget.embedded ? null : AppBar(title: const Text('PoC & Demo')),
      body: content,
      floatingActionButton: FloatingActionButton(
        tooltip: 'Tạo yêu cầu PoC',
        backgroundColor: palette.primary,
        foregroundColor: palette.isLight ? Colors.white : Colors.black,
        onPressed: () => context.push('/pocs/new'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAdvancedFilters() async {
    List<UserContact> users = const [];
    try {
      users =
          (await ref.read(userRepositoryProvider).getUsers(limit: 100)).users;
    } catch (_) {}
    if (!mounted) return;
    var developerId = _developerUserId;
    var saleId = _saleUserId;
    var priority = _priority;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              18,
              16,
              18 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bộ lọc PoC',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: developerId,
                  decoration: const InputDecoration(labelText: 'Developer'),
                  items: _userItems(users),
                  onChanged: (value) =>
                      setModalState(() => developerId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: saleId,
                  decoration: const InputDecoration(
                    labelText: 'Sale phụ trách',
                  ),
                  items: _userItems(users),
                  onChanged: (value) => setModalState(() => saleId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Mức ưu tiên'),
                  items: const [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Tất cả'),
                    ),
                    DropdownMenuItem(value: 'low', child: Text('Thấp')),
                    DropdownMenuItem(
                      value: 'normal',
                      child: Text('Bình thường'),
                    ),
                    DropdownMenuItem(value: 'high', child: Text('Cao')),
                    DropdownMenuItem(value: 'urgent', child: Text('Khẩn cấp')),
                  ],
                  onChanged: (value) => setModalState(() => priority = value),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        developerId = null;
                        saleId = null;
                        priority = null;
                        Navigator.pop(context, true);
                      },
                      child: const Text('Xóa lọc'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Áp dụng'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (applied == true && mounted) {
      setState(() {
        _developerUserId = developerId;
        _saleUserId = saleId;
        _priority = priority;
        _page = 1;
      });
    }
  }

  List<DropdownMenuItem<String?>> _userItems(List<UserContact> users) => [
    const DropdownMenuItem<String?>(value: null, child: Text('Tất cả')),
    ...users.map(
      (user) => DropdownMenuItem<String?>(
        value: user.id,
        child: Text(user.name, overflow: TextOverflow.ellipsis),
      ),
    ),
  ];
}

class _PocResults extends StatelessWidget {
  const _PocResults({
    required this.page,
    required this.currentPage,
    required this.onPageChanged,
    required this.onRefresh,
  });
  final PocPage page;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    if (page.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.science_outlined, size: 56, color: palette.textHint),
            const SizedBox(height: 12),
            Text(
              'Chưa có PoC phù hợp',
              style: TextStyle(color: palette.textSecondary),
            ),
          ],
        ),
      );
    }
    final overdue = page.items.where((item) => item.overdue).length;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: page.items.length + 2,
        separatorBuilder: (_, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: overdue > 0
                    ? AppColors.danger.withValues(alpha: 0.08)
                    : palette.surfaceVariant,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${page.total} PoC · $overdue quá hạn',
                style: TextStyle(
                  color: overdue > 0 ? AppColors.danger : palette.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }
          if (index == page.items.length + 1) {
            final hasNext = currentPage * page.limit < page.total;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Trang trước',
                  onPressed: currentPage > 1
                      ? () => onPageChanged(currentPage - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('Trang $currentPage'),
                IconButton(
                  tooltip: 'Trang sau',
                  onPressed: hasNext
                      ? () => onPageChanged(currentPage + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            );
          }
          final poc = page.items[index - 1];
          return PocListCard(
            poc: poc,
            onTap: () => context.push('/pocs/${poc.id}'),
          );
        },
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: AppColors.danger, size: 44),
        const SizedBox(height: 10),
        Text('Không tải được PoC: $error', textAlign: TextAlign.center),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Thử lại'),
        ),
      ],
    ),
  );
}
