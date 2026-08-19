import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/features/call/services/callkit_service.dart';

void main() {
  group('CallKit ownership helpers', () {
    test('buildAppOwnedCallKitExtra adds ownership marker and ids', () {
      final extra = buildAppOwnedCallKitExtra(
        callId: 'call-1',
        nativeCallId: 'native-1',
        callDirection: 'incoming',
      );

      expect(extra[callKitAppSourceKey], callKitAppSourceValue);
      expect(extra[callKitBusinessCallIdKey], 'call-1');
      expect(extra[callKitNativeCallIdKey], 'native-1');
      expect(extra[callKitDirectionKey], 'incoming');
    });

    test(
      'buildAppOwnedCallKitExtra prevents raw payload from overriding ownership keys',
      () {
        final extra = buildAppOwnedCallKitExtra(
          callId: 'call-override',
          nativeCallId: 'native-override',
          callDirection: 'incoming',
          extra: const {
            callKitAppSourceKey: 'foreign',
            callKitBusinessCallIdKey: 'bad-call',
            callKitNativeCallIdKey: 'bad-native',
            callKitDirectionKey: 'sideways',
          },
        );

        expect(extra[callKitAppSourceKey], callKitAppSourceValue);
        expect(extra[callKitBusinessCallIdKey], 'call-override');
        expect(extra[callKitNativeCallIdKey], 'native-override');
        expect(extra[callKitDirectionKey], 'incoming');
      },
    );

    test(
      'isAppOwnedCallKitExtra requires marker, business id, and direction',
      () {
        expect(
          isAppOwnedCallKitExtra(
            buildAppOwnedCallKitExtra(
              callId: 'call-2',
              nativeCallId: 'native-2',
              callDirection: 'incoming',
            ),
          ),
          isTrue,
        );

        expect(
          isAppOwnedCallKitExtra(const {
            callKitBusinessCallIdKey: 'call-2',
            callKitDirectionKey: 'incoming',
          }),
          isFalse,
        );
      },
    );

    test('isAppOwnedCallKitCall ignores foreign native payloads', () {
      expect(
        isAppOwnedCallKitCall({
          'id': 'native-3',
          'extra': buildAppOwnedCallKitExtra(
            callId: 'call-3',
            nativeCallId: 'native-3',
            callDirection: 'incoming',
          ),
        }),
        isTrue,
      );

      expect(
        isAppOwnedCallKitCall({
          'id': 'foreign-3',
          'extra': const {
            callKitBusinessCallIdKey: 'call-3',
            callKitDirectionKey: 'incoming',
          },
        }),
        isFalse,
      );
    });

    test('shouldHandleOwnedCallKitEvent rejects foreign event payloads', () {
      expect(
        shouldHandleOwnedCallKitEvent({
          'id': 'foreign-native',
          'extra': const {
            callKitBusinessCallIdKey: 'foreign-call',
            callKitDirectionKey: 'incoming',
          },
        }),
        isFalse,
      );
    });

    test('shouldHandleOwnedCallKitEvent accepts app-owned event payloads', () {
      expect(
        shouldHandleOwnedCallKitEvent({
          'id': 'native-4',
          'extra': buildAppOwnedCallKitExtra(
            callId: 'call-4',
            nativeCallId: 'native-4',
            callDirection: 'incoming',
          ),
        }),
        isTrue,
      );
    });

    test(
      'resolveIncomingPushCallId falls back to id when call_id is absent',
      () {
        expect(
          resolveIncomingPushCallId({'id': 'business-id-from-push'}),
          'business-id-from-push',
        );
      },
    );
  });
}
