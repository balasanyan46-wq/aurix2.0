import 'dart:async';
import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'track_player_web.dart' if (dart.library.io) 'track_player_stub.dart';

/// Inline audio player for a single track.
class TrackPlayer extends StatefulWidget {
  const TrackPlayer({super.key, required this.url});
  final String url;

  @override
  State<TrackPlayer> createState() => _TrackPlayerState();
}

class _TrackPlayerState extends State<TrackPlayer> {
  late final AudioHandle _audio;
  bool _playing = false;
  double _progress = 0;
  double _duration = 0;
  bool _error = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _audio = createAudioHandle(widget.url);
    _audio.onEnded = () {
      if (mounted) setState(() { _playing = false; _progress = 0; });
      _ticker?.cancel();
    };
    _audio.onError = () {
      if (mounted) setState(() => _error = true);
    };
    _audio.onCanPlay = () {
      if (mounted) setState(() => _duration = _audio.duration);
    };
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _audio.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_error) return;
    if (_playing) {
      _audio.pause();
      _ticker?.cancel();
      setState(() => _playing = false);
    } else {
      _audio.play();
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted) return;
        setState(() {
          _progress = _audio.currentTime;
          _duration = _audio.duration;
        });
      });
      setState(() => _playing = true);
    }
  }

  void _seek(double value) {
    _audio.seekTo(value);
    setState(() => _progress = value);
  }

  String _formatTime(double s) {
    if (s.isNaN || s.isInfinite || s <= 0) return '0:00';
    final m = s ~/ 60;
    final sec = (s % 60).toInt();
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: AurixTokens.danger.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 16, color: AurixTokens.danger.withValues(alpha: 0.6)),
            const SizedBox(width: 8),
            Text('Не удалось загрузить аудио', style: TextStyle(color: AurixTokens.danger.withValues(alpha: 0.7), fontSize: 12)),
          ],
        ),
      );
    }

    return Row(
      children: [
        GestureDetector(
          onTap: _toggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _playing
                  ? AurixTokens.orange.withValues(alpha: 0.15)
                  : AurixTokens.glass(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _playing
                    ? AurixTokens.orange.withValues(alpha: 0.3)
                    : AurixTokens.stroke(0.15),
              ),
            ),
            child: Icon(
              _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 18,
              color: _playing ? AurixTokens.orange : AurixTokens.muted,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _formatTime(_progress),
          style: TextStyle(
            color: AurixTokens.muted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            fontFeatures: AurixTokens.tabularFigures,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: AurixTokens.orange,
              inactiveTrackColor: AurixTokens.glass(0.12),
              thumbColor: AurixTokens.orange,
              overlayColor: AurixTokens.orange.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: _duration > 0 ? _progress.clamp(0, _duration) : 0,
              max: _duration > 0 ? _duration : 1,
              onChanged: _duration > 0 ? _seek : null,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formatTime(_duration),
          style: TextStyle(
            color: AurixTokens.muted.withValues(alpha: 0.6),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            fontFeatures: AurixTokens.tabularFigures,
          ),
        ),
      ],
    );
  }
}
