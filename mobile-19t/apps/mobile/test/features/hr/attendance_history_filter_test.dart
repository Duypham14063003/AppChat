import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/features/hr/data/hr_models.dart';
import 'package:nineteen_tech_app/features/hr/providers/hr_providers.dart';

void main() {
  group('isApprovedLeaveInMonth', () {
    final monthStart = DateTime(2026, 4, 1);
    final monthEndExclusive = DateTime(2026, 5, 1);

    test('returns true for approved leave overlapping the selected month', () {
      final leave = {
        'status': 'approved',
        'start_date': '2026-04-10',
        'end_date': '2026-04-11',
      };

      expect(
        isApprovedLeaveInMonth(leave, monthStart, monthEndExclusive),
        isTrue,
      );
    });

    test(
      'returns true for approved leave spanning into the selected month',
      () {
        final leave = {
          'status': 'approved',
          'start_date': '2026-03-31',
          'end_date': '2026-04-02',
        };

        expect(
          isApprovedLeaveInMonth(leave, monthStart, monthEndExclusive),
          isTrue,
        );
      },
    );

    test('returns false for non-approved leave even when dates overlap', () {
      final leave = {
        'status': 'submitted',
        'start_date': '2026-04-10',
        'end_date': '2026-04-11',
      };

      expect(
        isApprovedLeaveInMonth(leave, monthStart, monthEndExclusive),
        isFalse,
      );
    });

    test('returns false for approved leave outside the selected month', () {
      final leave = {
        'status': 'approved',
        'start_date': '2026-05-02',
        'end_date': '2026-05-03',
      };

      expect(
        isApprovedLeaveInMonth(leave, monthStart, monthEndExclusive),
        isFalse,
      );
    });

    test('returns false for malformed leave data', () {
      expect(
        isApprovedLeaveInMonth(
          {'status': 'approved', 'start_date': 'bad-date'},
          monthStart,
          monthEndExclusive,
        ),
        isFalse,
      );
      expect(
        isApprovedLeaveInMonth('not-a-map', monthStart, monthEndExclusive),
        isFalse,
      );
    });

    test('returns true for typed approved leave model', () {
      const leave = LeaveRequest(
        id: 'leave-1',
        type: 'annual',
        startDate: '2026-04-15',
        endDate: '2026-04-15',
        isHalfDay: false,
        status: 'approved',
      );

      expect(
        isApprovedLeaveInMonth(leave, monthStart, monthEndExclusive),
        isTrue,
      );
    });
  });
}
