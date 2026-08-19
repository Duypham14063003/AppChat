import 'dart:async';
import 'dart:ui';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/call_model.dart';
import '../providers/call_notifier.dart';
import '../providers/agora_provider.dart';
import '../widgets/pulse_avatar.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _showControls = true;
  bool _isSpeakerOn = false;

  Timer? _timer;
  int _durationSeconds = 0;
  Timer? _hideControlsTimer;
  bool _isLeavingScreen = false;

  @override
  void initState() {
    super.initState();
    // Giữ màn hình & CPU không ngủ trong khi đang gọi
    WakelockPlus.enable();
    _startTimer();
    _startHideControlsTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _durationSeconds++);
      }
    });
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _showControls) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideControlsTimer();
    }
  }

  @override
  void dispose() {
    // Tắt WakeLock khi rời màn hình gọi
    WakelockPlus.disable();
    _timer?.cancel();
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  String get _formattedDuration {
    final minutes = (_durationSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_durationSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _leaveIfCallFinished(CallStatus status) {
    if (_isLeavingScreen ||
        !mounted ||
        (status != CallStatus.idle && status != CallStatus.ended)) {
      return;
    }
    _isLeavingScreen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go('/chat');
    });
  }

  @override
  Widget build(BuildContext context) {
    final call = ref.watch(callNotifierProvider);
    final agora = ref.watch(agoraCallServiceProvider);
    _leaveIfCallFinished(call.status);

    final bool hasRemoteVideo = call.isVideo && call.remoteUid != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Background Blur (nếu không có remote video)
            if (!hasRemoteVideo && call.otherUserAvatar != null)
              Image.network(call.otherUserAvatar!, fit: BoxFit.cover),
            if (!hasRemoteVideo)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(color: Colors.black.withOpacity(0.5)),
              ),

            // 2. Remote Video / Avatar
            if (hasRemoteVideo)
              AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: agora.engine,
                  canvas: VideoCanvas(uid: call.remoteUid),
                  connection: RtcConnection(
                    channelId: call.channelName ?? call.callId,
                  ),
                ),
              )
            else
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PulseAvatar(
                    avatarUrl: call.otherUserAvatar,
                    radius: 80,
                    pulseColor: Colors.white24, // Slow/subtle pulse for active
                  ),
                  const SizedBox(height: 30),
                  Text(
                    call.otherUserName ?? 'Người dùng',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

            // 3. Local Video (Góc màn hình)
            if (call.isVideo && _isVideoEnabled)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 20,
                right: 20,
                width: 100,
                height: 150,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white38, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: agora.engine,
                        canvas: const VideoCanvas(uid: 0),
                      ),
                    ),
                  ),
                ),
              ),

            // 4. Timer (Glassmorphism top bar)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 20,
              left: 20,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _showControls ? 1.0 : 0.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formattedDuration,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 5. Controls Bottom Bar
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _showControls ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildControlButton(
                              icon: _isMuted ? Icons.mic_off : Icons.mic,
                              onTap: () {
                                setState(() => _isMuted = !_isMuted);
                                agora.toggleMute(_isMuted);
                                _startHideControlsTimer();
                              },
                            ),
                            if (call.isVideo)
                              _buildControlButton(
                                icon: _isVideoEnabled
                                    ? Icons.videocam
                                    : Icons.videocam_off,
                                onTap: () {
                                  setState(
                                    () => _isVideoEnabled = !_isVideoEnabled,
                                  );
                                  agora.toggleCamera(_isVideoEnabled);
                                  _startHideControlsTimer();
                                },
                              ),
                            if (call.isVideo)
                              _buildControlButton(
                                icon: Icons.switch_camera,
                                onTap: () {
                                  agora.switchCamera();
                                  _startHideControlsTimer();
                                },
                              ),
                            _buildControlButton(
                              icon: _isSpeakerOn
                                  ? Icons.volume_up
                                  : Icons.volume_down,
                              iconColor: _isSpeakerOn
                                  ? Colors.blueAccent
                                  : Colors.white,
                              onTap: () {
                                setState(() => _isSpeakerOn = !_isSpeakerOn);
                                agora.toggleSpeakerphone(_isSpeakerOn);
                                _startHideControlsTimer();
                              },
                            ),
                            _buildControlButton(
                              icon: Icons.call_end,
                              color: Colors.red,
                              iconColor: Colors.white,
                              onTap: () => ref
                                  .read(callNotifierProvider.notifier)
                                  .endCall(
                                    userInitiated: true,
                                    source: 'active_call_screen_hangup',
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    Color color = Colors.white24,
    Color iconColor = Colors.white,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 28),
      ),
    );
  }
}
