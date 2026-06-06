import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../theme/app_colors.dart';

class PremiumVoiceBubble extends StatefulWidget {
  final String audioUrl;
  final bool isMe;

  const PremiumVoiceBubble({
    super.key,
    required this.audioUrl,
    required this.isMe,
  });

  @override
  State<PremiumVoiceBubble> createState() => _PremiumVoiceBubbleState();
}

class _PremiumVoiceBubbleState extends State<PremiumVoiceBubble> {
  late final AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackSpeed = 1.0;

  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _completeSub;

  // Static heights for a realistic audio waveform look (24 bars)
  static const List<double> _waveHeights = [
    6, 12, 18, 10, 14, 22, 16, 8,
    14, 20, 12, 18, 24, 16, 10, 14,
    22, 12, 8, 14, 18, 10, 12, 6
  ];

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    // Set initial source
    _audioPlayer.setSourceUrl(widget.audioUrl).catchError((e) {
      debugPrint('[DEBUG] Audio source error: $e');
    });

    _durationSub = _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) {
        setState(() {
          _duration = d;
        });
      }
    });

    _positionSub = _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) {
        setState(() {
          _position = p;
        });
      }
    });

    _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _completeSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _position = Duration.zero;
          _isPlaying = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _completeSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play(UrlSource(widget.audioUrl));
        await _audioPlayer.setPlaybackRate(_playbackSpeed);
      }
    } catch (e) {
      debugPrint('[DEBUG] Play/Pause error: $e');
    }
  }

  void _toggleSpeed() {
    double nextSpeed;
    if (_playbackSpeed == 1.0) {
      nextSpeed = 1.5;
    } else if (_playbackSpeed == 1.5) {
      nextSpeed = 2.0;
    } else {
      nextSpeed = 1.0;
    }

    setState(() {
      _playbackSpeed = nextSpeed;
    });

    if (_isPlaying) {
      _audioPlayer.setPlaybackRate(nextSpeed);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final totalBars = _waveHeights.length;
    
    // Calculate progress percentage
    double progressPercent = 0.0;
    if (_duration.inMilliseconds > 0) {
      progressPercent = _position.inMilliseconds / _duration.inMilliseconds;
    }
    progressPercent = progressPercent.clamp(0.0, 1.0);
    
    final activeBars = (progressPercent * totalBars).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 260),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isMe
                    ? Colors.white.withOpacity(0.15)
                    : AppColors.primaryPurple.withOpacity(0.15),
                border: Border.all(
                  color: widget.isMe
                      ? Colors.white.withOpacity(0.2)
                      : AppColors.primaryPurple.withOpacity(0.2),
                ),
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: widget.isMe ? Colors.white : AppColors.primaryPurple,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Soundwave Visualization & Duration text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform bars
                SizedBox(
                  height: 24,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(totalBars, (index) {
                      final isActive = index < activeBars;
                      final barHeight = _waveHeights[index];
                      return Container(
                        width: 3,
                        height: barHeight,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(1.5),
                          color: isActive
                              ? (widget.isMe ? Colors.white : AppColors.primaryPurple)
                              : (widget.isMe
                                  ? Colors.white.withOpacity(0.25)
                                  : Colors.white.withOpacity(0.4)),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 4),
                // Duration & Progress indicator
                Text(
                  _isPlaying
                      ? '${_formatDuration(_position)} / ${_formatDuration(_duration)}'
                      : _duration != Duration.zero
                          ? _formatDuration(_duration)
                          : '0:00',
                  style: GoogleFonts.outfit(
                    color: widget.isMe
                        ? Colors.white.withOpacity(0.7)
                        : Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Speed Control Button (1x, 1.5x, 2x)
          GestureDetector(
            onTap: _toggleSpeed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: widget.isMe
                    ? Colors.white.withOpacity(0.15)
                    : AppColors.primaryPurple.withOpacity(0.15),
                border: Border.all(
                  color: widget.isMe
                      ? Colors.white.withOpacity(0.2)
                      : AppColors.primaryPurple.withOpacity(0.2),
                ),
              ),
              child: Text(
                '${_playbackSpeed.toStringAsFixed(1).replaceFirst('.0', '')}x',
                style: GoogleFonts.outfit(
                  color: widget.isMe ? Colors.white : AppColors.primaryPurple,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
