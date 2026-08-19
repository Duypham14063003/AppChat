import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/core/database/app_database.dart';
import 'package:nineteen_tech_app/features/chat/screens/chat_screen.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

void main() {
  group('chat search navigation helpers', () {
    test('finds matches from loaded decrypted room messages', () {
      final ids = findLoadedConversationSearchMatchIds(
        query: 'asd',
        loadedMessages: [
          _message('msg-1', content: 'asdasd'),
          _message('msg-2', content: 'hello'),
          _message('msg-3', content: 'ASD test'),
          _message('msg-4', content: null),
        ],
      );

      expect(ids, ['msg-1', 'msg-3']);
    });

    test(
      'selects the first navigable match for initial auto-scroll and excludes unavailable hits from the counter',
      () {
        final state = buildChatSearchNavigationState(
          rawMatchIds: const ['msg-9', 'msg-2', 'msg-3', 'msg-2'],
          loadedMessages: [
            _message('msg-1'),
            _message('msg-2'),
            _message('msg-3'),
          ],
          resetToFirst: true,
        );

        expect(state.matchIds, ['msg-2', 'msg-3']);
        expect(state.currentIndex, 0);
        expect(state.currentMessageId, 'msg-2');
      },
    );

    test(
      'keeps the selected navigable match when recalculating from raw hits',
      () {
        final state = buildChatSearchNavigationState(
          rawMatchIds: const ['msg-9', 'msg-2', 'msg-3'],
          loadedMessages: [
            _message('msg-2'),
            _message('msg-3'),
            _message('msg-4'),
          ],
          selectedMessageId: 'msg-3',
        );

        expect(state.matchIds, ['msg-2', 'msg-3']);
        expect(state.currentIndex, 1);
        expect('${state.currentIndex + 1}/${state.matchIds.length}', '2/2');
        expect(state.currentMessageId, 'msg-3');
      },
    );

    test('cycles next and previous within the same navigable match set', () {
      expect(
        cycleChatSearchIndex(currentIndex: 0, matchCount: 3, forward: true),
        1,
      );
      expect(
        cycleChatSearchIndex(currentIndex: 2, matchCount: 3, forward: true),
        0,
      );
      expect(
        cycleChatSearchIndex(currentIndex: 0, matchCount: 3, forward: false),
        2,
      );
    });

    test(
      're-triggers initial jump when messageId changes inside the same conversation',
      () {
        expect(
          shouldRetriggerInitialMessageJump(
            oldConversationId: 'conv-1',
            newConversationId: 'conv-1',
            oldInitialMessageId: 'msg-1',
            newInitialMessageId: 'msg-2',
          ),
          isTrue,
        );

        expect(
          shouldRetriggerInitialMessageJump(
            oldConversationId: 'conv-1',
            newConversationId: 'conv-1',
            oldInitialMessageId: 'msg-2',
            newInitialMessageId: 'msg-2',
          ),
          isFalse,
        );

        expect(
          shouldRetriggerInitialMessageJump(
            oldConversationId: 'conv-1',
            newConversationId: 'conv-2',
            oldInitialMessageId: 'msg-1',
            newInitialMessageId: 'msg-2',
          ),
          isFalse,
        );
      },
    );
  });

  group('historical jump helpers', () {
    test('finds a loaded message index by id', () {
      expect(
        findMessageIndexById('msg-2', [_message('msg-1'), _message('msg-2')]),
        1,
      );
      expect(findMessageIndexById('missing', [_message('msg-1')]), -1);
    });

    test(
      'keeps loading when history grows and the target is still missing',
      () {
        final resolution = evaluateHistoricalJumpResolution(
          messageId: 'msg-9',
          messages: [_message('msg-1'), _message('msg-2'), _message('msg-3')],
          previousMessageCount: 2,
          hasMoreHistory: true,
        );

        expect(resolution, HistoricalJumpResolution.loadMore);
      },
    );

    test('resolves as found after one or more historical loads', () {
      final firstStep = evaluateHistoricalJumpResolution(
        messageId: 'msg-9',
        messages: [_message('msg-1'), _message('msg-2'), _message('msg-3')],
        previousMessageCount: 2,
        hasMoreHistory: true,
      );
      final secondStep = evaluateHistoricalJumpResolution(
        messageId: 'msg-9',
        messages: [
          _message('msg-1'),
          _message('msg-2'),
          _message('msg-3'),
          _message('msg-9'),
        ],
        previousMessageCount: 3,
        hasMoreHistory: true,
      );

      expect(firstStep, HistoricalJumpResolution.loadMore);
      expect(secondStep, HistoricalJumpResolution.found);
    });

    test('reports exhaustion only when history no longer grows', () {
      final resolution = evaluateHistoricalJumpResolution(
        messageId: 'msg-9',
        messages: [_message('msg-1'), _message('msg-2')],
        previousMessageCount: 2,
        hasMoreHistory: false,
      );

      expect(resolution, HistoricalJumpResolution.exhausted);
    });

    test('keeps loading when backend still reports more history', () {
      final resolution = evaluateHistoricalJumpResolution(
        messageId: 'msg-9',
        messages: [_message('msg-1'), _message('msg-2')],
        previousMessageCount: 2,
        hasMoreHistory: true,
      );

      expect(resolution, HistoricalJumpResolution.loadMore);
    });

    test('computes rendered target index with inserted date separators', () {
      final messages = [
        _message('msg-1', createdAt: DateTime(2026, 4, 23, 9, 0)),
        _message('msg-2', createdAt: DateTime(2026, 4, 23, 8, 0)),
        _message('msg-3', createdAt: DateTime(2026, 4, 22, 18, 0)),
      ];

      expect(renderedTimelineItemCount(messages), 4);
      expect(renderedTimelineIndexForMessage('msg-1', messages), 0);
      expect(renderedTimelineIndexForMessage('msg-2', messages), 1);
      expect(renderedTimelineIndexForMessage('msg-3', messages), 3);
    });

    test('triggers older-history loading near the rendered top edge', () {
      expect(
        shouldTriggerOlderHistoryLoad(
          maxVisibleIndex: 12,
          renderedItemCount: 15,
          isLoadingMore: false,
          isResolvingHistoricalJump: false,
          hasMoreHistory: true,
        ),
        isTrue,
      );

      expect(
        shouldTriggerOlderHistoryLoad(
          maxVisibleIndex: 12,
          renderedItemCount: 15,
          isLoadingMore: false,
          isResolvingHistoricalJump: false,
          hasMoreHistory: false,
        ),
        isFalse,
      );
    });

    test('detects whether a rendered target index is actually visible', () {
      expect(
        isRenderedIndexVisible(
          targetIndex: 4,
          positions: const [
            ItemPosition(
              index: 4,
              itemLeadingEdge: 0.12,
              itemTrailingEdge: 0.42,
            ),
          ],
        ),
        isTrue,
      );

      expect(
        isRenderedIndexVisible(
          targetIndex: 4,
          positions: const [
            ItemPosition(
              index: 4,
              itemLeadingEdge: 1.02,
              itemTrailingEdge: 1.25,
            ),
          ],
        ),
        isFalse,
      );
    });
  });
}

LocalMessage _message(
  String id, {
  DateTime? createdAt,
  String type = 'text',
  String? content,
}) {
  return LocalMessage(
    id: id,
    convId: 'conv-1',
    senderId: 'user-1',
    type: type,
    content: content ?? 'message $id',
    createdAt: createdAt ?? DateTime(2026, 4, 22, 10, 0),
    status: 'sent',
    retryCount: 0,
  );
}
