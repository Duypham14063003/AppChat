import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/hr_models.dart';
import '../providers/hr_providers.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/snackbar_utils.dart';

class RewardAdminConfigScreen extends ConsumerStatefulWidget {
  const RewardAdminConfigScreen({super.key});

  @override
  ConsumerState<RewardAdminConfigScreen> createState() => _RewardAdminConfigScreenState();
}

class _RewardAdminConfigScreenState extends ConsumerState<RewardAdminConfigScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchJobTitleCtrl = TextEditingController();
  final _searchRoleCtrl = TextEditingController();
  final _searchTagCtrl = TextEditingController();

  String _searchJobTitleQuery = '';
  String _searchRoleQuery = '';
  String _searchTagQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchJobTitleCtrl.addListener(() {
      setState(() => _searchJobTitleQuery = _searchJobTitleCtrl.text.trim().toLowerCase());
    });
    _searchRoleCtrl.addListener(() {
      setState(() => _searchRoleQuery = _searchRoleCtrl.text.trim().toLowerCase());
    });
    _searchTagCtrl.addListener(() {
      setState(() => _searchTagQuery = _searchTagCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchJobTitleCtrl.dispose();
    _searchRoleCtrl.dispose();
    _searchTagCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Cấu hình Thưởng'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: palette.primary,
          labelColor: palette.primary,
          unselectedLabelColor: palette.textSecondary,
          labelStyle: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Chức danh Odoo'),
            Tab(text: 'Hệ số vai trò'),
            Tab(text: 'Tag Odoo'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _JobTitlesTab(
            palette: palette,
            searchQuery: _searchJobTitleQuery,
            searchController: _searchJobTitleCtrl,
          ),
          _InternalRolesTab(
            palette: palette,
            searchQuery: _searchRoleQuery,
            searchController: _searchRoleCtrl,
          ),
          _OdooTagConfigsTab(
            palette: palette,
            searchQuery: _searchTagQuery,
            searchController: _searchTagCtrl,
          ),
        ],
      ),
    );
  }
}

// ================= JOB TITLES OVERVIEW & MAPPING TAB =================

class _JobTitlesTab extends ConsumerStatefulWidget {
  const _JobTitlesTab({
    required this.palette,
    required this.searchQuery,
    required this.searchController,
  });

  final AppThemePalette palette;
  final String searchQuery;
  final TextEditingController searchController;

  @override
  ConsumerState<_JobTitlesTab> createState() => _JobTitlesTabState();
}

class _JobTitlesTabState extends ConsumerState<_JobTitlesTab> {
  bool _isSyncing = false;

  Future<void> _syncData() async {
    setState(() => _isSyncing = true);
    try {
      final repo = ref.read(hrRepositoryProvider);
      await repo.syncJobTitles();
      ref.invalidate(jobTitlesOverviewProvider);
      if (mounted) {
        showTopSnackBar(context, message: 'Đồng bộ chức danh thành công');
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, message: 'Lỗi đồng bộ: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(jobTitlesOverviewProvider);
    final rolesAsync = ref.watch(internalRolesProvider);

    return Column(
      children: [
        // Sync Button and Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.searchController,
                  decoration: InputDecoration(
                    labelText: 'Tìm kiếm chức danh...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: widget.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => widget.searchController.clear(),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _isSyncing
                  ? const SizedBox(
                      width: 48,
                      height: 48,
                      child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: widget.palette.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(12),
                      ),
                      icon: const Icon(Icons.sync_rounded),
                      tooltip: 'Đồng bộ từ Odoo',
                      onPressed: _syncData,
                    ),
            ],
          ),
        ),

        // List view
        Expanded(
          child: overviewAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Lỗi: $e', style: TextStyle(color: widget.palette.textSecondary)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(jobTitlesOverviewProvider),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
            data: (items) {
              final filteredItems = items
                  .where((item) => item.jobTitle.toLowerCase().contains(widget.searchQuery))
                  .toList();

              if (filteredItems.isEmpty) {
                return const Center(child: Text('Không tìm thấy chức danh phù hợp'));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  final isConfigured = item.isConfigured;

                  return Card(
                    color: widget.palette.card,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: widget.palette.surfaceVariant),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(
                        item.jobTitle,
                        style: AppTypography.titleMedium.copyWith(
                          color: widget.palette.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Số nhân viên: ${item.userCount} • ${isConfigured ? "Nhóm: ${item.internalRoleName ?? "Chưa rõ"}" : "Chưa cấu hình nhóm"}',
                          style: TextStyle(color: widget.palette.textSecondary),
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isConfigured
                              ? AppColors.online.withOpacity(0.12)
                              : Colors.orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isConfigured ? AppColors.online : Colors.orange,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          isConfigured ? 'ĐÃ CẤU HÌNH' : 'CHƯA CẤU HÌNH',
                          style: TextStyle(
                            color: isConfigured ? AppColors.online : Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      onTap: () {
                        rolesAsync.whenData((roles) {
                          _showMappingDialog(context, ref, item, roles);
                        });
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showMappingDialog(
    BuildContext context,
    WidgetRef ref,
    OdooJobTitleOverview item,
    List<RewardInternalRole> roles,
  ) {
    String? selectedRoleId = item.internalRoleId ?? (roles.isNotEmpty ? roles.first.id : null);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: widget.palette.surface,
              title: Text(
                item.jobTitle,
                style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700),
              ),
              content: roles.isEmpty
                  ? const Text('Chưa có nhóm vai trò nội bộ nào. Vui lòng tạo nhóm trước.')
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ánh xạ chức danh này vào nhóm vai trò nội bộ:'),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          dropdownColor: widget.palette.surface,
                          value: selectedRoleId,
                          items: roles.map((role) {
                            return DropdownMenuItem<String>(
                              value: role.id,
                              child: Text(role.roleName.toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() => selectedRoleId = value);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Nhóm vai trò (Internal Role)',
                          ),
                        ),
                      ],
                    ),
              actions: [
                if (item.isConfigured && item.mappingId != null)
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      try {
                        final repo = ref.read(hrRepositoryProvider);
                        await repo.deleteJobTitleMapping(item.mappingId!);
                        ref.invalidate(jobTitlesOverviewProvider);
                        if (context.mounted) {
                          showTopSnackBar(context, message: 'Đã xóa ánh xạ thành công');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showTopSnackBar(context, message: 'Lỗi khi xóa: $e');
                        }
                      }
                    },
                    style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                    child: const Text('Xóa ánh xạ'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                if (roles.isNotEmpty)
                  ElevatedButton(
                    onPressed: () async {
                      if (selectedRoleId == null) return;
                      Navigator.pop(context);
                      try {
                        final repo = ref.read(hrRepositoryProvider);
                        if (item.isConfigured && item.mappingId != null) {
                          await repo.updateJobTitleMapping(item.mappingId!, internalRoleId: selectedRoleId!);
                        } else {
                          await repo.createJobTitleMapping(jobTitle: item.jobTitle, internalRoleId: selectedRoleId!);
                        }
                        ref.invalidate(jobTitlesOverviewProvider);
                        if (context.mounted) {
                          showTopSnackBar(context, message: 'Đã lưu ánh xạ thành công');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showTopSnackBar(context, message: 'Lỗi khi lưu: $e');
                        }
                      }
                    },
                    child: const Text('Lưu'),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

// ================= INTERNAL ROLES TAB =================

class _InternalRolesTab extends ConsumerWidget {
  const _InternalRolesTab({
    required this.palette,
    required this.searchQuery,
    required this.searchController,
  });

  final AppThemePalette palette;
  final String searchQuery;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesAsync = ref.watch(internalRolesProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'Tìm kiếm nhóm...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => searchController.clear(),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(12),
                ),
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Thêm nhóm vai trò mới',
                onPressed: () => _showAddRoleDialog(context, ref),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Card(
            color: palette.primary.withOpacity(0.05),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: palette.primary.withOpacity(0.15)),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lưu ý: Với nhóm QC, hệ số là số điểm trực tiếp. Với nhóm khác, đây là hệ số nhân.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: rolesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Lỗi: $e', style: TextStyle(color: palette.textSecondary)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(internalRolesProvider),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
            data: (roles) {
              final filteredRoles = roles
                  .where((role) => role.roleName.toLowerCase().contains(searchQuery))
                  .toList();

              if (filteredRoles.isEmpty) {
                return const Center(child: Text('Không tìm thấy nhóm vai trò nào'));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: filteredRoles.length,
                itemBuilder: (context, index) {
                  final role = filteredRoles[index];
                  final isQc = role.roleName.toLowerCase() == 'qc';

                  return Card(
                    color: palette.card,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: palette.surfaceVariant),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      leading: CircleAvatar(
                        backgroundColor: palette.primary.withOpacity(0.1),
                        child: Icon(Icons.badge_outlined, color: palette.primary),
                      ),
                      title: Text(
                        role.roleName.toUpperCase(),
                        style: AppTypography.titleMedium.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(isQc ? 'Số điểm gốc mỗi task' : 'Hệ số nhân điểm thưởng'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            role.multiplier.toStringAsFixed(1),
                            style: AppTypography.headlineMedium.copyWith(
                              color: palette.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                            onPressed: () => _editRoleMultiplier(context, ref, role),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                            onPressed: () => _confirmDeleteRole(context, ref, role),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddRoleDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final multiplierCtrl = TextEditingController(text: '1.0');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: palette.surface,
          title: const Text('Thêm nhóm vai trò mới'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tên nhóm (ví dụ: Designer, Tester)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: multiplierCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Hệ số nhân / Điểm gốc QC',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final double? multiplier = double.tryParse(multiplierCtrl.text);

                if (name.isEmpty) {
                  showTopSnackBar(context, message: 'Vui lòng nhập tên nhóm');
                  return;
                }
                if (multiplier == null || multiplier < 0) {
                  showTopSnackBar(context, message: 'Hệ số không hợp lệ');
                  return;
                }
                Navigator.pop(context);
                try {
                  final repo = ref.read(hrRepositoryProvider);
                  await repo.createInternalRole(name, multiplier);
                  ref.invalidate(internalRolesProvider);
                  if (context.mounted) {
                    showTopSnackBar(context, message: 'Đã thêm thành công');
                  }
                } catch (e) {
                  if (context.mounted) {
                    showTopSnackBar(context, message: 'Lỗi khi thêm: $e');
                  }
                }
              },
              child: const Text('Thêm'),
            ),
          ],
        );
      },
    );
  }

  void _editRoleMultiplier(BuildContext context, WidgetRef ref, RewardInternalRole role) {
    final controller = TextEditingController(text: role.multiplier.toString());
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: palette.surface,
          title: Text('Sửa hệ số: ${role.roleName.toUpperCase()}'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Hệ số nhân / Điểm gốc QC',
              hintText: 'Ví dụ: 1.2',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                final double? multiplier = double.tryParse(controller.text);
                if (multiplier == null || multiplier < 0) {
                  showTopSnackBar(context, message: 'Hệ số không hợp lệ');
                  return;
                }
                Navigator.pop(context);
                try {
                  final repo = ref.read(hrRepositoryProvider);
                  await repo.updateInternalRole(role.id, multiplier);
                  ref.invalidate(internalRolesProvider);
                  if (context.mounted) {
                    showTopSnackBar(context, message: 'Đã cập nhật thành công');
                  }
                } catch (e) {
                  if (context.mounted) {
                    showTopSnackBar(context, message: 'Lỗi: $e');
                  }
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteRole(BuildContext context, WidgetRef ref, RewardInternalRole role) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: palette.surface,
          title: const Text('Xác nhận xóa'),
          content: Text('Bạn có chắc muốn xóa vai trò "${role.roleName.toUpperCase()}"? Điều này có thể ảnh hưởng đến ánh xạ hiện có.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  final repo = ref.read(hrRepositoryProvider);
                  await repo.deleteInternalRole(role.id);
                  ref.invalidate(internalRolesProvider);
                  if (context.mounted) {
                    showTopSnackBar(context, message: 'Đã xóa vai trò thành công');
                  }
                } catch (e) {
                  if (context.mounted) {
                    showTopSnackBar(context, message: 'Lỗi: $e');
                  }
                }
              },
              child: const Text('Xóa', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}

// ================= TAG CONFIGS TAB =================

class _OdooTagConfigsTab extends ConsumerWidget {
  const _OdooTagConfigsTab({
    required this.palette,
    required this.searchQuery,
    required this.searchController,
  });

  final AppThemePalette palette;
  final String searchQuery;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagConfigsAsync = ref.watch(odooTaskTagConfigsProvider);

    return tagConfigsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Lỗi: $e', style: TextStyle(color: palette.textSecondary)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.invalidate(odooTaskTagConfigsProvider),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
      data: (configs) {
        final filteredConfigs = configs
            .where((c) => c.tagName.toLowerCase().contains(searchQuery))
            .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  labelText: 'Tìm kiếm tag...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => searchController.clear(),
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: filteredConfigs.isEmpty
                  ? const Center(child: Text('Không tìm thấy cấu hình tag phù hợp'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filteredConfigs.length,
                      itemBuilder: (context, index) {
                        final config = filteredConfigs[index];
                        return Card(
                          color: palette.card,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: palette.surfaceVariant),
                          ),
                          child: ListTile(
                            title: Text(
                              config.tagName,
                              style: AppTypography.titleMedium.copyWith(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: const Text('Điểm gốc của tag'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${config.basePoints} Tim',
                                  style: AppTypography.bodyLarge.copyWith(
                                    color: palette.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.edit_outlined, color: palette.textSecondary, size: 20),
                              ],
                            ),
                            onTap: () => _editTagBasePoints(context, ref, config),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _editTagBasePoints(BuildContext context, WidgetRef ref, OdooTaskTagConfig config) {
    final controller = TextEditingController(text: config.basePoints.toString());
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: palette.surface,
          title: Text('Sửa điểm gốc: ${config.tagName}'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Điểm gốc (base_points)',
              hintText: 'Ví dụ: 25',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                final int? basePoints = int.tryParse(controller.text);
                if (basePoints == null || basePoints < 0) {
                  showTopSnackBar(context, message: 'Điểm gốc không hợp lệ');
                  return;
                }
                Navigator.pop(context);
                try {
                  final repo = ref.read(hrRepositoryProvider);
                  await repo.updateOdooTaskTagConfig(config.id, basePoints);
                  ref.invalidate(odooTaskTagConfigsProvider);
                  if (context.mounted) {
                    showTopSnackBar(context, message: 'Đã cập nhật thành công');
                  }
                } catch (e) {
                  if (context.mounted) {
                    showTopSnackBar(context, message: 'Lỗi: $e');
                  }
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }
}
