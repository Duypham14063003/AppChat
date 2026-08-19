import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/core/config/app_config.dart';
import 'package:nineteen_tech_app/core/theme/app_theme.dart';
import 'package:nineteen_tech_app/features/chat/data/chat_avatar_resolver.dart';
import 'package:nineteen_tech_app/features/chat/data/search_result.dart';
import 'package:nineteen_tech_app/features/chat/data/user_repository.dart';
import 'package:nineteen_tech_app/features/chat/widgets/chat_avatar.dart';

void main() {
  group('resolveChatAvatarUrl', () {
    test('returns null for null or empty values', () {
      expect(resolveChatAvatarUrl(null), isNull);
      expect(resolveChatAvatarUrl(''), isNull);
      expect(resolveChatAvatarUrl('   '), isNull);
    });

    test('keeps absolute urls unchanged', () {
      expect(
        resolveChatAvatarUrl('https://cdn.example.com/avatar.png'),
        'https://cdn.example.com/avatar.png',
      );
    });

    test('expands relative urls using app api base url', () {
      expect(
        resolveChatAvatarUrl('/uploads/avatars/a.png'),
        '${AppConfig.instance.apiUrl}/uploads/avatars/a.png',
      );
    });
  });

  group('chat avatar parsing', () {
    test('UserContact resolves snake-case avatar values', () {
      final contact = UserContact.fromJson(const {
        'id': 'u1',
        'name': 'Jane Doe',
        'email': 'jane@example.com',
        'avatar_url': '/uploads/jane.png',
      });

      expect(
        contact.avatarUrl,
        '${AppConfig.instance.apiUrl}/uploads/jane.png',
      );
    });

    test('SearchResult resolves local row avatar values', () {
      final result = SearchResult.fromLocalRow({
        'id': 'm1',
        'conv_id': 'c1',
        'conv_type': 'DIRECT',
        'other_member_name': 'Jane Doe',
        'other_member_avatar': '/uploads/jane.png',
        'sender_id': 'u2',
        'created_at': DateTime(2026, 4, 20, 10, 0),
        'type': 'text',
        'content': 'hello',
      }, 'hello');

      expect(
        result.convAvatar,
        '${AppConfig.instance.apiUrl}/uploads/jane.png',
      );
    });
  });

  group('ChatAvatar', () {
    testWidgets('shows initials fallback for direct chats', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: ChatAvatar(displayName: 'Jane Doe')),
        ),
      );

      expect(find.text('JD'), findsOneWidget);
    });

    testWidgets('shows group icon fallback for group chats', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: ChatAvatar(displayName: 'Team', isGroup: true),
          ),
        ),
      );

      expect(find.byIcon(Icons.group), findsOneWidget);
    });
  });
}
