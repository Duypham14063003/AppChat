import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/core/database/app_database.dart';
import 'package:nineteen_tech_app/core/theme/app_theme.dart';
import 'package:nineteen_tech_app/features/chat/widgets/message_bubble.dart';

void main() {
  group('formatChatBubbleTimestamp', () {
    test('keeps same-day timestamps time-only', () {
      expect(
        formatChatBubbleTimestamp(
          DateTime(2026, 4, 22, 9, 5),
          now: DateTime(2026, 4, 22, 18, 0),
        ),
        '09:05',
      );
    });

    test('shows day/month and time for older messages in the same year', () {
      expect(
        formatChatBubbleTimestamp(
          DateTime(2026, 4, 20, 10, 30),
          now: DateTime(2026, 4, 22, 18, 0),
        ),
        '20/04 10:30',
      );
    });

    test(
      'shows day/month/year and time for older messages from past years',
      () {
        expect(
          formatChatBubbleTimestamp(
            DateTime(2025, 12, 31, 23, 45),
            now: DateTime(2026, 1, 1, 8, 0),
          ),
          '31/12/2025 23:45',
        );
      },
    );
  });

  group('maxMessageBubbleWidthForAvailableWidth', () {
    test('keeps narrow/mobile bubble sizing unchanged', () {
      expect(maxMessageBubbleWidthForAvailableWidth(400), closeTo(300, 0.1));
      expect(maxMessageBubbleWidthForAvailableWidth(640), closeTo(480, 0.1));
    });

    test('widens desktop bubbles without removing the cap', () {
      expect(maxMessageBubbleWidthForAvailableWidth(960), closeTo(640, 0.1));
      expect(maxMessageBubbleWidthForAvailableWidth(1600), closeTo(640, 0.1));
    });
  });

  group('MessageBubble layout', () {
    testWidgets(
      'incoming direct bubbles align further left than group bubbles',
      (tester) async {
        await tester.pumpWidget(
          _buildHarness(
            MessageBubble(
              message: _message(content: 'direct message'),
              isMine: false,
              senderName: 'Huynh Thi Minh Anh',
              isFirstInGroup: true,
              isLastInGroup: true,
              showAvatar: false,
              showSenderName: false,
            ),
          ),
        );

        final directTextLeft = tester
            .getTopLeft(find.text('direct message'))
            .dx;

        await tester.pumpWidget(
          _buildHarness(
            MessageBubble(
              message: _message(content: 'group message'),
              isMine: false,
              senderName: 'Huynh Thi Minh Anh',
              isFirstInGroup: true,
              isLastInGroup: true,
              showAvatar: true,
              showSenderName: true,
            ),
          ),
        );

        final groupTextLeft = tester.getTopLeft(find.text('group message')).dx;

        expect(directTextLeft, lessThan(40));
        expect(groupTextLeft, greaterThan(directTextLeft + 10));
      },
    );

    testWidgets('shows recalled placeholder instead of original content', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHarness(
          MessageBubble(
            message: _message(
              content: 'should be hidden',
              deletedAt: DateTime(2026, 4, 22, 10, 0),
            ),
            isMine: true,
          ),
        ),
      );

      expect(find.text('Tin nhắn đã được thu hồi'), findsOneWidget);
      expect(find.text('should be hidden'), findsNothing);
    });

    testWidgets('shows edited label for edited messages', (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          MessageBubble(
            message: _message(
              content: 'edited text',
              editedAt: DateTime(2026, 4, 22, 10, 0),
            ),
            isMine: true,
          ),
        ),
      );

      expect(find.text('Đã sửa'), findsOneWidget);
    });

    testWidgets('renders file attachments as cards', (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          MessageBubble(
            message: LocalMessage(
              id: 'msg-file-1',
              convId: 'conv-1',
              senderId: 'user-2',
              type: 'file',
              content: 'report.pdf',
              metadata:
                  '{"url":"/uploads/chat/report.pdf","originalName":"report.pdf","mimeType":"application/pdf","size":153248}',
              createdAt: DateTime(2026, 4, 20, 10, 30),
              status: 'delivered',
              retryCount: 0,
            ),
            isMine: false,
          ),
        ),
      );

      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.textContaining('PDF'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);
    });

    testWidgets('renders mention spans inline at start middle and end', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHarness(
          Column(
            children: [
              MessageBubble(
                message: _message(
                  content: '@Alice abc',
                  metadata:
                      '{"mentions":[{"offset":0,"length":6,"user_id":"user-2","name":"Alice"}]}',
                ),
                isMine: true,
              ),
              MessageBubble(
                message: _message(
                  content: 'abc @Alice xyz',
                  metadata:
                      '{"mentions":[{"offset":4,"length":6,"user_id":"user-2","name":"Alice"}]}',
                ),
                isMine: false,
              ),
              MessageBubble(
                message: _message(
                  content: 'abc @Alice',
                  metadata:
                      '{"mentions":[{"offset":4,"length":6,"user_id":"user-2","name":"Alice"}]}',
                ),
                isMine: false,
              ),
            ],
          ),
        ),
      );

      final startSpans = _richTextChildren(tester, '@Alice abc');
      expect(startSpans.map((span) => span.text).toList(), ['@Alice', ' abc']);
      expect(startSpans.first.style?.fontWeight, FontWeight.w700);

      final middleSpans = _richTextChildren(tester, 'abc @Alice xyz');
      expect(
        middleSpans.map((span) => span.text).toList(),
        ['abc ', '@Alice', ' xyz'],
      );
      expect(middleSpans[1].style?.fontWeight, FontWeight.w700);

      final endSpans = _richTextChildren(tester, 'abc @Alice');
      expect(endSpans.map((span) => span.text).toList(), ['abc ', '@Alice']);
      expect(endSpans.last.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('invalid mention metadata does not hide surrounding text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHarness(
          MessageBubble(
            message: _message(
              content: 'abc @Alice xyz',
              metadata:
                  '{"mentions":[{"offset":99,"length":6,"user_id":"user-2","name":"Alice"}]}',
            ),
            isMine: false,
          ),
        ),
      );

      final spans = _richTextChildren(tester, 'abc @Alice xyz');
      expect(spans.map((span) => span.text).join(), 'abc @Alice xyz');
    });
  });
}

Widget _buildHarness(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 400, child: child),
      ),
    ),
  );
}

LocalMessage _message({
  required String content,
  String? metadata,
  DateTime? editedAt,
  DateTime? deletedAt,
}) {
  return LocalMessage(
    id: 'msg-1',
    convId: 'conv-1',
    senderId: 'user-2',
    type: 'text',
    content: content,
    metadata: metadata,
    createdAt: DateTime(2026, 4, 20, 10, 30),
    editedAt: editedAt,
    deletedAt: deletedAt,
    status: 'delivered',
    retryCount: 0,
  );
}

List<TextSpan> _richTextChildren(WidgetTester tester, String text) {
  final finder = find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText() == text,
  );
  final richText = tester.widget<RichText>(finder.first);
  final span = richText.text as TextSpan;
  return _collectLeafTextSpans(span);
}

List<TextSpan> _collectLeafTextSpans(TextSpan span) {
  final children = span.children;
  if (children == null || children.isEmpty) {
    return [span];
  }

  final leaves = <TextSpan>[];
  for (final child in children) {
    if (child is TextSpan) {
      leaves.addAll(_collectLeafTextSpans(child));
    }
  }
  return leaves;
}
