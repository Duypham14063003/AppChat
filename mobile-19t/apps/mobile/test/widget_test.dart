import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nineteen_tech_app/app.dart';

void main() {
  testWidgets('App renders placeholder home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    expect(find.text('19T Dev'), findsOneWidget);
  });
}
