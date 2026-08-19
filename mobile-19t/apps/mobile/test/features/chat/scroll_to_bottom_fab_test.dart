import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/features/chat/screens/chat_screen.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

void main() {
  group('scroll-to-bottom FAB visibility helpers', () {
    test(
      'treats the chat as near bottom when the latest message is fully visible',
      () {
        const positions = [
          ItemPosition(index: 0, itemLeadingEdge: 0.82, itemTrailingEdge: 1.0),
          ItemPosition(index: 1, itemLeadingEdge: 0.64, itemTrailingEdge: 0.8),
        ];

        expect(isChatNearBottom(positions), isTrue);
        expect(shouldShowScrollToBottomFab(positions), isFalse);
      },
    );

    test(
      'keeps the FAB hidden when the latest message is only slightly clipped',
      () {
        const positions = [
          ItemPosition(index: 0, itemLeadingEdge: 0.92, itemTrailingEdge: 1.08),
          ItemPosition(index: 1, itemLeadingEdge: 0.7, itemTrailingEdge: 0.9),
        ];

        expect(isChatNearBottom(positions), isTrue);
        expect(shouldShowScrollToBottomFab(positions), isFalse);
      },
    );

    test(
      'shows the FAB after the latest message moves beyond the threshold',
      () {
        const positions = [
          ItemPosition(index: 0, itemLeadingEdge: 1.0, itemTrailingEdge: 1.2),
          ItemPosition(index: 1, itemLeadingEdge: 0.78, itemTrailingEdge: 0.98),
        ];

        expect(isChatNearBottom(positions), isFalse);
        expect(shouldShowScrollToBottomFab(positions), isTrue);
      },
    );

    test('shows the FAB when the latest message is no longer visible', () {
      const positions = [
        ItemPosition(index: 2, itemLeadingEdge: 0.1, itemTrailingEdge: 0.3),
        ItemPosition(index: 3, itemLeadingEdge: 0.32, itemTrailingEdge: 0.5),
      ];

      expect(isChatNearBottom(positions), isFalse);
      expect(shouldShowScrollToBottomFab(positions), isTrue);
    });
  });
}
