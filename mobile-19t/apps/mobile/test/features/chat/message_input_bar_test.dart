import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:nineteen_tech_app/core/database/app_database.dart';
import 'package:nineteen_tech_app/core/theme/app_theme.dart';
import 'package:nineteen_tech_app/core/utils/web_attachment_preview_common.dart';
import 'package:nineteen_tech_app/features/chat/utils/chat_attachment_drop.dart';
import 'package:nineteen_tech_app/features/chat/widgets/message_input_bar.dart';
import 'package:nineteen_tech_app/features/chat/widgets/web_chat_drop_target_common.dart';

void main() {
  group('chat web attachment drop classification', () {
    test('accepts multiple images as a single image batch', () {
      final result = classifyMessageInputBarDrop([
        const ChatAttachmentDropCandidate(
          name: 'a.png',
          mimeType: 'image/png',
          sizeInBytes: 1024,
        ),
        const ChatAttachmentDropCandidate(
          name: 'b.jpg',
          mimeType: 'image/jpeg',
          sizeInBytes: 2048,
        ),
      ]);

      expect(result.isAccepted, isTrue);
      expect(result.kind, ChatAttachmentDropKind.images);
    });

    test('accepts a single supported document', () {
      final result = classifyMessageInputBarDrop([
        const ChatAttachmentDropCandidate(
          name: 'report.pdf',
          mimeType: 'application/pdf',
          sizeInBytes: 1024,
        ),
      ]);

      expect(result.isAccepted, isTrue);
      expect(result.kind, ChatAttachmentDropKind.document);
    });

    test('rejects mixed attachment payloads', () {
      final result = classifyMessageInputBarDrop([
        const ChatAttachmentDropCandidate(
          name: 'photo.png',
          mimeType: 'image/png',
          sizeInBytes: 1024,
        ),
        const ChatAttachmentDropCandidate(
          name: 'notes.pdf',
          mimeType: 'application/pdf',
          sizeInBytes: 1024,
        ),
      ]);

      expect(result.isAccepted, isFalse);
      expect(result.rejectionReason, ChatAttachmentDropRejectionReason.mixed);
    });

    test('rejects unsupported documents before attachment flow begins', () {
      final result = classifyMessageInputBarDrop([
        const ChatAttachmentDropCandidate(
          name: 'archive.exe',
          mimeType: 'application/octet-stream',
          sizeInBytes: 2048,
        ),
      ]);

      expect(result.isAccepted, isFalse);
      expect(
        result.rejectionReason,
        ChatAttachmentDropRejectionReason.unsupported,
      );
    });

    testWidgets('invalid drop leaves the current draft text untouched', (
      tester,
    ) async {
      var imagesAttached = false;
      await tester.pumpWidget(
        _buildHarness(
          MessageInputBar(
            conversationId: 'test_conv',
            onSend: (_, {linkPreview, mentions}) {},
            onAttachImages: (_) => imagesAttached = true,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'keep this draft');
      await tester.pumpAndSettle();

      final result = await dispatchMessageInputBarDrop(
        files: [
          ChatAttachmentDropFile(
            name: 'photo.png',
            mimeType: 'image/png',
            sizeInBytes: 1024,
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
          ChatAttachmentDropFile(
            name: 'notes.pdf',
            mimeType: 'application/pdf',
            sizeInBytes: 1024,
            bytes: Uint8List.fromList([4, 5, 6]),
          ),
        ],
        validateVideo: (_) async => true,
        onAttachImages: (_) => imagesAttached = true,
      );

      expect(result.isAccepted, isFalse);
      expect(imagesAttached, isFalse);
      expect(find.text('keep this draft'), findsOneWidget);
    });
  });

  group('web attachment preview compatibility', () {
    test('reuses picker-style blob URLs directly', () {
      expect(
        isReusableBrowserPreviewUrl('blob:https://app.test/preview-1'),
        isTrue,
      );
    });

    test(
      'requires generated preview for clipboard-style data-backed files',
      () {
        expect(isReusableBrowserPreviewUrl(''), isFalse);
      },
    );

    test('accepts network URLs for previously normalized media', () {
      expect(
        isReusableBrowserPreviewUrl('https://cdn.example.com/video.mp4'),
        isTrue,
      );
    });

    test('accepts ByteBuffer file reader results', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final converted = bytesFromBrowserFileReaderResult(bytes.buffer);

      expect(converted, isNotNull);
      expect(converted, [1, 2, 3]);
    });

    test('accepts Uint8List file reader results', () {
      final converted = bytesFromBrowserFileReaderResult(
        Uint8List.fromList([4, 5, 6]),
      );

      expect(converted, isNotNull);
      expect(converted, [4, 5, 6]);
    });

    test('accepts ByteData file reader results', () {
      final data = ByteData.sublistView(Uint8List.fromList([7, 8, 9]));
      final converted = bytesFromBrowserFileReaderResult(data);

      expect(converted, isNotNull);
      expect(converted, [7, 8, 9]);
    });
  });

  group('chat document validation', () {
    test('accepts supported document extensions only', () {
      expect(isSupportedChatDocumentExtension('report.pdf'), isTrue);
      expect(isSupportedChatDocumentExtension('deck.PPTX'), isTrue);
      expect(isSupportedChatDocumentExtension('photo.jpg'), isFalse);
      expect(isSupportedChatDocumentExtension('no-extension'), isFalse);
    });

    test('enforces 20MB upload limit', () {
      expect(isSupportedChatDocumentSize(20 * 1024 * 1024), isTrue);
      expect(isSupportedChatDocumentSize(20 * 1024 * 1024 + 1), isFalse);
    });
  });

  group('MessageInputBar web keyboard behavior', () {
    test('Shift+Enter inserts newline and does not send', () {
      var newlineCount = 0;
      var sendCount = 0;

      final result = handleComposerKeyEvent(
        event: _enterDownEvent(),
        isSending: false,
        isShiftPressed: true,
        insertNewline: () => newlineCount++,
        send: () => sendCount++,
      );

      expect(result, KeyEventResult.handled);
      expect(newlineCount, 1);
      expect(sendCount, 0);
    });

    test('Enter without Shift sends message shortcut', () {
      var newlineCount = 0;
      var sendCount = 0;

      final result = handleComposerKeyEvent(
        event: _enterDownEvent(),
        isSending: false,
        isShiftPressed: false,
        insertNewline: () => newlineCount++,
        send: () => sendCount++,
      );

      expect(result, KeyEventResult.handled);
      expect(newlineCount, 0);
      expect(sendCount, 1);
    });

    test('Enter does not send while composer is already sending', () {
      var newlineCount = 0;
      var sendCount = 0;

      final result = handleComposerKeyEvent(
        event: _enterDownEvent(),
        isSending: true,
        isShiftPressed: false,
        insertNewline: () => newlineCount++,
        send: () => sendCount++,
      );

      expect(result, KeyEventResult.handled);
      expect(newlineCount, 0);
      expect(sendCount, 0);
    });

    testWidgets('send button preserves multiline message content', (
      tester,
    ) async {
      final sentMessages = <String>[];
      await tester.pumpWidget(
        _buildHarness(
          MessageInputBar(
            conversationId: 'test_conv',
            onSend: (text, {linkPreview, mentions}) {
              sentMessages.add(text);
            },
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'line 1\nline 2');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(sentMessages, ['line 1\nline 2']);
    });

    testWidgets('send button does not send whitespace-only text', (
      tester,
    ) async {
      final sentMessages = <String>[];
      await tester.pumpWidget(
        _buildHarness(
          MessageInputBar(
            conversationId: 'test_conv',
            onSend: (text, {linkPreview, mentions}) {
              sentMessages.add(text);
            },
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
      expect(sentMessages, isEmpty);
    });
  });

  group('MessageInputBar edit mode', () {
    testWidgets('prefills composer and shows edit banner', (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          MessageInputBar(
            conversationId: 'test_conv',
            onSend: (_, {linkPreview, mentions}) {},
            editingMessage: _message('Original text'),
          ),
        ),
      );

      expect(find.text('Đang sửa tin nhắn'), findsOneWidget);
      expect(find.text('Original text'), findsNWidgets(2));
    });

    testWidgets('cancel edit callback is triggered from banner', (
      tester,
    ) async {
      var cancelTapped = false;
      await tester.pumpWidget(
        _buildHarness(
          MessageInputBar(
            conversationId: 'test_conv',
            onSend: (_, {linkPreview, mentions}) {},
            editingMessage: _message('Original text'),
            onCancelEdit: () => cancelTapped = true,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Hủy sửa'));
      await tester.pumpAndSettle();

      expect(cancelTapped, isTrue);
    });
  });

  group('MessageInputBar keyboard dismiss behavior', () {
    testWidgets('outside tap dismisses composer focus', (tester) async {
      final outsideTapKey = UniqueKey();
      await tester.pumpWidget(
        _buildDismissHarness(
          outsideTapKey: outsideTapKey,
          child: MessageInputBar(conversationId: 'test_conv', onSend: (_, {linkPreview, mentions}) {}),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      final editableBefore = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      expect(editableBefore.widget.focusNode.hasFocus, isTrue);

      await tester.tap(find.byKey(outsideTapKey));
      await tester.pumpAndSettle();

      final editableAfter = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      expect(editableAfter.widget.focusNode.hasFocus, isFalse);
    });

    testWidgets(
      'outside tap dismisses mention overlay and keeps send flow functional',
      (tester) async {
        final outsideTapKey = UniqueKey();
        final sentMessages = <String>[];
        await tester.pumpWidget(
          _buildDismissHarness(
            outsideTapKey: outsideTapKey,
            child: MessageInputBar(
              conversationId: 'test_conv',
              onSend: (text, {linkPreview, mentions}) {
                sentMessages.add(text);
              },
              isGroup: true,
              currentUserId: 'user-1',
              members: {
                'user-1': {'name': 'Me'},
                'user-2': {'name': 'Alice'},
              },
            ),
          ),
        );

        await tester.tap(find.byType(TextField));
        await tester.enterText(find.byType(TextField), '@al');
        await tester.pumpAndSettle();
        expect(find.text('Alice'), findsOneWidget);

        await tester.tap(find.byKey(outsideTapKey));
        await tester.pumpAndSettle();
        expect(find.text('Alice'), findsNothing);

        await tester.tap(find.byType(TextField));
        await tester.enterText(find.byType(TextField), 'hello');
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pumpAndSettle();

        expect(sentMessages, ['hello']);
      },
    );

    testWidgets('outside tap dismisses emoji picker', (tester) async {
      final outsideTapKey = UniqueKey();
      await tester.pumpWidget(
        _buildDismissHarness(
          outsideTapKey: outsideTapKey,
          child: MessageInputBar(conversationId: 'test_conv', onSend: (_, {linkPreview, mentions}) {}),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Emoji'));
      await tester.pumpAndSettle();
      expect(find.byType(EmojiPicker), findsOneWidget);

      await tester.tap(find.byKey(outsideTapKey));
      await tester.pumpAndSettle();
      expect(find.byType(EmojiPicker), findsNothing);
    });
  });

  group('MessageInputBar remote activity continuity', () {
    testWidgets(
      'typing indicator appearance keeps composer focused and editable',
      (tester) async {
        final harnessKey = GlobalKey<_RemoteActivityHarnessState>();
        await tester.pumpWidget(
          _buildHarness(_RemoteActivityHarness(key: harnessKey)),
        );

        await tester.tap(find.byType(TextField));
        await tester.enterText(find.byType(TextField), 'hello');
        await tester.pumpAndSettle();

        harnessKey.currentState!.setTypingVisible(true);
        await tester.pumpAndSettle();

        final editable = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        expect(editable.widget.focusNode.hasFocus, isTrue);
        expect(find.text('hello'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'hello world');
        await tester.pumpAndSettle();
        expect(find.text('hello world'), findsOneWidget);
      },
    );

    testWidgets('typing indicator updates and expiry keep composer focused', (
      tester,
    ) async {
      final harnessKey = GlobalKey<_RemoteActivityHarnessState>();
      await tester.pumpWidget(
        _buildHarness(_RemoteActivityHarness(key: harnessKey)),
      );

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'draft');
      await tester.pumpAndSettle();

      harnessKey.currentState!.setTypingVisible(true, label: 'Alice is typing');
      await tester.pumpAndSettle();
      harnessKey.currentState!.setTypingVisible(true, label: 'Bob is typing');
      await tester.pumpAndSettle();
      harnessKey.currentState!.setTypingVisible(false);
      await tester.pumpAndSettle();

      final editable = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      expect(editable.widget.focusNode.hasFocus, isTrue);
      expect(find.text('draft'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'draft again');
      await tester.pumpAndSettle();
      expect(find.text('draft again'), findsOneWidget);
    });

    testWidgets('remote message updates preserve draft and full send flow', (
      tester,
    ) async {
      final harnessKey = GlobalKey<_RemoteActivityHarnessState>();
      await tester.pumpWidget(
        _buildHarness(_RemoteActivityHarness(key: harnessKey)),
      );

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pumpAndSettle();

      harnessKey.currentState!.addRemoteMessage('Remote 1');
      await tester.pumpAndSettle();

      final editable = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      expect(editable.widget.focusNode.hasFocus, isTrue);
      expect(find.text('hello'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'hello world');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(harnessKey.currentState!.sentMessages, ['hello world']);
    });

    testWidgets(
      'reply, edit, emoji, and mention flows remain coherent after rebuilds',
      (tester) async {
        final harnessKey = GlobalKey<_RemoteActivityHarnessState>();
        await tester.pumpWidget(
          _buildHarness(
            _RemoteActivityHarness(
              key: harnessKey,
              isGroup: true,
              replyTo: _message('Reply target'),
            ),
          ),
        );

        await tester.tap(find.byType(TextField));
        await tester.enterText(find.byType(TextField), '@al');
        await tester.pumpAndSettle();
        expect(find.text('Alice'), findsOneWidget);

        await tester.tap(find.byTooltip('Emoji'));
        await tester.pumpAndSettle();
        expect(find.byType(EmojiPicker), findsOneWidget);

        harnessKey.currentState!.setTypingVisible(true);
        await tester.pumpAndSettle();

        expect(find.text('Alice'), findsOneWidget);
        expect(find.byType(EmojiPicker), findsOneWidget);
        expect(find.text('Reply target'), findsOneWidget);

        await tester.tap(find.byTooltip('Emoji'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'hello');
        await tester.pumpAndSettle();

        harnessKey.currentState!.replaceWithEditingMessage(_message('Edit me'));
        await tester.pumpAndSettle();

        final editable = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        expect(editable.widget.focusNode.hasFocus, isTrue);
        expect(find.text('Đang sửa tin nhắn'), findsOneWidget);
        expect(find.text('Edit me'), findsNWidgets(2));
      },
    );
  });

  group('MessageInputBar conversation switch reset', () {
    testWidgets(
      'switching conversations clears draft and transient composer state',
      (tester) async {
        final harnessKey = GlobalKey<_ConversationSwitchHarnessState>();
        await tester.pumpWidget(
          _buildBottomComposerHarness(
            _ConversationSwitchHarness(key: harnessKey, isGroup: true),
          ),
        );

        await tester.tap(find.byType(TextField));
        await tester.enterText(find.byType(TextField), 'carry me');
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Emoji'));
        await tester.pumpAndSettle();

        expect(find.byType(EmojiPicker), findsOneWidget);
        expect(find.text('carry me'), findsOneWidget);

        harnessKey.currentState!.switchConversation('conv-2');
        await tester.pumpAndSettle();

        expect(find.byType(EmojiPicker), findsNothing);
        expect(find.text('carry me'), findsNothing);

        await tester.enterText(find.byType(TextField), 'fresh draft');
        await tester.pumpAndSettle();
        expect(find.text('fresh draft'), findsOneWidget);
      },
    );

    testWidgets('same-conversation rebuild preserves the active draft', (
      tester,
    ) async {
      final harnessKey = GlobalKey<_ConversationSwitchHarnessState>();
      await tester.pumpWidget(
        _buildBottomComposerHarness(
          _ConversationSwitchHarness(key: harnessKey),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'keep me');
      await tester.pumpAndSettle();

      harnessKey.currentState!.rebuildSameConversation();
      await tester.pumpAndSettle();

      expect(find.text('keep me'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'keep me too');
      await tester.pumpAndSettle();
      expect(find.text('keep me too'), findsOneWidget);
    });
  });

  group('MessageInputBar mention integrity and styling', () {
    test(
      'recalculateComposerMentions shifts unaffected mentions independently',
      () {
        final result = recalculateComposerMentions(
          mentions: const [
            {'offset': 0, 'length': 6, 'user_id': 'user-2', 'name': 'Alice'},
            {'offset': 11, 'length': 4, 'user_id': 'user-3', 'name': 'Bob'},
          ],
          oldText: '@Alice and @Bob',
          newText: 'hi @Alice and @Bob',
        );

        expect(result, hasLength(2));
        expect(result[0]['offset'], 3);
        expect(result[1]['offset'], 14);
      },
    );

    test(
      'recalculateComposerMentions removes only the intersected mention',
      () {
        final result = recalculateComposerMentions(
          mentions: const [
            {'offset': 0, 'length': 6, 'user_id': 'user-2', 'name': 'Alice'},
            {'offset': 11, 'length': 4, 'user_id': 'user-3', 'name': 'Bob'},
          ],
          oldText: '@Alice and @Bob',
          newText: '@Alicee and @Bob',
        );

        expect(result, hasLength(1));
        expect(result.single['user_id'], 'user-3');
        expect(result.single['offset'], 12);
      },
    );

    testWidgets(
      'selected mention is highlighted and keeps a stable color after trailing text',
      (tester) async {
        await tester.pumpWidget(
          _buildBottomComposerHarness(
            MessageInputBar(
              conversationId: 'test_conv',
              onSend: (_, {linkPreview, mentions}) {},
              isGroup: true,
              currentUserId: 'user-1',
              members: {
                'user-1': {'name': 'Me'},
                'user-2': {'name': 'Alice'},
              },
            ),
          ),
        );

        await tester.tap(find.byType(TextField));
        await tester.enterText(find.byType(TextField), '@al');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Alice'));
        await tester.pumpAndSettle();

        var composerSpan = _composerTextSpan(tester);
        var children = composerSpan.children!.cast<TextSpan>();
        expect(children.map((span) => span.text).toList(), ['@Alice', ' ']);
        expect(children.first.style?.fontWeight, FontWeight.w700);
        expect(
          children.first.style?.color,
          composerMentionColorForUserId('user-2'),
        );

        await tester.enterText(find.byType(TextField), '@Alice abc');
        await tester.pumpAndSettle();

        composerSpan = _composerTextSpan(tester);
        children = composerSpan.children!.cast<TextSpan>();
        expect(children.map((span) => span.text).toList(), ['@Alice', ' abc']);
        expect(children.first.style?.fontWeight, FontWeight.w700);
        expect(
          children.first.style?.color,
          composerMentionColorForUserId('user-2'),
        );
        expect(children.last.style?.fontWeight, isNot(FontWeight.w700));
      },
    );

    testWidgets('typing after a mention preserves sent mention metadata', (
      tester,
    ) async {
      List<Map<String, dynamic>>? sentMentions;
      await tester.pumpWidget(
        _buildBottomComposerHarness(
          MessageInputBar(
            conversationId: 'test_conv',
            onSend: (_, {linkPreview, mentions}) {
              sentMentions = mentions;
            },
            isGroup: true,
            currentUserId: 'user-1',
            members: {
              'user-1': {'name': 'Me'},
              'user-2': {'name': 'Alice'},
            },
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '@al');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '@Alice abc');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(sentMentions, isNotNull);
      expect(sentMentions, hasLength(1));
      expect(sentMentions!.single['offset'], 0);
      expect(sentMentions!.single['length'], 6);
    });

    testWidgets('editing inside a mention removes its metadata before send', (
      tester,
    ) async {
      List<Map<String, dynamic>>? sentMentions;
      await tester.pumpWidget(
        _buildBottomComposerHarness(
          MessageInputBar(
            conversationId: 'test_conv',
            onSend: (_, {linkPreview, mentions}) {
              sentMentions = mentions;
            },
            isGroup: true,
            currentUserId: 'user-1',
            members: {
              'user-1': {'name': 'Me'},
              'user-2': {'name': 'Alice'},
            },
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '@al');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '@Alicee');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(sentMentions, isNull);
    });
  });
}

KeyDownEvent _enterDownEvent() {
  return const KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.enter,
    logicalKey: LogicalKeyboardKey.enter,
    timeStamp: Duration.zero,
  );
}

Widget _buildHarness(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: child),
    ),
  );
}

Widget _buildDismissHarness({
  required Key outsideTapKey,
  required Widget child,
}) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: SizedBox.expand(
                child: GestureDetector(
                  key: outsideTapKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    ),
  );
}

Widget _buildBottomComposerHarness(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: Column(
          children: [
            const Expanded(child: SizedBox.expand()),
            child,
          ],
        ),
      ),
    ),
  );
}

LocalMessage _message(String content) {
  return LocalMessage(
    id: 'msg-1',
    convId: 'conv-1',
    senderId: 'user-1',
    type: 'text',
    content: content,
    createdAt: DateTime(2026, 4, 22, 10, 0),
    status: 'sent',
    retryCount: 0,
  );
}

TextSpan _composerTextSpan(WidgetTester tester) {
  final editable = tester.widget<EditableText>(find.byType(EditableText));
  final context = tester.element(find.byType(EditableText));
  return editable.controller.buildTextSpan(
    context: context,
    style: editable.style,
    withComposing: false,
  );
}

class _RemoteActivityHarness extends StatefulWidget {
  const _RemoteActivityHarness({super.key, this.isGroup = false, this.replyTo});

  final bool isGroup;
  final LocalMessage? replyTo;

  @override
  State<_RemoteActivityHarness> createState() => _RemoteActivityHarnessState();
}

class _RemoteActivityHarnessState extends State<_RemoteActivityHarness> {
  bool _showTypingIndicator = false;
  String _typingLabel = 'Someone is typing';
  final List<String> _remoteMessages = [];
  final List<String> sentMessages = [];
  LocalMessage? _replyTo;
  LocalMessage? _editingMessage;

  @override
  void initState() {
    super.initState();
    _replyTo = widget.replyTo;
  }

  void setTypingVisible(bool value, {String label = 'Someone is typing'}) {
    setState(() {
      _showTypingIndicator = value;
      _typingLabel = label;
    });
  }

  void addRemoteMessage(String message) {
    setState(() {
      _remoteMessages.insert(0, message);
    });
  }

  void replaceWithEditingMessage(LocalMessage message) {
    setState(() {
      _replyTo = null;
      _editingMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [for (final message in _remoteMessages) Text(message)],
            ),
          ),
          if (_showTypingIndicator)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(_typingLabel),
              ),
            ),
          MessageInputBar(
            conversationId: 'test_conv',
            onSend: (text, {linkPreview, mentions}) {
              sentMessages.add(text);
            },
            isGroup: widget.isGroup,
            currentUserId: 'user-1',
            members: widget.isGroup
                ? {
                    'user-1': {'name': 'Me'},
                    'user-2': {'name': 'Alice'},
                    'user-3': {'name': 'Bob'},
                  }
                : null,
            replyTo: _replyTo,
            editingMessage: _editingMessage,
            replyToSenderName: 'Responder',
            onCancelReply: () => setState(() => _replyTo = null),
            onCancelEdit: () => setState(() => _editingMessage = null),
          ),
        ],
      ),
    );
  }
}

class _ConversationSwitchHarness extends StatefulWidget {
  const _ConversationSwitchHarness({super.key, this.isGroup = false});

  final bool isGroup;

  @override
  State<_ConversationSwitchHarness> createState() =>
      _ConversationSwitchHarnessState();
}

class _ConversationSwitchHarnessState
    extends State<_ConversationSwitchHarness> {
  String _conversationId = 'conv-1';
  int _sameConversationRevision = 0;

  void switchConversation(String conversationId) {
    setState(() {
      _conversationId = conversationId;
    });
  }

  void rebuildSameConversation() {
    setState(() {
      _sameConversationRevision++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final composer = MessageInputBar(
      key: ValueKey('chat_message_input_bar_$_conversationId'),
      conversationId: _conversationId,
      onSend: (_, {linkPreview, mentions}) {},
      isGroup: widget.isGroup,
      currentUserId: 'user-1',
      members: widget.isGroup
          ? {
              'user-1': {'name': 'Me'},
              'user-2': {'name': 'Alice'},
              'user-3': {'name': 'Bob'},
            }
          : null,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ColoredBox(
          color: Colors.transparent,
          child: Text(
            'conversation=$_conversationId/$_sameConversationRevision',
          ),
        ),
        composer,
      ],
    );
  }
}
