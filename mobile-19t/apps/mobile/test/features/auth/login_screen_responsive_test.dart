import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/core/theme/app_theme.dart';
import 'package:nineteen_tech_app/core/theme/theme_color_presets.dart';
import 'package:nineteen_tech_app/features/auth/data/auth_repository.dart';
import 'package:nineteen_tech_app/features/auth/providers/auth_notifier.dart';
import 'package:nineteen_tech_app/features/auth/screens/login_screen.dart';

void main() {
  group('LoginScreen responsive layout', () {
    testWidgets('uses a bounded content frame on wide viewports', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildHarness());
      await tester.pumpAndSettle();

      final frameSize = tester.getSize(
        find.byKey(const Key('login-content-frame')),
      );

      expect(frameSize.width, closeTo(loginContentFrameMaxWidth, 0.1));
    });

    testWidgets('keeps narrow layout width constrained by mobile padding', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildHarness());
      await tester.pumpAndSettle();

      final frameSize = tester.getSize(
        find.byKey(const Key('login-content-frame')),
      );

      expect(frameSize.width, closeTo(326, 0.1));
      expect(frameSize.width, lessThan(loginContentFrameMaxWidth));
    });

    testWidgets('exposes email and password fields to autofill services', (
      tester,
    ) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pumpAndSettle();

      final fields =
          tester.widgetList<EditableText>(find.byType(EditableText)).toList();
      final emailField = fields.first;
      final passwordField = fields.last;

      expect(
        emailField.autofillHints,
        const [AutofillHints.username, AutofillHints.email],
      );
      expect(passwordField.autofillHints, const [AutofillHints.password]);
    });

    testWidgets('keeps manual login submission behavior intact', (tester) async {
      final fakeNotifier = _FakeAuthNotifier();

      await tester.pumpWidget(_buildHarness(fakeNotifier: fakeNotifier));
      await tester.enterText(find.byType(TextFormField).at(0), 'duy@19t.vn');
      await tester.enterText(find.byType(TextFormField).at(1), 'secret');
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.pump();

      expect(fakeNotifier.loginCalls, 1);
      expect(fakeNotifier.lastEmail, 'duy@19t.vn');
      expect(fakeNotifier.lastPassword, 'secret');
    });
  });
}

Widget _buildHarness({_FakeAuthNotifier? fakeNotifier}) {
  final notifier = fakeNotifier ?? _FakeAuthNotifier();
  return ProviderScope(
    overrides: [authNotifierProvider.overrideWith(() => notifier)],
    child: MaterialApp(
      theme: AppTheme.dark(AppThemePreset.ivorySlate),
      home: const LoginScreen(),
    ),
  );
}

class _FakeAuthNotifier extends AuthNotifier {
  int loginCalls = 0;
  String? lastEmail;
  String? lastPassword;

  @override
  Future<AuthState> build() async => AuthState.unauthenticated;

  @override
  Future<void> login({required String email, required String password}) async {
    loginCalls++;
    lastEmail = email;
    lastPassword = password;
    state = const AsyncData(
      AuthState(
        status: AuthStatus.authenticated,
        user: UserInfo(
          id: 'user-1',
          email: 'duy@19t.vn',
          name: 'Duy',
          roles: ['employee'],
        ),
      ),
    );
  }
}
