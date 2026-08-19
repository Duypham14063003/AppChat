import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/core/theme/app_theme.dart';
import 'package:nineteen_tech_app/core/theme/theme_color_presets.dart';
import 'package:nineteen_tech_app/features/chat/data/user_repository.dart';
import 'package:nineteen_tech_app/features/chat/providers/chat_providers.dart';
import 'package:nineteen_tech_app/features/chat/screens/contact_picker_screen.dart';
import 'package:nineteen_tech_app/features/chat/screens/group_create_members_screen.dart';
import 'package:nineteen_tech_app/features/chat/screens/group_create_name_screen.dart';

void main() {
  final lightPalette = AppThemePreset.ivorySlate.palette;

  group('chat/group light mode theme surfaces', () {
    testWidgets('contact picker search and empty state use light palette', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          repository: _FakeUserRepository(),
          child: const ContactPickerScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final searchField = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      expect(searchField.style?.color, lightPalette.textPrimary);
      expect(searchField.decoration?.hintStyle?.color, lightPalette.textHint);

      final prefixIcon = searchField.decoration?.prefixIcon as Icon;
      expect(prefixIcon.color, lightPalette.textHint);

      final emptyState = tester.widget<Text>(
        find.text('Không tìm thấy liên hệ'),
      );
      expect(emptyState.style?.color, lightPalette.textSecondary);
    });

    testWidgets(
      'group create members search and empty state use light palette',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            repository: _FakeUserRepository(),
            child: const Scaffold(
              body: GroupCreateMembersScreen(asDialog: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final searchField = tester.widget<TextField>(
          find.byType(TextField).first,
        );
        expect(searchField.style?.color, lightPalette.textPrimary);
        expect(searchField.decoration?.hintStyle?.color, lightPalette.textHint);

        final title = tester.widget<Text>(find.text('Tạo nhóm'));
        expect(title.style?.color, lightPalette.textPrimary);

        final emptyState = tester.widget<Text>(
          find.text('Không tìm thấy liên hệ'),
        );
        expect(emptyState.style?.color, lightPalette.textSecondary);
      },
    );

    testWidgets('group create name dialog content uses light palette', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          repository: _FakeUserRepository(),
          child: const Scaffold(
            body: GroupCreateNameScreen(
              memberIds: ['u1', 'u2'],
              asDialog: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final nameField = tester.widget<TextField>(find.byType(TextField).first);
      expect(nameField.style?.color, lightPalette.textPrimary);
      expect(nameField.decoration?.hintStyle?.color, lightPalette.textHint);

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.backgroundColor, lightPalette.surfaceVariant);

      final cameraIcon = tester.widget<Icon>(find.byIcon(Icons.camera_alt));
      expect(cameraIcon.color, lightPalette.textHint);

      final header = tester.widget<Text>(find.text('Đặt tên nhóm'));
      expect(header.style?.color, lightPalette.textPrimary);
    });
  });
}

Widget _buildTestApp({
  required UserRepository repository,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [userRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      theme: AppTheme.dark(AppThemePreset.ivorySlate),
      home: child,
    ),
  );
}

class _FakeUserRepository extends UserRepository {
  _FakeUserRepository() : super(Dio());

  @override
  Future<UserListResponse> getUsers({
    String? search,
    String? cursor,
    int limit = 50,
  }) async {
    return const UserListResponse(users: [], total: 0, hasMore: false);
  }
}
