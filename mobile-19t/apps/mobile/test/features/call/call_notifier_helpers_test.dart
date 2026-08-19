import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/features/auth/data/secure_token_storage.dart';
import 'package:nineteen_tech_app/features/auth/providers/auth_notifier.dart';
import 'package:nineteen_tech_app/features/call/models/call_model.dart';
import 'package:nineteen_tech_app/features/call/providers/agora_provider.dart';
import 'package:nineteen_tech_app/features/call/providers/call_notifier.dart';
import 'package:nineteen_tech_app/features/call/services/agora_call_service.dart';
import 'package:nineteen_tech_app/features/call/services/call_api_service.dart';
import 'package:nineteen_tech_app/features/call/services/callkit_service.dart';

void main() {
  group('shouldEndCancelledOutgoingCall', () {
    test('requires explicit caller hangup after outgoing state changed', () {
      expect(
        shouldEndCancelledOutgoingCall(
          currentStatus: CallStatus.idle,
          callerHangupRequestedWhileStarting: true,
        ),
        isTrue,
      );
    });

    test(
      'does not end backend call when startCall returns without hangup intent',
      () {
        expect(
          shouldEndCancelledOutgoingCall(
            currentStatus: CallStatus.idle,
            callerHangupRequestedWhileStarting: false,
          ),
          isFalse,
        );
      },
    );

    test('does not end backend call while caller is still outgoing', () {
      expect(
        shouldEndCancelledOutgoingCall(
          currentStatus: CallStatus.outgoing,
          callerHangupRequestedWhileStarting: true,
        ),
        isFalse,
      );
    });
  });

  group('shouldIgnoreIncomingCallPresentation', () {
    test('suppresses late invite for processed call id', () {
      expect(
        shouldIgnoreIncomingCallPresentation(
          processedCallIds: {'call-1'},
          status: CallStatus.idle,
          currentCallId: null,
          incomingCallId: 'call-1',
        ),
        isTrue,
      );
    });

    test('suppresses duplicate presentation while already in another call', () {
      expect(
        shouldIgnoreIncomingCallPresentation(
          processedCallIds: const {},
          status: CallStatus.active,
          currentCallId: 'call-1',
          incomingCallId: 'call-2',
        ),
        isTrue,
      );
    });

    test('allows new unrelated call after prior call was processed', () {
      expect(
        shouldIgnoreIncomingCallPresentation(
          processedCallIds: {'call-1'},
          status: CallStatus.idle,
          currentCallId: null,
          incomingCallId: 'call-2',
        ),
        isFalse,
      );
    });
  });

  group('shouldIgnoreNativeCallKitEndedEvent', () {
    test('ignores locally initiated native teardown events', () {
      expect(
        shouldIgnoreNativeCallKitEndedEvent(
          locallyClosedCallIds: {'call-1'},
          status: CallStatus.outgoing,
          currentCallId: 'call-1',
          endedCallId: 'call-1',
        ),
        isTrue,
      );
    });

    test('ignores non-user native ended event for active outgoing call', () {
      expect(
        shouldIgnoreNativeCallKitEndedEvent(
          locallyClosedCallIds: const {},
          status: CallStatus.outgoing,
          currentCallId: 'call-1',
          endedCallId: 'call-1',
        ),
        isTrue,
      );
    });
  });

  group('findOwnedCallKitCallForRestore', () {
    test('returns first app-owned call when no event id is provided', () {
      final ownedCall = {
        'id': 'native-1',
        'extra': buildAppOwnedCallKitExtra(
          callId: 'business-1',
          nativeCallId: 'native-1',
          callDirection: 'incoming',
        ),
      };

      expect(
        findOwnedCallKitCallForRestore(
          activeCalls: [
            {
              'id': 'foreign-1',
              'extra': const {'callDirection': 'incoming'},
            },
            ownedCall,
          ],
        ),
        equals(ownedCall),
      );
    });

    test('matches app-owned call by native id or business id', () {
      final ownedCall = {
        'id': 'native-2',
        'extra': buildAppOwnedCallKitExtra(
          callId: 'business-2',
          nativeCallId: 'native-2',
          callDirection: 'incoming',
        ),
      };

      expect(
        findOwnedCallKitCallForRestore(
          activeCalls: [ownedCall],
          eventCallId: 'business-2',
        ),
        equals(ownedCall),
      );

      expect(
        findOwnedCallKitCallForRestore(
          activeCalls: [ownedCall],
          eventCallId: 'native-2',
        ),
        equals(ownedCall),
      );
    });

    test('ignores foreign native calls and removes first-call fallback', () {
      expect(
        findOwnedCallKitCallForRestore(
          activeCalls: [
            {
              'id': 'foreign-2',
              'extra': {
                'callId': 'foreign-business',
                'callDirection': 'incoming',
              },
            },
          ],
          eventCallId: 'foreign-2',
        ),
        isNull,
      );
    });

    test(
      'keeps state idle when checkInitialCall sees only foreign native calls',
      () async {
        final container = ProviderContainer(
          overrides: [
            secureTokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
            callKitServiceProvider.overrideWithValue(
              _FakeCallKitService(
                activeCalls: [
                  {
                    'id': 'foreign-3',
                    'extra': {
                      'callId': 'foreign-business',
                      'callDirection': 'incoming',
                    },
                  },
                ],
              ),
            ),
            callApiServiceProvider.overrideWithValue(CallApiService(Dio())),
            agoraCallServiceProvider.overrideWithValue(AgoraCallService()),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(callNotifierProvider.notifier);

        await notifier.checkInitialCall();

        final state = container.read(callNotifierProvider);
        expect(state.status, CallStatus.idle);
        expect(state.callId, isNull);
      },
    );
  });
}

class _FakeTokenStorage extends SecureTokenStorage {
  _FakeTokenStorage() : super(null, false);

  @override
  Future<String?> getAccessToken() async => 'token';
}

class _FakeCallKitService extends CallKitService {
  _FakeCallKitService({required List<dynamic> activeCalls})
    : _activeCalls = activeCalls;

  final List<dynamic> _activeCalls;

  @override
  Future<void> setupListeners() async {}

  @override
  Future<List<dynamic>> getActiveCalls() async => _activeCalls;
}
