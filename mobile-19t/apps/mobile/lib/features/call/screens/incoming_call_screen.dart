import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/call_model.dart';
import '../providers/call_notifier.dart';
import '../widgets/pulse_avatar.dart';

class IncomingCallScreen extends ConsumerStatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen> {
  bool _isLeavingScreen = false;

  void _syncRouteWithCallStatus(CallStatus status) {
    if (!mounted || _isLeavingScreen) return;
    if (status == CallStatus.active) {
      _isLeavingScreen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go('/call/active');
      });
      return;
    }

    if (_isLeavingScreen ||
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
    _syncRouteWithCallStatus(call.status);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background blur
          if (call.otherUserAvatar != null)
            Image.network(
              call.otherUserAvatar!,
              fit: BoxFit.cover,
            ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 80),
                PulseAvatar(
                  avatarUrl: call.otherUserAvatar,
                  radius: 70,
                  pulseColor: Colors.white,
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
                const Text(
                  'Cuộc gọi đến...',
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCallButton(
                      icon: Icons.call_end,
                      color: Colors.red,
                      onTap: () => ref.read(callNotifierProvider.notifier).rejectCall(),
                    ),
                    _buildCallButton(
                      icon: Icons.call,
                      color: Colors.green,
                      onTap: () => ref.read(callNotifierProvider.notifier).acceptCall(),
                    ),
                  ],
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: color, 
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 36),
      ),
    );
  }
}
