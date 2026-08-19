import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/core/theme/app_theme.dart';
import 'package:nineteen_tech_app/features/poc/models/poc_models.dart';
import 'package:nineteen_tech_app/features/poc/widgets/poc_widgets.dart';

void main() {
  for (final size in const [Size(390, 844), Size(1200, 900)]) {
    testWidgets('PoC card contains long text at ${size.width}px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: PocListCard(poc: _poc(), onTap: () {}),
            ),
          ),
        ),
      );

      expect(find.textContaining('POC-WITH-A-VERY-LONG'), findsOneWidget);
      expect(find.text('Quá hạn'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

PocRecord _poc() => PocRecord(
  id: 'poc-1',
  code: 'POC-WITH-A-VERY-LONG-CODE-THAT-MUST-NOT-OVERFLOW',
  customerName: 'Khách hàng có tên rất dài để kiểm thử giới hạn nội dung',
  title: 'Một dự án demo có tiêu đề dài và vẫn phải hiển thị gọn trong card',
  requirement: 'Requirement',
  productType: 'validation',
  priority: 'urgent',
  saleUserId: 'sale-1',
  developerUserId: 'dev-1',
  demoAt: DateTime(2026, 8, 14, 10),
  status: 'in_progress',
  version: 1,
  referenceLinks: const [],
  history: const [],
  overdue: true,
  saleUser: const PocUser(id: 'sale-1', name: 'Sale Owner With Long Name'),
  developerUser: const PocUser(id: 'dev-1', name: 'Developer With Long Name'),
  estimatedHours: 28,
);
