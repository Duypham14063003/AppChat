import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/call_notifier.dart';
import '../models/call_model.dart';
import '../widgets/pulse_avatar.dart';

class OutgoingCallScreen extends ConsumerStatefulWidget {
  const OutgoingCallScreen({super.key});

  @override
  ConsumerState<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends ConsumerState<OutgoingCallScreen> {
  bool _isLeavingScreen = false;

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
    _leaveIfCallFinished(call.status);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background blur
          if (call.otherUserAvatar != null)
            Image.network(call.otherUserAvatar!, fit: BoxFit.cover),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 80),
                PulseAvatar(
                  avatarUrl: call.otherUserAvatar,
                  radius: 70,
                  pulseColor: call.status == CallStatus.busy
                      ? Colors.redAccent
                      : Colors.blueAccent,
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
                const SizedBox(height: 10),
                Text(
                  call.status == CallStatus.busy
                      ? 'Người nhận đang bận...'
                      : 'Đang gọi...',
                  style: TextStyle(
                    color: call.status == CallStatus.busy
                        ? Colors.redAccent
                        : Colors.white70,
                    fontSize: 18,
                    fontWeight: call.status == CallStatus.busy
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                const Spacer(),
                _buildCancelButton(ref),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton(WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref
          .read(callNotifierProvider.notifier)
          .endCall(userInitiated: true, source: 'outgoing_screen_hangup'),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(Icons.call_end, color: Colors.white, size: 36),
      ),
    );
  }
}
