import 'dart:convert';
import 'dart:math' show max;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../providers/chat_providers.dart';

class VoiceBubble extends ConsumerStatefulWidget {
  final LocalMessage message;
  final bool isMine;

  const VoiceBubble({super.key, required this.message, required this.isMine});

  @override
  ConsumerState<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends ConsumerState<VoiceBubble> {
  List<double> _waveform = [];
  double _totalDuration = 0;
  String? _audioUrl;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _parseMetadata();
  }

  void _parseMetadata() {
    if (widget.message.metadata == null) return;
    try {
      final meta = jsonDecode(widget.message.metadata!) as Map<String, dynamic>;
      _waveform = (meta['waveform'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
      _totalDuration = (meta['duration'] as num?)?.toDouble() ?? 0;
      _audioUrl = meta['url'] as String?;
      _localPath = meta['localPath'] as String?;
    } catch (_) {}
  }

  bool get _isPending => widget.message.status == 'pending';

  String _formatDuration(double seconds) {
    final mins = seconds ~/ 60;
    final secs = (seconds % 60).toInt();
    return '${mins.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
  }
// VOICE_BUBBLE_CONTINUED

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final currentlyPlaying = ref.watch(currentlyPlayingMessageProvider);
    final isThisPlaying = currentlyPlaying == widget.message.id;
    final player = ref.read(audioPlayerProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          _buildPlayButton(player, isThisPlaying),
          const SizedBox(width: 8),
          // Waveform
          Flexible(
            child: isThisPlaying
                ? StreamBuilder<Duration>(
                    stream: player.positionStream,
                    builder: (context, snapshot) {
                      final pos = snapshot.data?.inMilliseconds ?? 0;
                      final total = _totalDuration * 1000;
                      final progress = total > 0 ? pos / total : 0.0;
                      return _buildWaveform(progress);
                    },
                  )
                : _buildWaveform(0),
          ),
          const SizedBox(width: 8),
          // Duration
          isThisPlaying
              ? StreamBuilder<Duration>(
                  stream: player.positionStream,
                  builder: (context, snapshot) {
                    final pos = (snapshot.data?.inMilliseconds ?? 0) / 1000;
                    return Text(
                      _formatDuration(pos),
                      style: TextStyle(color: widget.isMine ? Colors.white70 : palette.textHint, fontSize: 12),
                    );
                  },
                )
              : Text(
                  _formatDuration(_totalDuration),
                  style: TextStyle(color: widget.isMine ? Colors.white70 : palette.textHint, fontSize: 12),
                ),
        ],
      ),
    );
  }
// VOICE_BUBBLE_PLAY_BUTTON

  Widget _buildPlayButton(AudioPlayer player, bool isThisPlaying) {
    final palette = context.appPalette;
    if (_isPending) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.isMine ? Colors.white30 : palette.textHint.withValues(alpha: 0.3),
        ),
        child: Icon(Icons.play_arrow, color: widget.isMine ? Colors.white : palette.textHint, size: 24),
      );
    }

    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final isBuffering = isThisPlaying &&
            playerState != null &&
            (playerState.processingState == ProcessingState.loading ||
                playerState.processingState == ProcessingState.buffering);

        Widget icon;
        if (isBuffering) {
          icon = SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.isMine ? palette.primary : palette.background,
            ),
          );
        } else {
          icon = Icon(
            isThisPlaying && (playerState?.playing ?? false)
                ? Icons.pause
                : Icons.play_arrow,
            color: widget.isMine ? palette.primary : palette.background,
            size: 24,
          );
        }

        return GestureDetector(
          onTap: () => _onPlayPause(player, isThisPlaying),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isMine ? Colors.white : palette.primary,
            ),
            child: Center(child: icon),
          ),
        );
      },
    );
  }

  Future<void> _onPlayPause(AudioPlayer player, bool isThisPlaying) async {
    if (isThisPlaying) {
      if (player.playing) {
        await player.pause();
      } else {
        await player.play();
      }
      return;
    }

    // Stop current and play this one
    final source = _audioUrl ?? _localPath;
    if (source == null) return;

    ref.read(currentlyPlayingMessageProvider.notifier).state = widget.message.id;

    try {
      if (source.startsWith('/') || source.startsWith('file://')) {
        await player.setFilePath(source.replaceFirst('file://', ''));
      } else {
        await player.setUrl(source);
      }
      player.play();

      // Listen for completion
      player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          player.seek(Duration.zero);
          player.pause();
          ref.read(currentlyPlayingMessageProvider.notifier).state = null;
        }
      });
    } catch (e) {
      ref.read(currentlyPlayingMessageProvider.notifier).state = null;
    }
  }
// VOICE_BUBBLE_WAVEFORM

  Widget _buildWaveform(double progress) {
    final palette = context.appPalette;
    final playedColor = widget.isMine ? Colors.white : palette.primary;
    final unplayedColor = widget.isMine ? Colors.white30 : palette.textHint.withValues(alpha: 0.3);

    if (_waveform.isEmpty) {
      // Placeholder flat bars
      return SizedBox(
        height: 32,
        width: 120,
        child: CustomPaint(painter: _WaveformPainter(
          waveform: List.filled(30, 0.3),
          progress: progress,
          playedColor: playedColor,
          unplayedColor: unplayedColor,
        )),
      );
    }
    return SizedBox(
      height: 32,
      width: 120,
      child: CustomPaint(painter: _WaveformPainter(
        waveform: _waveform,
        progress: progress,
        playedColor: playedColor,
        unplayedColor: unplayedColor,
      )),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> waveform;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;

  _WaveformPainter({
    required this.waveform,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) return;
    const barWidth = 2.0;
    const gap = 2.0;
    const totalBarWidth = barWidth + gap;
    final barCount = (size.width / totalBarWidth).floor();
    final samples = _resample(waveform, barCount);
    final progressIndex = (progress * barCount).floor();

    for (int i = 0; i < samples.length; i++) {
      final x = i * totalBarWidth;
      final barHeight = max(4.0, samples[i] * (size.height - 4)) + 4;
      final y = (size.height - barHeight) / 2;
      final paint = Paint()
        ..color = i < progressIndex ? playedColor : unplayedColor
        ..strokeCap = StrokeCap.round;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  List<double> _resample(List<double> data, int count) {
    if (count <= 0) return [];
    if (data.length == count) return data;
    final result = <double>[];
    for (int i = 0; i < count; i++) {
      final idx = (i * data.length / count).floor().clamp(0, data.length - 1);
      result.add(data[idx].clamp(0.0, 1.0));
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.waveform != waveform;
}