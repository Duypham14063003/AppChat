import 'dart:async';

import 'package:dio/dio.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nineteen_tech_app/core/theme/app_colors.dart';
import 'package:nineteen_tech_app/core/config/app_config.dart';
import 'package:nineteen_tech_app/core/theme/theme_color_presets.dart';
import 'package:nineteen_tech_app/core/utils/snackbar_utils.dart';
import 'package:nineteen_tech_app/features/auth/providers/auth_notifier.dart';
import 'package:nineteen_tech_app/features/hr/hr_role_utils.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/hr_models.dart';
import '../data/vietqr.dart';
import '../providers/hr_providers.dart';
import '../widgets/employee_payment_qr.dart';
import 'employee_working_days_detail_dialog.dart';

enum EmployeeContractFormMode { create, edit, renew }

class EmployeeDirectoryScreen extends ConsumerStatefulWidget {
  const EmployeeDirectoryScreen({super.key});

  @override
  ConsumerState<EmployeeDirectoryScreen> createState() =>
      _EmployeeDirectoryScreenState();
}

class _EmployeeDirectoryScreenState
    extends ConsumerState<EmployeeDirectoryScreen> {
  final _searchController = TextEditingController();
  final _departmentController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _employmentStatusController = TextEditingController();
  Timer? _searchDebounce;
  bool? _isActiveFilter;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _departmentController.dispose();
    _jobTitleController.dispose();
    _employmentStatusController.dispose();
    super.dispose();
  }

  HrEmployeeDirectoryQuery get _query => HrEmployeeDirectoryQuery(
    search: _searchController.text.trim().isEmpty
        ? null
        : _searchController.text.trim(),
    department: _departmentController.text.trim().isEmpty
        ? null
        : _departmentController.text.trim(),
    jobTitle: _jobTitleController.text.trim().isEmpty
        ? null
        : _jobTitleController.text.trim(),
    employmentStatus: _employmentStatusController.text.trim().isEmpty
        ? null
        : _employmentStatusController.text.trim(),
    isActive: _isActiveFilter,
  );

  void _refresh() => setState(() {});

  void _searchAsYouType(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), _refresh);
  }

  void _submitSearch() {
    _searchDebounce?.cancel();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(hrEmployeeDirectoryProvider(_query));
    final notifier = ref.read(hrEmployeeDirectoryProvider(_query).notifier);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nhân sự',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Quản lý thông tin nhân viên trong công ty',
                          style: TextStyle(
                            color: context.appPalette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.outlined(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Làm mới',
                    onPressed: notifier.refresh,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: _DirectoryFilters(
                searchController: _searchController,
                departmentController: _departmentController,
                jobTitleController: _jobTitleController,
                employmentStatusController: _employmentStatusController,
                isActiveFilter: _isActiveFilter,
                onIsActiveChanged: (value) {
                  setState(() => _isActiveFilter = value);
                },
                onChanged: _refresh,
                onSearchChanged: _searchAsYouType,
                onSearchSubmitted: _submitSearch,
              ),
            ),
            Expanded(
              child: page.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _EmployeeStateError(
                  message: '$error',
                  onRetry: notifier.refresh,
                ),
                data: (data) {
                  if (data.items.isEmpty) {
                    return _EmptyState(
                      icon: Icons.badge_outlined,
                      title: 'Không có nhân sự',
                      message: 'Thử đổi bộ lọc hoặc tìm lại.',
                      actionLabel: 'Tải lại',
                      onAction: notifier.refresh,
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                        child: Text(
                          'Tổng số: ${data.total} nhân viên',
                          style: TextStyle(
                            color: context.appPalette.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification.metrics.extentAfter < 320) {
                              notifier.loadMore();
                            }
                            return false;
                          },
                          child: RefreshIndicator(
                            onRefresh: notifier.refresh,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                              itemCount:
                                  data.items.length + (data.hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= data.items.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }

                                final employee = data.items[index];
                                return _EmployeeSummaryTile(
                                  employee: employee,
                                  onTap: () =>
                                      context.push('/employees/${employee.id}'),
                                  showTopBorder: index == 0,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmployeeDetailScreen extends ConsumerStatefulWidget {
  const EmployeeDetailScreen({
    super.key,
    required this.employeeId,
    this.isSelf = false,
  });

  final String employeeId;
  final bool isSelf;

  @override
  ConsumerState<EmployeeDetailScreen> createState() =>
      _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends ConsumerState<EmployeeDetailScreen> {
  int _selectedTab = 0;
  bool _isEditingProfile = false;

  @override
  Widget build(BuildContext context) {
    final roles =
        ref.watch(authNotifierProvider).valueOrNull?.user?.roles ?? [];
    final canManage = canManageEmployeesForRoles(roles);
    final canViewAttendance = canViewEmployeeAttendanceForRoles(roles);
    final detailAsync = widget.isSelf
        ? ref.watch(myEmployeeProfileProvider)
        : ref.watch(employeeDetailProvider(widget.employeeId));

    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Quay lại',
          onPressed: context.pop,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Làm mới',
            onPressed: () {
              if (widget.isSelf) {
                ref.invalidate(myEmployeeProfileProvider);
              } else {
                ref.invalidate(employeeDetailProvider(widget.employeeId));
              }
            },
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _EmployeeStateError(
          message: '$error',
          onRetry: () {
            if (widget.isSelf) {
              ref.invalidate(myEmployeeProfileProvider);
            } else {
              ref.invalidate(employeeDetailProvider(widget.employeeId));
            }
          },
        ),
        data: (detail) {
          final profile = detail.profile;
          final contractsAsync = ref.watch(
            employeeContractsProvider(detail.employee.id),
          );
          return RefreshIndicator(
            onRefresh: () async {
              if (widget.isSelf) {
                ref.invalidate(myEmployeeProfileProvider);
              } else {
                ref.invalidate(employeeDetailProvider(widget.employeeId));
              }
              ref.invalidate(employeeContractsProvider(detail.employee.id));
              await ref.read(
                employeeContractsProvider(detail.employee.id).future,
              );
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                _EmployeeHeader(detail: detail),
                const SizedBox(height: 18),
                _EmployeeTabs(
                  selectedIndex: _selectedTab,
                  showAttendance: canViewAttendance,
                  onSelected: (index) => setState(() {
                    _selectedTab = index;
                    if (index != 1) _isEditingProfile = false;
                  }),
                ),
                const SizedBox(height: 12),
                if (_selectedTab == 0)
                  _OverviewContent(detail: detail)
                else if (_selectedTab == 1)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _isEditingProfile
                        ? _InlineProfileEditor(
                            key: ValueKey(detail.employee.id),
                            detail: detail,
                            isSelf: widget.isSelf,
                            canManage: canManage,
                            onCancel: () =>
                                setState(() => _isEditingProfile = false),
                            onSaved: () {
                              setState(() => _isEditingProfile = false);
                              if (widget.isSelf) {
                                ref.invalidate(myEmployeeProfileProvider);
                              } else {
                                ref.invalidate(
                                  employeeDetailProvider(widget.employeeId),
                                );
                              }
                            },
                          )
                        : Column(
                            children: [
                              _ProfileSection(
                                key: const ValueKey('profile-readonly'),
                                title: 'Thông tin cá nhân',
                                columns: 2,
                                rows: [
                                  _DetailRow(
                                    label: 'Ngày sinh',
                                    value:
                                        profile?.dateOfBirth ?? 'Chưa cập nhật',
                                  ),
                                  _DetailRow(
                                    label: 'Giới tính',
                                    value: profile?.gender ?? 'Chưa cập nhật',
                                  ),
                                  _DetailRow(
                                    label: 'SĐT cá nhân',
                                    value:
                                        profile?.personalPhone ??
                                        'Chưa cập nhật',
                                  ),
                                  _DetailRow(
                                    label: 'Email cá nhân',
                                    value:
                                        profile?.personalEmail ??
                                        'Chưa cập nhật',
                                  ),
                                  _DetailRow(
                                    label: 'Địa chỉ hiện tại',
                                    value:
                                        profile?.currentAddress ??
                                        'Chưa cập nhật',
                                  ),
                                  _DetailRow(
                                    label: 'Địa chỉ thường trú',
                                    value:
                                        profile?.permanentAddress ??
                                        'Chưa cập nhật',
                                  ),
                                  _DetailRow(
                                    label: 'Liên hệ khẩn cấp',
                                    value:
                                        profile?.emergencyContactName ??
                                        'Chưa cập nhật',
                                  ),
                                  _DetailRow(
                                    label: 'Mã số thuế',
                                    value: profile?.taxCode ?? 'Chưa cập nhật',
                                  ),
                                  _DetailRow(
                                    label: 'Ngân hàng',
                                    value: profile?.bankName ?? 'Chưa cập nhật',
                                  ),
                                  _DetailRow(
                                    label: 'Số tài khoản',
                                    value:
                                        profile?.bankAccountNumber ??
                                        'Chưa cập nhật',
                                  ),
                                  _DetailRow(
                                    label: 'Ngày vào làm',
                                    value: profile?.joinedAt ?? 'Chưa cập nhật',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _EmployeePaymentProfileCard(profile: profile),
                            ],
                          ),
                  )
                else if (_selectedTab == 2)
                  _ContractsSection(
                    contractsAsync: contractsAsync,
                    canManage: canManage,
                    employeeId: detail.employee.id,
                  )
                else if (canViewAttendance)
                  _EmployeeAttendanceSection(
                    employeeId: detail.employee.id,
                    employeeName: detail.employee.name,
                  ),
                if (canManage || widget.isSelf) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // FilledButton.tonalIcon(
                      //   onPressed: () => context.push(
                      //     '/employees/${detail.employee.id}/contracts',
                      //   ),
                      //   icon: const Icon(Icons.list_alt_outlined),
                      //   label: const Text('Hợp đồng'),
                      // ),
                      if (!_isEditingProfile)
                        FilledButton.icon(
                          onPressed: () => setState(() {
                            _selectedTab = 1;
                            _isEditingProfile = true;
                          }),
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(
                            widget.isSelf ? 'Chỉnh hồ sơ' : 'Sửa hồ sơ',
                          ),
                        ),
                      // if (canManage)
                      //   FilledButton.tonalIcon(
                      //     onPressed: () => context.push(
                      //       '/employees/${detail.employee.id}/contracts/new',
                      //     ),
                      //     icon: const Icon(Icons.description_outlined),
                      //     label: const Text('Thêm hợp đồng'),
                      //   ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class EmployeeProfileEditScreen extends ConsumerStatefulWidget {
  const EmployeeProfileEditScreen({
    super.key,
    required this.employeeId,
    this.isSelf = false,
  });

  final String employeeId;
  final bool isSelf;

  @override
  ConsumerState<EmployeeProfileEditScreen> createState() =>
      _EmployeeProfileEditScreenState();
}

class _EmployeeProfileEditScreenState
    extends ConsumerState<EmployeeProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateOfBirthController = TextEditingController();
  final _genderController = TextEditingController();
  final _identityNumberController = TextEditingController();
  final _identityIssuedDateController = TextEditingController();
  final _identityIssuedPlaceController = TextEditingController();
  final _permanentAddressController = TextEditingController();
  final _currentAddressController = TextEditingController();
  final _personalPhoneController = TextEditingController();
  final _personalEmailController = TextEditingController();
  final _emergencyContactNameController = TextEditingController();
  final _emergencyContactPhoneController = TextEditingController();
  final _emergencyContactRelationshipController = TextEditingController();
  final _maritalStatusController = TextEditingController();
  final _taxCodeController = TextEditingController();
  final _bankAccountNumberController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _joinedAtController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _dateOfBirthController.dispose();
    _genderController.dispose();
    _identityNumberController.dispose();
    _identityIssuedDateController.dispose();
    _identityIssuedPlaceController.dispose();
    _permanentAddressController.dispose();
    _currentAddressController.dispose();
    _personalPhoneController.dispose();
    _personalEmailController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactPhoneController.dispose();
    _emergencyContactRelationshipController.dispose();
    _maritalStatusController.dispose();
    _taxCodeController.dispose();
    _bankAccountNumberController.dispose();
    _bankNameController.dispose();
    _joinedAtController.dispose();
    super.dispose();
  }

  void _hydrate(EmployeeProfile? profile) {
    if (_initialized || profile == null) return;
    _initialized = true;
    _dateOfBirthController.text = profile.dateOfBirth ?? '';
    _genderController.text = profile.gender ?? '';
    _identityNumberController.text = profile.identityNumber ?? '';
    _identityIssuedDateController.text = profile.identityIssuedDate ?? '';
    _identityIssuedPlaceController.text = profile.identityIssuedPlace ?? '';
    _permanentAddressController.text = profile.permanentAddress ?? '';
    _currentAddressController.text = profile.currentAddress ?? '';
    _personalPhoneController.text = profile.personalPhone ?? '';
    _personalEmailController.text = profile.personalEmail ?? '';
    _emergencyContactNameController.text = profile.emergencyContactName ?? '';
    _emergencyContactPhoneController.text = profile.emergencyContactPhone ?? '';
    _emergencyContactRelationshipController.text =
        profile.emergencyContactRelationship ?? '';
    _maritalStatusController.text = profile.maritalStatus ?? '';
    _taxCodeController.text = profile.taxCode ?? '';
    _bankAccountNumberController.text = profile.bankAccountNumber ?? '';
    _bankNameController.text = profile.bankName ?? '';
    _joinedAtController.text = profile.joinedAt ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = widget.isSelf
        ? ref.watch(myEmployeeProfileProvider)
        : ref.watch(employeeDetailProvider(widget.employeeId));
    final roles =
        ref.watch(authNotifierProvider).valueOrNull?.user?.roles ?? [];
    final canManage = canManageEmployeesForRoles(roles);
    final selfEditable = widget.isSelf && !canManage;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSelf ? 'Chỉnh hồ sơ HR' : 'Sửa hồ sơ nhân sự'),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _EmployeeStateError(message: '$error'),
        data: (detail) {
          _hydrate(detail.profile);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _ProfileField(
                  controller: _dateOfBirthController,
                  label: 'Ngày sinh',
                  readOnly: selfEditable,
                ),
                _ProfileField(
                  controller: _genderController,
                  label: 'Giới tính',
                  readOnly: selfEditable,
                ),
                _ProfileField(
                  controller: _identityNumberController,
                  label: 'Số CCCD',
                  readOnly: selfEditable,
                ),
                _ProfileField(
                  controller: _identityIssuedDateController,
                  label: 'Ngày cấp CCCD',
                  readOnly: selfEditable,
                ),
                _ProfileField(
                  controller: _identityIssuedPlaceController,
                  label: 'Nơi cấp CCCD',
                  readOnly: selfEditable,
                ),
                _ProfileField(
                  controller: _permanentAddressController,
                  label: 'Địa chỉ thường trú',
                  readOnly: selfEditable && !canManage,
                ),
                _ProfileField(
                  controller: _currentAddressController,
                  label: 'Địa chỉ hiện tại',
                ),
                _ProfileField(
                  controller: _personalPhoneController,
                  label: 'SĐT cá nhân',
                ),
                _ProfileField(
                  controller: _personalEmailController,
                  label: 'Email cá nhân',
                ),
                _ProfileField(
                  controller: _emergencyContactNameController,
                  label: 'Người liên hệ khẩn cấp',
                ),
                _ProfileField(
                  controller: _emergencyContactPhoneController,
                  label: 'SĐT liên hệ khẩn cấp',
                ),
                _ProfileField(
                  controller: _emergencyContactRelationshipController,
                  label: 'Quan hệ liên hệ khẩn cấp',
                ),
                _ProfileField(
                  controller: _maritalStatusController,
                  label: 'Tình trạng hôn nhân',
                  readOnly: selfEditable,
                ),
                _ProfileField(
                  controller: _taxCodeController,
                  label: 'Mã số thuế',
                  readOnly: selfEditable,
                ),
                _ProfileField(
                  controller: _bankAccountNumberController,
                  label: 'Số tài khoản',
                  readOnly: selfEditable,
                ),
                _ProfileField(
                  controller: _bankNameController,
                  label: 'Ngân hàng',
                  readOnly: selfEditable,
                ),
                _ProfileField(
                  controller: _joinedAtController,
                  label: 'Ngày vào làm',
                  readOnly: selfEditable,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () =>
                      _save(context, detail.employee.id, selfEditable),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Lưu thay đổi'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _save(
    BuildContext context,
    String employeeId,
    bool selfEditable,
  ) async {
    if (!_formKey.currentState!.validate()) return;

    final request = EmployeeProfileUpdateRequest(
      dateOfBirth: selfEditable ? null : _dateOfBirthController.text.trim(),
      gender: selfEditable ? null : _genderController.text.trim(),
      identityNumber: selfEditable
          ? null
          : _identityNumberController.text.trim(),
      identityIssuedDate: selfEditable
          ? null
          : _identityIssuedDateController.text.trim(),
      identityIssuedPlace: selfEditable
          ? null
          : _identityIssuedPlaceController.text.trim(),
      permanentAddress: _permanentAddressController.text.trim(),
      currentAddress: _currentAddressController.text.trim(),
      personalPhone: _personalPhoneController.text.trim(),
      personalEmail: _personalEmailController.text.trim(),
      emergencyContactName: _emergencyContactNameController.text.trim(),
      emergencyContactPhone: _emergencyContactPhoneController.text.trim(),
      emergencyContactRelationship: _emergencyContactRelationshipController.text
          .trim(),
      maritalStatus: selfEditable ? null : _maritalStatusController.text.trim(),
      taxCode: selfEditable ? null : _taxCodeController.text.trim(),
      bankAccountNumber: selfEditable
          ? null
          : _bankAccountNumberController.text.trim(),
      bankName: selfEditable ? null : _bankNameController.text.trim(),
      joinedAt: selfEditable ? null : _joinedAtController.text.trim(),
    );

    try {
      if (selfEditable) {
        await ref
            .read(employeeProfileMutationProvider.notifier)
            .updateSelf(request);
      } else {
        await ref
            .read(employeeProfileMutationProvider.notifier)
            .updateEmployee(userId: employeeId, request: request);
      }
      ref.invalidate(employeeDetailProvider(employeeId));
      ref.invalidate(employeeContractsProvider(employeeId));
      ref.invalidate(myEmployeeProfileProvider);
      if (!mounted) return;
      showTopSnackBar(context, message: 'Đã lưu hồ sơ');
      context.pop();
    } on DioException catch (error) {
      if (!mounted) return;
      showTopSnackBar(
        context,
        message:
            (error.response?.data as Map?)?['message']?.toString() ??
            'Không thể lưu hồ sơ',
        backgroundColor: AppColors.danger,
      );
    }
  }
}

class EmployeeContractsScreen extends ConsumerWidget {
  const EmployeeContractsScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  final String employeeId;
  final String employeeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles =
        ref.watch(authNotifierProvider).valueOrNull?.user?.roles ?? [];
    final canManage = canManageEmployeesForRoles(roles);
    final contractsAsync = ref.watch(employeeContractsProvider(employeeId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Hợp đồng - $employeeName'),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Tạo hợp đồng',
              onPressed: () =>
                  context.push('/employees/$employeeId/contracts/new'),
            ),
        ],
      ),
      body: contractsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _EmployeeStateError(
          message: '$error',
          onRetry: () => ref.invalidate(employeeContractsProvider(employeeId)),
        ),
        data: (contracts) {
          if (contracts.isEmpty) {
            return _EmptyState(
              icon: Icons.description_outlined,
              title: 'Chưa có hợp đồng',
              message: 'Danh sách hợp đồng sẽ xuất hiện ở đây.',
              actionLabel: canManage ? 'Tạo hợp đồng' : null,
              onAction: canManage
                  ? () => context.push('/employees/$employeeId/contracts/new')
                  : null,
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(employeeContractsProvider(employeeId));
              await ref.read(employeeContractsProvider(employeeId).future);
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: contracts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final contract = contracts[index];
                return _ContractTile(
                  contract: contract,
                  onTap: () => context.push(
                    '/employees/$employeeId/contracts/${contract.id}',
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class EmployeeContractDetailScreen extends ConsumerWidget {
  const EmployeeContractDetailScreen({
    super.key,
    required this.employeeId,
    required this.contractId,
  });

  final String employeeId;
  final String contractId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contractAsync = ref.watch(employeeContractsProvider(employeeId));
    final canManage = canManageEmployeesForRoles(
      ref.watch(authNotifierProvider).valueOrNull?.user?.roles ?? const [],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết hợp đồng')),
      body: contractAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _EmployeeStateError(message: '$error'),
        data: (contracts) {
          EmployeeContract? contract;
          for (final item in contracts) {
            if (item.id == contractId) {
              contract = item;
              break;
            }
          }
          if (contract == null) {
            return const _EmptyState(
              icon: Icons.description_outlined,
              title: 'Không tìm thấy hợp đồng',
              message: 'Hợp đồng này không còn trong danh sách hiện tại.',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _ProfileSection(
                title: 'Thông tin hợp đồng',
                rows: [
                  _DetailRow(label: 'Loại', value: contract.type),
                  _DetailRow(label: 'Trạng thái', value: contract.status),
                  _DetailRow(
                    label: 'Ngày ký',
                    value: contract.signedDate ?? 'Chưa có',
                  ),
                  _DetailRow(label: 'Ngày bắt đầu', value: contract.startDate),
                  _DetailRow(
                    label: 'Ngày kết thúc',
                    value: contract.endDate ?? 'Không xác định',
                  ),
                  _DetailRow(
                    label: 'Nội dung',
                    value: contract.notes ?? 'Không có',
                  ),
                  _DetailRow(
                    label: 'Ngày tới hạn',
                    value: contract.daysUntilExpiry?.toString() ?? 'N/A',
                  ),
                ],
              ),
              if (canManage) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => context.push(
                        '/employees/$employeeId/contracts/$contractId/edit',
                      ),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Chỉnh sửa'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => context.push(
                        '/employees/$employeeId/contracts/$contractId/renew',
                      ),
                      icon: const Icon(Icons.autorenew_outlined),
                      label: const Text('Gia hạn'),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class EmployeeContractFormScreen extends ConsumerStatefulWidget {
  const EmployeeContractFormScreen({
    super.key,
    required this.employeeId,
    this.contractId,
    required this.mode,
  });

  final String employeeId;
  final String? contractId;
  final EmployeeContractFormMode mode;

  @override
  ConsumerState<EmployeeContractFormScreen> createState() =>
      _EmployeeContractFormScreenState();
}

class _EmployeeContractFormScreenState
    extends ConsumerState<EmployeeContractFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _typeController = TextEditingController(text: 'official');
  final _signedDateController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _statusController = TextEditingController(text: 'draft');
  final _notesController = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _typeController.dispose();
    _signedDateController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _statusController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.mode) {
      EmployeeContractFormMode.create => 'Tạo hợp đồng',
      EmployeeContractFormMode.edit => 'Chỉnh sửa hợp đồng',
      EmployeeContractFormMode.renew => 'Gia hạn hợp đồng',
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: widget.contractId == null
          ? _buildForm()
          : ref
                .watch(employeeContractsProvider(widget.employeeId))
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => _EmployeeStateError(message: '$error'),
                  data: (contracts) {
                    if (!_loaded) {
                      final source = contracts.isNotEmpty
                          ? contracts.firstWhere(
                              (item) => item.id == widget.contractId,
                              orElse: () => contracts.first,
                            )
                          : EmployeeContract(
                              id: '',
                              userId: widget.employeeId,
                              type: 'official',
                              startDate: '',
                              status: 'draft',
                              createdBy: '',
                            );
                      _typeController.text = source.type;
                      _signedDateController.text = source.signedDate ?? '';
                      _startDateController.text = source.startDate;
                      _endDateController.text = source.endDate ?? '';
                      _statusController.text = source.status;
                      _notesController.text = source.notes ?? '';
                      _loaded = true;
                    }
                    return _buildForm();
                  },
                ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _ProfileField(controller: _typeController, label: 'Loại hợp đồng'),
          _ProfileField(controller: _signedDateController, label: 'Ngày ký'),
          _ProfileField(
            controller: _startDateController,
            label: 'Ngày bắt đầu',
            validator: _requiredValidator,
          ),
          _ProfileField(controller: _endDateController, label: 'Ngày kết thúc'),
          _ProfileField(controller: _statusController, label: 'Trạng thái'),
          _ProfileField(
            controller: _notesController,
            label: 'Ghi chú',
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Lưu hợp đồng'),
          ),
        ],
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Bắt buộc nhập';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final request = EmployeeContractRequest(
      userId: widget.employeeId,
      type: _typeController.text.trim(),
      signedDate: _signedDateController.text.trim().isEmpty
          ? null
          : _signedDateController.text.trim(),
      startDate: _startDateController.text.trim(),
      endDate: _endDateController.text.trim().isEmpty
          ? null
          : _endDateController.text.trim(),
      status: _statusController.text.trim().isEmpty
          ? null
          : _statusController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    try {
      final notifier = ref.read(employeeContractMutationProvider.notifier);
      if (widget.mode == EmployeeContractFormMode.create) {
        await notifier.create(request);
      } else if (widget.mode == EmployeeContractFormMode.edit) {
        await notifier.updateContract(
          contractId: widget.contractId!,
          request: request,
        );
      } else {
        await notifier.renew(contractId: widget.contractId!, request: request);
      }
      ref.invalidate(employeeContractsProvider(widget.employeeId));
      ref.invalidate(employeeDetailProvider(widget.employeeId));
      if (!mounted) return;
      showTopSnackBar(context, message: 'Đã lưu hợp đồng');
      context.pop();
    } on DioException catch (error) {
      if (!mounted) return;
      showTopSnackBar(
        context,
        message:
            (error.response?.data as Map?)?['message']?.toString() ??
            'Không thể lưu hợp đồng',
        backgroundColor: AppColors.danger,
      );
    }
  }
}

class _DirectoryFilters extends StatelessWidget {
  const _DirectoryFilters({
    required this.searchController,
    required this.departmentController,
    required this.jobTitleController,
    required this.employmentStatusController,
    required this.isActiveFilter,
    required this.onIsActiveChanged,
    required this.onChanged,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
  });

  final TextEditingController searchController;
  final TextEditingController departmentController;
  final TextEditingController jobTitleController;
  final TextEditingController employmentStatusController;
  final bool? isActiveFilter;
  final ValueChanged<bool?> onIsActiveChanged;
  final VoidCallback onChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchSubmitted;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final decoration = InputDecoration(
      filled: true,
      fillColor: palette.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: palette.surfaceVariant),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          SizedBox(
            width: constraints.maxWidth < 700 ? constraints.maxWidth : 320,
            child: TextField(
              controller: searchController,
              decoration: decoration.copyWith(
                hintText: 'Tìm kiếm nhân viên...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
              ),
              onChanged: onSearchChanged,
              onSubmitted: (_) => onSearchSubmitted(),
            ),
          ),
          // SizedBox(
          //   width: 180,
          //   child: TextField(
          //     controller: departmentController,
          //     decoration: decoration.copyWith(hintText: 'Phòng ban'),
          //     onSubmitted: (_) => onChanged(),
          //   ),
          // ),
          // SizedBox(
          //   width: 180,
          //   child: TextField(
          //     controller: jobTitleController,
          //     decoration: decoration.copyWith(hintText: 'Chức danh'),
          //     onSubmitted: (_) => onChanged(),
          //   ),
          // ),
          // SizedBox(
          //   width: 180,
          //   child: TextField(
          //     controller: employmentStatusController,
          //     decoration: decoration.copyWith(hintText: 'Employment'),
          //     onSubmitted: (_) => onChanged(),
          //   ),
          // ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<bool?>(
              isExpanded: true,
              initialValue: isActiveFilter,
              items: const [
                DropdownMenuItem(value: null, child: Text('Tất cả')),
                DropdownMenuItem(value: true, child: Text('Đang hoạt động')),
                DropdownMenuItem(value: false, child: Text('Ngừng hoạt động')),
              ],
              onChanged: onIsActiveChanged,
              decoration: decoration.copyWith(labelText: 'Trạng thái'),
            ),
          ),
          // SizedBox(
          //   height: 48,
          //   child: FilledButton.icon(
          //     onPressed: onChanged,
          //     icon: const Icon(Icons.search),
          //     label: const Text('Lọc'),
          //   ),
          // ),
        ],
      ),
    );
  }
}

class _EmployeeSummaryTile extends StatelessWidget {
  const _EmployeeSummaryTile({
    required this.employee,
    required this.onTap,
    this.showTopBorder = false,
  });

  final HrEmployeeSummary employee;
  final VoidCallback onTap;
  final bool showTopBorder;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 620;
        final employeeInfo = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              employee.name,
              maxLines: isCompact ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 3),
            Text(
              employee.jobTitle ?? 'Chưa cập nhật',
              maxLines: isCompact ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            ),
          ],
        );

        return ListTile(
          onTap: onTap,
          tileColor: palette.surface,
          minTileHeight: isCompact ? 74 : 60,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: isCompact ? 8 : 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: showTopBorder ? const Radius.circular(10) : Radius.zero,
              bottom: Radius.zero,
            ),
            side: BorderSide(
              color: palette.surfaceVariant.withValues(alpha: .8),
            ),
          ),
          leading: CircleAvatar(
            backgroundImage: employee.avatarUrl == null
                ? null
                : NetworkImage(employee.avatarUrl!),
            child: employee.avatarUrl == null
                ? Text(employee.name.isNotEmpty ? employee.name[0] : '?')
                : null,
          ),
          title: isCompact
              ? employeeInfo
              : Row(
                  children: [
                    Expanded(flex: 3, child: employeeInfo),
                    Expanded(
                      flex: 2,
                      child: Text(employee.department ?? 'Chưa cập nhật'),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        employee.email,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusBadge(isActive: employee.isActive),
              const SizedBox(width: 10),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        );
      },
    );
  }
}

class _EmployeeHeader extends StatelessWidget {
  const _EmployeeHeader({required this.detail});

  final EmployeeDetailResponse detail;

  @override
  Widget build(BuildContext context) {
    final employee = detail.employee;
    final palette = context.appPalette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 54,
          backgroundColor: palette.primaryPale,
          backgroundImage: employee.avatarUrl == null
              ? null
              : NetworkImage(employee.avatarUrl!),
          child: employee.avatarUrl == null
              ? Text(
                  employee.name.isEmpty ? '?' : employee.name[0],
                  style: const TextStyle(fontSize: 30),
                )
              : null,
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    employee.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  _StatusBadge(isActive: employee.isActive),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                employee.jobTitle ?? 'Chưa cập nhật',
                style: TextStyle(
                  color: palette.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                employee.department ?? 'Chưa cập nhật',
                style: TextStyle(color: palette.textSecondary),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  _MetaItem(
                    icon: Icons.mail_outline_rounded,
                    text: employee.email,
                  ),
                  _MetaItem(
                    icon: Icons.calendar_today_outlined,
                    text:
                        'Ngày vào làm: ${detail.profile?.joinedAt ?? "Chưa cập nhật"}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContractsSection extends ConsumerStatefulWidget {
  const _ContractsSection({
    required this.contractsAsync,
    required this.canManage,
    required this.employeeId,
  });

  final AsyncValue<List<EmployeeContract>> contractsAsync;
  final bool canManage;
  final String employeeId;

  @override
  ConsumerState<_ContractsSection> createState() => _ContractsSectionState();
}

class _ContractsSectionState extends ConsumerState<_ContractsSection> {
  EmployeeContract? _editing;
  bool _creating = false;
  String? _deletingContractId;

  @override
  Widget build(BuildContext context) {
    return widget.contractsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => _EmployeeStateError(message: '$error'),
      data: (contracts) {
        if (_creating || _editing != null) {
          return _InlineContractEditor(
            employeeId: widget.employeeId,
            contract: _editing,
            onCancel: () => setState(() {
              _creating = false;
              _editing = null;
            }),
            onSaved: () {
              setState(() {
                _creating = false;
                _editing = null;
              });
              ref.invalidate(employeeContractsProvider(widget.employeeId));
            },
          );
        }
        final palette = context.appPalette;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.surfaceVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Danh sách hợp đồng',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (widget.canManage)
                    FilledButton.icon(
                      onPressed: () => setState(() => _creating = true),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Thêm hợp đồng'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (contracts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: Text('Chưa có hợp đồng nào')),
                )
              else
                ...contracts.map(
                  (contract) => _ContractRow(
                    contract: contract,
                    canManage: widget.canManage,
                    isDeleting: _deletingContractId == contract.id,
                    onEdit: () => setState(() => _editing = contract),
                    onDelete: () => _deleteContract(contract),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteContract(EmployeeContract contract) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa hợp đồng?'),
        content: Text(
          'Hợp đồng ${contract.type} từ ${contract.startDate} sẽ bị xóa vĩnh viễn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingContractId = contract.id);
    try {
      await ref
          .read(employeeContractMutationProvider.notifier)
          .deleteContract(contract.id);
      if (!mounted) return;
      ref.invalidate(employeeContractsProvider(widget.employeeId));
      showTopSnackBar(context, message: 'Đã xóa hợp đồng');
    } on DioException catch (error) {
      if (!mounted) return;
      showTopSnackBar(
        context,
        message:
            (error.response?.data as Map?)?['message']?.toString() ??
            'Không thể xóa hợp đồng',
        backgroundColor: AppColors.danger,
      );
    } finally {
      if (mounted) setState(() => _deletingContractId = null);
    }
  }
}

class _ContractRow extends StatelessWidget {
  const _ContractRow({
    required this.contract,
    required this.canManage,
    required this.isDeleting,
    required this.onEdit,
    required this.onDelete,
  });

  final EmployeeContract contract;
  final bool canManage;
  final bool isDeleting;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String? get _attachmentUrl {
    final value = contract.attachmentUrl;
    if (value == null || value.isEmpty) return null;
    return value.startsWith('http')
        ? value
        : '${AppConfig.instance.apiUrl}$value';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: palette.card.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.surfaceVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: palette.primary.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.description_outlined, color: palette.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contract.type,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  '${contract.startDate} — ${contract.endDate ?? "Không thời hạn"}',
                  style: TextStyle(color: palette.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          _StatusBadge(isActive: contract.status == 'active'),
          const SizedBox(width: 14),
          if (_attachmentUrl != null) ...[
            IconButton(
              tooltip: 'Xem trước',
              onPressed: () => launchUrl(
                Uri.parse(_attachmentUrl!),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.visibility_outlined),
            ),
            IconButton(
              tooltip: 'Tải xuống',
              onPressed: () => launchUrl(
                Uri.parse(_attachmentUrl!),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.download_outlined),
            ),
          ],
          if (canManage)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Chỉnh sửa',
                  onPressed: isDeleting ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Xóa',
                  onPressed: isDeleting ? null : onDelete,
                  color: AppColors.danger,
                  icon: isDeleting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _InlineContractEditor extends ConsumerStatefulWidget {
  const _InlineContractEditor({
    required this.employeeId,
    required this.contract,
    required this.onCancel,
    required this.onSaved,
  });

  final String employeeId;
  final EmployeeContract? contract;
  final VoidCallback onCancel;
  final VoidCallback onSaved;

  @override
  ConsumerState<_InlineContractEditor> createState() =>
      _InlineContractEditorState();
}

class _InlineContractEditorState extends ConsumerState<_InlineContractEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _type;
  late final TextEditingController _signedDate;
  late final TextEditingController _startDate;
  late final TextEditingController _endDate;
  late final TextEditingController _status;
  late final TextEditingController _notes;
  XFile? _pendingFile;
  bool _dragging = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final contract = widget.contract;
    _type = TextEditingController(text: contract?.type ?? 'official');
    _signedDate = TextEditingController(text: contract?.signedDate ?? '');
    _startDate = TextEditingController(text: contract?.startDate ?? '');
    _endDate = TextEditingController(text: contract?.endDate ?? '');
    _status = TextEditingController(text: contract?.status ?? 'draft');
    _notes = TextEditingController(text: contract?.notes ?? '');
  }

  @override
  void dispose() {
    _type.dispose();
    _signedDate.dispose();
    _startDate.dispose();
    _endDate.dispose();
    _status.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.surfaceVariant),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.contract == null
                        ? 'Thêm hợp đồng'
                        : 'Chỉnh sửa hợp đồng',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _saving ? null : widget.onCancel,
                  child: const Text('Hủy'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_saving ? 'Đang lưu...' : 'Lưu hợp đồng'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final fieldWidth = constraints.maxWidth < 760
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 16) / 2;
                return Wrap(
                  spacing: 16,
                  runSpacing: 14,
                  children:
                      [
                            _InlineDropdownField(
                              controller: _type,
                              label: 'Loại hợp đồng',
                              options: const {
                                'internship': 'Thực tập',
                                'probation': 'Thử việc',
                                'official': 'Chính thức',
                                'temporary': 'Thời vụ',
                              },
                            ),
                            _InlineDropdownField(
                              controller: _status,
                              label: 'Trạng thái',
                              options: const {
                                'draft': 'Bản nháp',
                                'active': 'Đang hiệu lực',
                                'expired': 'Hết hạn',
                                'terminated': 'Đã chấm dứt',
                              },
                            ),
                            _InlineDateField(
                              controller: _signedDate,
                              label: 'Ngày ký',
                            ),
                            _InlineDateField(
                              controller: _startDate,
                              label: 'Ngày bắt đầu',
                            ),
                            _InlineDateField(
                              controller: _endDate,
                              label: 'Ngày kết thúc',
                            ),
                            _InlineField(
                              controller: _notes,
                              label: 'Ghi chú',
                              maxLines: 3,
                            ),
                          ]
                          .map(
                            (field) =>
                                SizedBox(width: fieldWidth, child: field),
                          )
                          .toList(),
                );
              },
            ),
            const SizedBox(height: 18),
            Text(
              'File hợp đồng',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DropTarget(
              onDragEntered: (_) => setState(() => _dragging = true),
              onDragExited: (_) => setState(() => _dragging = false),
              onDragDone: (detail) {
                if (detail.files.isNotEmpty) {
                  setState(() {
                    _pendingFile = detail.files.first;
                    _dragging = false;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: _dragging
                      ? palette.primary.withValues(alpha: .10)
                      : palette.card.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _dragging ? palette.primary : palette.surfaceVariant,
                    width: _dragging ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 32,
                      color: palette.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _pendingFile?.name ??
                          widget.contract?.attachmentName ??
                          'Kéo thả file vào đây',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PDF, DOC, DOCX hoặc ảnh',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickFile,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Chọn file'),
                        ),
                        if (widget.contract?.hasAttachment == true)
                          OutlinedButton.icon(
                            onPressed: _previewExisting,
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('Xem trước'),
                          ),
                        if (widget.contract?.hasAttachment == true)
                          OutlinedButton.icon(
                            onPressed: _previewExisting,
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Tải xuống'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
      type: FileType.custom,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.single;
    setState(() {
      _pendingFile = file.path != null
          ? XFile(file.path!, name: file.name)
          : XFile.fromData(file.bytes!, name: file.name);
    });
  }

  Future<void> _previewExisting() async {
    final value = widget.contract?.attachmentUrl;
    if (value == null || value.isEmpty) return;
    final url = value.startsWith('http')
        ? value
        : '${AppConfig.instance.apiUrl}$value';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _save() async {
    final start = DateTime.tryParse(_startDate.text.trim());
    final end = DateTime.tryParse(_endDate.text.trim());
    if (start == null) {
      showTopSnackBar(
        context,
        message: 'Vui lòng chọn ngày bắt đầu',
        backgroundColor: AppColors.danger,
      );
      return;
    }
    if (end != null && end.isBefore(start)) {
      showTopSnackBar(
        context,
        message: 'Ngày kết thúc phải sau ngày bắt đầu',
        backgroundColor: AppColors.danger,
      );
      return;
    }
    setState(() => _saving = true);
    final request = EmployeeContractRequest(
      userId: widget.employeeId,
      type: _type.text.trim(),
      signedDate: _signedDate.text.trim().isEmpty
          ? null
          : _signedDate.text.trim(),
      startDate: _startDate.text.trim(),
      endDate: _endDate.text.trim().isEmpty ? null : _endDate.text.trim(),
      status: _status.text.trim().isEmpty ? null : _status.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    try {
      final notifier = ref.read(employeeContractMutationProvider.notifier);
      final saved = widget.contract == null
          ? await notifier.create(request)
          : await notifier.updateContract(
              contractId: widget.contract!.id,
              request: request,
            );
      if (_pendingFile != null) {
        await notifier.uploadAttachment(
          contractId: saved.id,
          file: _pendingFile!,
        );
      }
      if (!mounted) return;
      showTopSnackBar(context, message: 'Đã lưu hợp đồng');
      widget.onSaved();
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showTopSnackBar(
        context,
        message:
            (error.response?.data as Map?)?['message']?.toString() ??
            'Không thể lưu hợp đồng',
        backgroundColor: AppColors.danger,
      );
    }
  }
}

class _EmployeeTabs extends StatelessWidget {
  const _EmployeeTabs({
    required this.selectedIndex,
    required this.onSelected,
    required this.showAttendance,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool showAttendance;

  @override
  Widget build(BuildContext context) {
    final labels = [
      'Tổng quan',
      'Hồ sơ HR',
      'Hợp đồng',
      if (showAttendance) 'Chấm công',
    ];
    final palette = context.appPalette;
    return Row(
      children: List.generate(
        labels.length,
        (index) => Expanded(
          child: InkWell(
            onTap: () => onSelected(index),
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: index == selectedIndex
                        ? palette.primary
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                labels[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: index == selectedIndex
                      ? palette.primary
                      : palette.textSecondary,
                  fontWeight: index == selectedIndex
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewContent extends StatelessWidget {
  const _OverviewContent({required this.detail});

  final EmployeeDetailResponse detail;

  @override
  Widget build(BuildContext context) {
    final employee = detail.employee;
    final profile = detail.profile;
    final basic = _ProfileSection(
      title: 'Thông tin cơ bản',
      rows: [
        _DetailRow(label: 'Email', value: employee.email),
        _DetailRow(
          label: 'Phòng ban',
          value: employee.department ?? 'Chưa cập nhật',
        ),
        _DetailRow(
          label: 'Chức danh',
          value: employee.jobTitle ?? 'Chưa cập nhật',
        ),
        _DetailRow(
          label: 'Employment',
          value: employee.employmentStatus ?? 'Chưa cập nhật',
        ),
        _DetailRow(
          label: 'Trạng thái',
          value: employee.isActive ? 'Active' : 'Inactive',
        ),
        _DetailRow(
          label: 'Ngày vào làm',
          value: profile?.joinedAt ?? 'Chưa cập nhật',
        ),
      ],
    );
    final contact = _ProfileSection(
      title: 'Thông tin liên hệ',
      rows: [
        _DetailRow(
          label: 'SĐT cá nhân',
          value: profile?.personalPhone ?? 'Chưa cập nhật',
        ),
        _DetailRow(
          label: 'Email cá nhân',
          value: profile?.personalEmail ?? 'Chưa cập nhật',
        ),
        _DetailRow(
          label: 'Địa chỉ hiện tại',
          value: profile?.currentAddress ?? 'Chưa cập nhật',
        ),
        _DetailRow(
          label: 'Địa chỉ thường trú',
          value: profile?.permanentAddress ?? 'Chưa cập nhật',
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(children: [basic, const SizedBox(height: 12), contact]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: basic),
            const SizedBox(width: 16),
            Expanded(child: contact),
          ],
        );
      },
    );
  }
}

class _EmployeeAttendanceSection extends ConsumerStatefulWidget {
  const _EmployeeAttendanceSection({
    required this.employeeId,
    required this.employeeName,
  });

  final String employeeId;
  final String employeeName;

  @override
  ConsumerState<_EmployeeAttendanceSection> createState() =>
      _EmployeeAttendanceSectionState();
}

class _EmployeePaymentProfileCard extends ConsumerWidget {
  const _EmployeePaymentProfileCard({required this.profile});

  final EmployeeProfile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appPalette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.surfaceVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thông tin thanh toán',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              _DetailRow(
                label: 'Ngân hàng',
                value: profile?.bankName ?? 'Chưa cập nhật',
              ),
              _DetailRow(
                label: 'Số tài khoản',
                value: profile?.bankAccountNumber ?? 'Chưa cập nhật',
              ),
              _DetailRow(
                label: 'Chủ tài khoản',
                value: profile?.bankAccountName ?? 'Chưa cập nhật',
              ),
            ],
          );
          final preview = EmployeePaymentQr(
            bankCode: profile?.bankCode,
            accountNumber: profile?.bankAccountNumber,
            uploadedImageUrl: profile?.bankQrImageUrl,
            source: profile?.bankQrSource,
            compact: true,
          );
          if (constraints.maxWidth < 720) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                details,
                const SizedBox(height: 16),
                Center(child: preview),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: details),
              const SizedBox(width: 24),
              SizedBox(width: 240, child: preview),
            ],
          );
        },
      ),
    );
  }
}

class _EmployeeAttendanceSectionState
    extends ConsumerState<_EmployeeAttendanceSection> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final payrollStartDay =
        ref.read(authNotifierProvider).valueOrNull?.payrollStartConfig ?? 1;
    _month = resolveCurrentPayrollMonth(
      payrollStartDay,
      now: ref.read(employeeAttendanceCurrentDateProvider),
    );
  }

  String get _monthKey =>
      '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  EmployeePayrollSummaryQuery get _query =>
      EmployeePayrollSummaryQuery(month: _monthKey, userId: widget.employeeId);

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final summaryAsync = ref.watch(employeePayrollSummaryProvider(_query));
    return Container(
      height: MediaQuery.sizeOf(context).height.clamp(560, 820).toDouble(),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.surfaceVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Tháng trước',
                  onPressed: () => setState(() {
                    _month = DateTime(_month.year, _month.month - 1);
                  }),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    'Chấm công tháng ${_month.month}/${_month.year}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Tháng sau',
                  onPressed: () => setState(() {
                    _month = DateTime(_month.year, _month.month + 1);
                  }),
                  icon: const Icon(Icons.chevron_right),
                ),
                IconButton(
                  key: const ValueKey('employee-attendance-refresh'),
                  tooltip: 'Làm mới',
                  onPressed: () =>
                      ref.invalidate(employeePayrollSummaryProvider(_query)),
                  icon: const Icon(Icons.refresh_outlined),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.surfaceVariant),
          Expanded(
            child: summaryAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _EmployeeStateError(
                message: '$error',
                onRetry: () =>
                    ref.invalidate(employeePayrollSummaryProvider(_query)),
              ),
              data: (summary) {
                if (summary.attendanceStatus == AttendanceDataStatus.unmapped) {
                  return const _AttendanceUnavailable(
                    icon: Icons.link_off_rounded,
                    title: 'Chưa liên kết nhân sự Odoo',
                    message:
                        'Không thể quy đổi trạng thái này thành 0 ngày công.',
                  );
                }
                if (summary.attendanceStatus ==
                    AttendanceDataStatus.unavailable) {
                  return _AttendanceUnavailable(
                    icon: Icons.cloud_off_outlined,
                    title: 'Chưa tải được dữ liệu chấm công',
                    message: 'Nguồn chấm công đang không khả dụng.',
                    onRetry: () =>
                        ref.invalidate(employeePayrollSummaryProvider(_query)),
                  );
                }
                return EmployeeWorkingDaysDetailView(
                  summary: summary,
                  employeeName: widget.employeeName,
                  embedded: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceUnavailable extends StatelessWidget {
  const _AttendanceUnavailable({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: context.appPalette.textSecondary),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Thử lại'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? const Color(0xFF239B5B)
        : context.appPalette.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 17, color: context.appPalette.textSecondary),
      const SizedBox(width: 7),
      Flexible(
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: context.appPalette.textSecondary),
        ),
      ),
    ],
  );
}

class _InlineProfileEditor extends ConsumerStatefulWidget {
  const _InlineProfileEditor({
    super.key,
    required this.detail,
    required this.isSelf,
    required this.canManage,
    required this.onCancel,
    required this.onSaved,
  });

  final EmployeeDetailResponse detail;
  final bool isSelf;
  final bool canManage;
  final VoidCallback onCancel;
  final VoidCallback onSaved;

  @override
  ConsumerState<_InlineProfileEditor> createState() =>
      _InlineProfileEditorState();
}

class _InlineProfileEditorState extends ConsumerState<_InlineProfileEditor> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  bool _saving = false;
  bool _uploadingQr = false;
  XFile? _failedQrUpload;
  String? _qrOperationError;
  late String? _qrSource;
  late String? _qrImageUrl;

  @override
  void initState() {
    super.initState();
    final p = widget.detail.profile;
    _controllers = {
      'dateOfBirth': TextEditingController(text: p?.dateOfBirth ?? ''),
      'gender': TextEditingController(text: p?.gender ?? ''),
      'identityNumber': TextEditingController(text: p?.identityNumber ?? ''),
      'identityIssuedDate': TextEditingController(
        text: p?.identityIssuedDate ?? '',
      ),
      'identityIssuedPlace': TextEditingController(
        text: p?.identityIssuedPlace ?? '',
      ),
      'permanentAddress': TextEditingController(
        text: p?.permanentAddress ?? '',
      ),
      'currentAddress': TextEditingController(text: p?.currentAddress ?? ''),
      'personalPhone': TextEditingController(text: p?.personalPhone ?? ''),
      'personalEmail': TextEditingController(text: p?.personalEmail ?? ''),
      'emergencyContactName': TextEditingController(
        text: p?.emergencyContactName ?? '',
      ),
      'emergencyContactPhone': TextEditingController(
        text: p?.emergencyContactPhone ?? '',
      ),
      'emergencyContactRelationship': TextEditingController(
        text: p?.emergencyContactRelationship ?? '',
      ),
      'maritalStatus': TextEditingController(text: p?.maritalStatus ?? ''),
      'taxCode': TextEditingController(text: p?.taxCode ?? ''),
      'bankName': TextEditingController(text: p?.bankName ?? ''),
      'bankCode': TextEditingController(text: p?.bankCode ?? ''),
      'bankAccountName': TextEditingController(text: p?.bankAccountName ?? ''),
      'bankAccountNumber': TextEditingController(
        text: p?.bankAccountNumber ?? '',
      ),
      'joinedAt': TextEditingController(text: p?.joinedAt ?? ''),
    };
    _qrSource = p?.bankQrSource;
    _qrImageUrl = p?.bankQrImageUrl;
    _controllers['bankCode']!.addListener(_refreshPaymentPreview);
    _controllers['bankAccountNumber']!.addListener(_refreshPaymentPreview);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _value(String key) => _controllers[key]!.text.trim();

  void _refreshPaymentPreview() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final selfLimited = widget.isSelf && !widget.canManage;
    final fields = <Widget>[
      _InlineDateField(
        controller: _controllers['dateOfBirth']!,
        label: 'Ngày sinh',
        readOnly: selfLimited,
      ),
      _InlineDropdownField(
        controller: _controllers['gender']!,
        label: 'Giới tính',
        options: const {'male': 'Nam', 'female': 'Nữ', 'other': 'Khác'},
        readOnly: selfLimited,
      ),
      _InlineField(
        controller: _controllers['identityNumber']!,
        label: 'Số CCCD',
        readOnly: selfLimited,
      ),
      _InlineDateField(
        controller: _controllers['identityIssuedDate']!,
        label: 'Ngày cấp CCCD',
        readOnly: selfLimited,
      ),
      _InlineField(
        controller: _controllers['identityIssuedPlace']!,
        label: 'Nơi cấp CCCD',
        readOnly: selfLimited,
      ),
      _InlineField(
        controller: _controllers['personalPhone']!,
        label: 'SĐT cá nhân',
        keyboardType: TextInputType.phone,
      ),
      _InlineField(
        controller: _controllers['personalEmail']!,
        label: 'Email cá nhân',
        keyboardType: TextInputType.emailAddress,
      ),
      _InlineField(
        controller: _controllers['currentAddress']!,
        label: 'Địa chỉ hiện tại',
      ),
      _InlineField(
        controller: _controllers['permanentAddress']!,
        label: 'Địa chỉ thường trú',
        readOnly: selfLimited,
      ),
      _InlineField(
        controller: _controllers['emergencyContactName']!,
        label: 'Người liên hệ khẩn cấp',
      ),
      _InlineField(
        controller: _controllers['emergencyContactPhone']!,
        label: 'SĐT liên hệ khẩn cấp',
        keyboardType: TextInputType.phone,
      ),
      _InlineField(
        controller: _controllers['emergencyContactRelationship']!,
        label: 'Quan hệ liên hệ khẩn cấp',
      ),
      _InlineDropdownField(
        controller: _controllers['maritalStatus']!,
        label: 'Tình trạng hôn nhân',
        options: const {
          'single': 'Độc thân',
          'married': 'Đã kết hôn',
          'other': 'Khác',
        },
        readOnly: selfLimited,
      ),
      _InlineField(
        controller: _controllers['taxCode']!,
        label: 'Mã số thuế',
        readOnly: selfLimited,
      ),
      _InlineDateField(
        controller: _controllers['joinedAt']!,
        label: 'Ngày vào làm',
        readOnly: selfLimited,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.surfaceVariant),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 240,
                  child: Text(
                    'Chỉnh sửa thông tin cá nhân',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _saving ? null : widget.onCancel,
                  child: const Text('Hủy'),
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_saving ? 'Đang lưu...' : 'Lưu thay đổi'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth < 760
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 16) / 2;
                return Wrap(
                  spacing: 16,
                  runSpacing: 14,
                  children: fields
                      .map((field) => SizedBox(width: width, child: field))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 22),
            _buildPaymentSection(),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final selfLimited = widget.isSelf && !widget.canManage;
    final selectedBank = VietQrBanks.byCode(_value('bankCode'));
    var nextSource = _qrSource;
    if (nextSource != 'uploaded' &&
        selectedBank != null &&
        _value('bankAccountNumber').isNotEmpty) {
      nextSource = 'generated';
    }
    final original = widget.detail.profile;
    final paymentChanged =
        original?.bankCode != _value('bankCode') ||
        original?.bankAccountNumber != _value('bankAccountNumber');
    if (_qrSource == 'uploaded' && paymentChanged) {
      final keepUploaded = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ảnh QR có thể không còn khớp'),
          content: const Text(
            'Bạn đã đổi ngân hàng hoặc số tài khoản. Giữ ảnh QR đã tải lên, hay chuyển sang VietQR tự động?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Giữ ảnh đã tải'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Dùng VietQR tự động'),
            ),
          ],
        ),
      );
      if (keepUploaded == null) return;
      nextSource = keepUploaded ? 'uploaded' : 'generated';
      setState(() => _qrSource = nextSource);
    }
    final request = EmployeeProfileUpdateRequest(
      dateOfBirth: selfLimited ? null : _value('dateOfBirth'),
      gender: selfLimited ? null : _value('gender'),
      identityNumber: selfLimited ? null : _value('identityNumber'),
      identityIssuedDate: selfLimited ? null : _value('identityIssuedDate'),
      identityIssuedPlace: selfLimited ? null : _value('identityIssuedPlace'),
      permanentAddress: _value('permanentAddress'),
      currentAddress: _value('currentAddress'),
      personalPhone: _value('personalPhone'),
      personalEmail: _value('personalEmail'),
      emergencyContactName: _value('emergencyContactName'),
      emergencyContactPhone: _value('emergencyContactPhone'),
      emergencyContactRelationship: _value('emergencyContactRelationship'),
      maritalStatus: selfLimited ? null : _value('maritalStatus'),
      taxCode: selfLimited ? null : _value('taxCode'),
      bankAccountNumber: _value('bankAccountNumber'),
      bankName: selectedBank?.name ?? _value('bankName'),
      bankCode: selectedBank?.code,
      bankAccountName: _value('bankAccountName'),
      bankQrSource: nextSource,
      joinedAt: selfLimited ? null : _value('joinedAt'),
    );
    setState(() => _saving = true);
    try {
      final notifier = ref.read(employeeProfileMutationProvider.notifier);
      if (selfLimited) {
        await notifier.updateSelf(request);
      } else {
        await notifier.updateEmployee(
          userId: widget.detail.employee.id,
          request: request,
        );
      }
      if (!mounted) return;
      showTopSnackBar(context, message: 'Đã lưu hồ sơ');
      widget.onSaved();
    } on DioException catch (error) {
      if (!mounted) return;
      showTopSnackBar(
        context,
        message:
            (error.response?.data as Map?)?['message']?.toString() ??
            'Không thể lưu hồ sơ',
        backgroundColor: AppColors.danger,
      );
      setState(() => _saving = false);
    }
  }

  Widget _buildPaymentSection() {
    final palette = context.appPalette;
    final bankCode = _value('bankCode');
    final selected = VietQrBanks.byCode(bankCode);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.card.withValues(alpha: .32),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thông tin thanh toán',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final form = Column(
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey('bank-$bankCode'),
                    initialValue: selected?.code,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Ngân hàng'),
                    items: VietQrBanks.values
                        .map(
                          (bank) => DropdownMenuItem(
                            value: bank.code,
                            child: Text('${bank.name} • ${bank.bin}'),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      final bank = VietQrBanks.byCode(value);
                      _controllers['bankCode']!.text = bank?.code ?? '';
                      _controllers['bankName']!.text = bank?.name ?? '';
                    },
                  ),
                  const SizedBox(height: 12),
                  _InlineField(
                    controller: _controllers['bankAccountNumber']!,
                    label: 'Số tài khoản',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  _InlineField(
                    controller: _controllers['bankAccountName']!,
                    label: 'Tên chủ tài khoản',
                  ),
                ],
              );
              final preview = EmployeePaymentQr(
                bankCode: bankCode,
                accountNumber: _value('bankAccountNumber'),
                uploadedImageUrl: _qrImageUrl,
                source: _qrSource,
                compact: true,
              );
              if (constraints.maxWidth < 720) {
                return Column(
                  children: [form, const SizedBox(height: 16), preview],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: form),
                  const SizedBox(width: 20),
                  SizedBox(width: 240, child: preview),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _uploadingQr ? null : _pickAndUploadQr,
                icon: _uploadingQr
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_outlined),
                label: Text(
                  _qrImageUrl == null ? 'Tải ảnh QR lên' : 'Thay ảnh QR',
                ),
              ),
              if (_qrImageUrl != null)
                OutlinedButton.icon(
                  onPressed: _uploadingQr ? null : _removeQr,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Xóa ảnh QR'),
                ),
              if (_qrImageUrl != null &&
                  selected != null &&
                  _value('bankAccountNumber').isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => setState(() => _qrSource = 'generated'),
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Dùng VietQR tự động'),
                ),
              if (_qrImageUrl != null && _qrSource != 'uploaded')
                OutlinedButton.icon(
                  onPressed: () => setState(() => _qrSource = 'uploaded'),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Dùng ảnh đã tải'),
                ),
            ],
          ),
          if (_qrOperationError != null) ...[
            const SizedBox(height: 12),
            Container(
              key: const ValueKey('payment-qr-operation-error'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: .35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_qrOperationError!)),
                  if (_failedQrUpload != null)
                    TextButton(
                      onPressed: _uploadingQr
                          ? null
                          : () => _uploadQr(_failedQrUpload!),
                      child: const Text('Thử lại'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickAndUploadQr() async {
    final file = await ref.read(employeePaymentQrImagePickerProvider)();
    if (file == null || !mounted) return;
    await _uploadQr(file);
  }

  Future<void> _uploadQr(XFile file) async {
    setState(() => _uploadingQr = true);
    try {
      final profile = await ref
          .read(employeeProfileMutationProvider.notifier)
          .uploadPaymentQr(
            userId: widget.isSelf ? null : widget.detail.employee.id,
            file: file,
          );
      if (!mounted) return;
      setState(() {
        _qrImageUrl = profile.bankQrImageUrl;
        _qrSource = 'uploaded';
        _failedQrUpload = null;
        _qrOperationError = null;
      });
      showTopSnackBar(context, message: 'Đã tải ảnh QR');
    } catch (error) {
      if (!mounted) return;
      final message = _paymentQrErrorMessage(error, 'Không thể tải ảnh QR');
      setState(() {
        _failedQrUpload = file;
        _qrOperationError = message;
      });
      showTopSnackBar(
        context,
        message: message,
        backgroundColor: AppColors.danger,
      );
    } finally {
      if (mounted) setState(() => _uploadingQr = false);
    }
  }

  Future<void> _removeQr() async {
    setState(() {
      _uploadingQr = true;
      _qrOperationError = null;
    });
    try {
      final profile = await ref
          .read(employeeProfileMutationProvider.notifier)
          .deletePaymentQr(
            userId: widget.isSelf ? null : widget.detail.employee.id,
          );
      if (!mounted) return;
      setState(() {
        _qrImageUrl = null;
        _qrSource = profile.bankQrSource;
        _failedQrUpload = null;
        _qrOperationError = null;
      });
      showTopSnackBar(context, message: 'Đã xóa ảnh QR');
    } catch (error) {
      if (!mounted) return;
      final message = _paymentQrErrorMessage(error, 'Không thể xóa ảnh QR');
      setState(() => _qrOperationError = message);
      showTopSnackBar(
        context,
        message: message,
        backgroundColor: AppColors.danger,
      );
    } finally {
      if (mounted) setState(() => _uploadingQr = false);
    }
  }
}

String _paymentQrErrorMessage(Object error, String fallback) {
  if (error is ArgumentError) return error.message?.toString() ?? fallback;
  if (error is DioException) {
    return (error.response?.data as Map?)?['message']?.toString() ?? fallback;
  }
  return fallback;
}

class _InlineField extends StatelessWidget {
  const _InlineField({
    required this.controller,
    required this.label,
    this.readOnly = false,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final bool readOnly;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: readOnly
            ? palette.card.withValues(alpha: .55)
            : palette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: palette.surfaceVariant),
        ),
      ),
    );
  }
}

class _InlineDateField extends StatelessWidget {
  const _InlineDateField({
    required this.controller,
    required this.label,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String label;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: readOnly ? null : () => _pickDate(context),
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Chọn ngày',
        suffixIcon: Icon(
          Icons.calendar_month_outlined,
          color: readOnly ? palette.textHint : palette.primary,
        ),
        filled: true,
        fillColor: readOnly
            ? palette.card.withValues(alpha: .55)
            : palette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: palette.surfaceVariant),
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final parsed = DateTime.tryParse(controller.text.trim());
    final selected = await showDatePicker(
      context: context,
      initialDate: parsed ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
      helpText: label,
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (selected == null) return;
    controller.text =
        '${selected.year.toString().padLeft(4, '0')}-'
        '${selected.month.toString().padLeft(2, '0')}-'
        '${selected.day.toString().padLeft(2, '0')}';
  }
}

class _InlineDropdownField extends StatelessWidget {
  const _InlineDropdownField({
    required this.controller,
    required this.label,
    required this.options,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String label;
  final Map<String, String> options;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final current = options.containsKey(controller.text.trim())
        ? controller.text.trim()
        : null;
    return DropdownButtonFormField<String>(
      initialValue: current,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Chọn $label',
        filled: true,
        fillColor: readOnly
            ? palette.card.withValues(alpha: .55)
            : palette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: palette.surfaceVariant),
        ),
      ),
      items: options.entries
          .map(
            (entry) => DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            ),
          )
          .toList(),
      onChanged: readOnly
          ? null
          : (value) {
              if (value != null) controller.text = value;
            },
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    super.key,
    required this.title,
    required this.rows,
    this.columns = 1,
  });

  final String title;
  final List<_DetailRow> rows;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.surfaceVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const Text('Không có dữ liệu')
          else if (columns == 1)
            ...rows.expand((row) => [row, const SizedBox(height: 10)]).toList()
              ..removeLast()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 640) {
                  return Column(
                    children:
                        rows
                            .expand((row) => [row, const SizedBox(height: 12)])
                            .toList()
                          ..removeLast(),
                  );
                }
                return Wrap(
                  spacing: 20,
                  runSpacing: 12,
                  children: rows
                      .map(
                        (row) => SizedBox(
                          width: (constraints.maxWidth - 20) / 2,
                          child: row,
                        ),
                      )
                      .toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: palette.textSecondary)),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: Text(
                label,
                style: TextStyle(color: palette.textSecondary),
              ),
            ),
            Expanded(
              child: Text(value, style: TextStyle(color: palette.textPrimary)),
            ),
          ],
        );
      },
    );
  }
}

class _ContractTile extends StatelessWidget {
  const _ContractTile({required this.contract, required this.onTap});

  final EmployeeContract contract;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return ListTile(
      onTap: onTap,
      tileColor: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.surfaceVariant),
      ),
      title: Text('${contract.type} • ${contract.status}'),
      subtitle: Text(
        'Bắt đầu ${contract.startDate} • Hết hạn ${contract.endDate ?? "không xác định"}',
      ),
      trailing: Text(contract.daysUntilExpiry?.toString() ?? ''),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.controller,
    required this.label,
    this.readOnly = false,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool readOnly;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          helperText: readOnly ? 'Chỉ xem' : null,
        ),
      ),
    );
  }
}

class _EmployeeStateError extends StatelessWidget {
  const _EmployeeStateError({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
