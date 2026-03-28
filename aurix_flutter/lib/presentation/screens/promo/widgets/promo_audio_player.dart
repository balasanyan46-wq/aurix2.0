import 'dart:async';
import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/presentation/screens/releases/widgets/track_player_web.dart'
    if (dart.library.io) 'package:aurix_flutter/presentation/screens/releases/widgets/track_player_stub.dart';

/// Full-featured audio player with waveform-style progress.
class PromoAudioPlayer extends StatefulWidget {
  final String url;
  final String title;
  final ValueChanged<double>? onPositionChanged;
  final ValueChanged<double>? onDurationKnown;

  const PromoAudioPlayer({
    super.key,
    required this.url,
    required this.title,
    this.onPositionChanged,
    this.onDurationKnown,
  });

  @override
  State<PromoAudioPlayer> createState() => PromoAudioPlayerState();
}

class PromoAudioPlayerState extends State<PromoAudioPlayer> {
  late AudioHandle _audio;
  bool _playing = false;
  double _position = 0;
  double _duration = 0;
  bool _error = false;
  Timer? _ticker;

  double get position => _position;
  double get duration => _duration;
  bool get isPlaying => _playing;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  void _initAudio() {
    _audio = createAudioHandle(widget.url);
    _audio.onEnded = () {
      if (mounted) setState(() { _playing = false; _position = 0; });
      _ticker?.cancel();
    };
    _audio.onError = () {
      if (mounted) setState(() => _error = true);
    };
    _audio.onCanPlay = () {
      if (!mounted) return;
      final d = _audio.duration;
      setState(() => _duration = d);
      widget.onDurationKnown?.call(d);
    };
  }

  @override
  void didUpdateWidget(covariant PromoAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _ticker?.cancel();
      _audio.dispose();
      setState(() { _playing = false; _position = 0; _duration = 0; _error = false; });
      _initAudio();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _audio.dispose();
    super.dispose();
  }

  void toggle() {
    if (_error) return;
    if (_playing) {
      _audio.pause();
      _ticker?.cancel();
      setState(() => _playing = false);
    } else {
      _audio.play();
      _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted) return;
        final pos = _audio.currentTime;
        setState(() => _position = pos);
        widget.onPositionChanged?.call(pos);
      });
      setState(() => _playing = true);
    }
  }

  void seekTo(double t) {
    _audio.seekTo(t);
    setState(() => _position = t);
  }

  String _fmt(double s) {
    if (s.isNaN || s.isInfinite || s <= 0) return '0:00';
    final m = s ~/ 60;
    final sec = (s % 60).toInt();
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AurixTokens.danger.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AurixTokens.danger.withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          Icon(Icons.error_outline, size: 20, color: AurixTokens.danger.withValues(alpha: 0.6)),
          const SizedBox(width: 10),
          const Text('Не удалось загрузить аудио', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AurixTokens.stroke(0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(
            onTap: toggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _playing
                    ? AurixTokens.accent.withValues(alpha: 0.15)
                    : AurixTokens.glass(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _playing
                      ? AurixTokens.accent.withValues(alpha: 0.3)
                      : AurixTokens.stroke(0.12),
                ),
              ),
              child: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 24,
                color: _playing ? AurixTokens.accent : AurixTokens.text,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title, style: const TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text('${_fmt(_position)} / ${_fmt(_duration)}',
                  style: TextStyle(color: AurixTokens.muted, fontSize: 12, fontFeatures: AurixTokens.tabularFigures)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: AurixTokens.accent,
            inactiveTrackColor: AurixTokens.glass(0.12),
            thumbColor: AurixTokens.accent,
            overlayColor: AurixTokens.accent.withValues(alpha: 0.12),
          ),
          child: Slider(
            value: _duration > 0 ? _position.clamp(0, _duration) : 0,
            max: _duration > 0 ? _duration : 1,
            onChanged: _duration > 0 ? seekTo : null,
          ),
        ),
      ]),
    );
  }
}
