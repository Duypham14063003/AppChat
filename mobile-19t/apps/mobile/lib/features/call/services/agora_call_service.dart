import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraCallService {
  late RtcEngine _engine;
  bool _isInitialized = false;

  Function(int uid)? onUserJoined;
  Function(int uid)? onUserOffline;
  VoidCallback? onLeaveChannel;

  Future<void> init(String appId) async {
    if (_isInitialized) return;

    try {
      debugPrint('[Agora] Creating engine...');
      _engine = createAgoraRtcEngine();
      
      debugPrint('[Agora] Initializing engine with appId: $appId...');
      await _engine.initialize(RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      debugPrint('[Agora] Registering event handler...');
      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint('[Agora] Join channel success: ${connection.channelId}');
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint('[Agora] User joined: $remoteUid');
            onUserJoined?.call(remoteUid);
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            debugPrint('[Agora] User offline: $remoteUid');
            onUserOffline?.call(remoteUid);
          },
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            debugPrint('[Agora] Leave channel');
            onLeaveChannel?.call();
          },
        ),
      );

      _isInitialized = true;
      debugPrint('[Agora] Init complete');
    } catch (e) {
      debugPrint('[Agora] Init Error: $e');
      rethrow;
    }
  }

  Future<void> joinChannel({
    required String token,
    required String channelId,
    required int uid,
    required bool isVideo,
  }) async {
    if (!kIsWeb) {
      debugPrint('[Agora] Requesting permissions...');
      await [Permission.microphone].request();
      if (isVideo) await [Permission.camera].request();
    } else {
      debugPrint('[Agora] Running on web, skipping permission_handler request');
    }

    try {
      debugPrint('[Agora] Enabling audio publish path...');
      await _engine.enableAudio();
      await _engine.enableLocalAudio(true);
      await _engine.muteLocalAudioStream(false);

      if (isVideo) {
        debugPrint('[Agora] Enabling video...');
        await _engine.enableVideo();
        debugPrint('[Agora] Starting preview...');
        await _engine.startPreview();
      } else {
        debugPrint('[Agora] Disabling video...');
        await _engine.disableVideo();
      }

      debugPrint('[Agora] Joining channel $channelId...');
      await _engine.joinChannel(
        token: token,
        channelId: channelId,
        uid: uid,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          publishCameraTrack: isVideo,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
      debugPrint('[Agora] Join channel called successfully');
    } catch (e) {
      debugPrint('[Agora] Join Channel Error: $e');
      rethrow;
    }
  }

  Future<void> leaveChannel() async {
    if (!_isInitialized) return;
    await _engine.leaveChannel();
    await _engine.stopPreview();
  }

  Future<void> toggleMute(bool muted) async {
    await _engine.muteLocalAudioStream(muted);
  }

  Future<void> toggleCamera(bool enabled) async {
    await _engine.enableLocalVideo(enabled);
  }

  Future<void> switchCamera() async {
    await _engine.switchCamera();
  }

  Future<void> toggleSpeakerphone(bool enabled) async {
    await _engine.setEnableSpeakerphone(enabled);
  }

  Future<void> dispose() async {
    if (_isInitialized) {
      await _engine.release();
      _isInitialized = false;
    }
  }

  RtcEngine get engine => _engine;
}
