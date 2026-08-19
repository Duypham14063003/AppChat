import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/core/theme/app_theme.dart';
import 'package:nineteen_tech_app/core/theme/theme_color_presets.dart';
import 'package:nineteen_tech_app/features/hr/data/hr_models.dart';
import 'package:nineteen_tech_app/features/hr/data/hr_repository.dart';
import 'package:nineteen_tech_app/features/hr/providers/hr_providers.dart';
import 'package:nineteen_tech_app/features/hr/screens/employee_management_screens.dart';

void main() {
  testWidgets('shows employee directory rows', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hrRepositoryProvider.overrideWithValue(_FakeHrRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(AppThemePreset.ivorySlate),
          home: const EmployeeDirectoryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Nguyen Van A'), findsOneWidget);
    expect(find.byType(ListTile), findsWidgets);
  });
}

class _FakeHrRepository extends HrRepository {
  _FakeHrRepository() : super(Dio());

  @override
  Future<HrEmployeeDirectoryPage> getEmployees({
    String? search,
    String? department,
    String? jobTitle,
    bool? isActive,
    String? employmentStatus,
    int page = 1,
    int limit = 20,
  }) async {
    return const HrEmployeeDirectoryPage(
      items: [
        HrEmployeeSummary(
          id: 'emp-1',
          name: 'Nguyen Van A',
          email: 'a@19t.vn',
          department: 'Engineering',
          jobTitle: 'Flutter Dev',
          employmentStatus: 'active',
          isActive: true,
        ),
      ],
      total: 1,
      page: 1,
      limit: 20,
    );
  }
}
