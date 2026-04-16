import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'package:aurix_flutter/design/aurix_theme.dart';

/// Minimal premium waveform player for the result screen.
class ResultPlayer extends StatefulWidget {
  final String blobUrl;
  final Float32List? waveformData;

  const ResultPlayer({
    super.key,
    required this.blobUrl,
    this.waveformData,
  });

  @override
  State<ResultPlayer> createState() => _ResultPlayerState();
}

class _ResultPlayerState extends State<ResultPlayer>
    with SingleTickerProviderStateMixin {
  web.HTMLAudioElement? _audio;
  bool _playing = false;
  double _progress = 0;
  double _duration = 0;
  Timer? _ticker;

  late AnimationController _playBounce;

  @override
  void initState() {
    super.initState();
    _playBounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );

    _audio = web.HTMLAudioElement()..src = widget.blobUrl;
    _audio!.addEventListener(
      'loadedmetadata',
      ((JSAny _) {
        if (mounted) setState(() => _duration = _audio!.duration);
      }).toJS,
    );
    _audio!.addEventListener(
      'ended',
      ((JSAny _) {
        if (mounted) {
          setState(() {
            _playing = false;
            _progress = 0;
          });
          _ticker?.cancel();
        }
      }).toJS,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _audio?.pause();
    _playBounce.dispose();
    super.dispose();
  }

  void _toggle() {
    _playBounce.forward(from: 0);
    if (_playing) {
      _audio?.pause();
      _ticker?.cancel();
      setState(() => _playing = false);
    } else {
      _audio?.play();
      setState(() => _playing = true);
      _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (!mounted || _audio == null) return;
        final cur = _audio!.currentTime;
        final dur = _audio!.duration;
        if (dur > 0 && !dur.isNaN) {
          setState(() => _progress = (cur / dur).clamp(0.0, 1.0));
        }
      });
    }
  }

  void _seek(double ratio) {
    if (_audio == null || _duration == 0) return;
    _audio!.currentTime = ratio * _duration;
    setState(() => _progress = ratio.clamp(0.0, 1.0));
  }

  String _fmt(double s) {
    if (s.isNaN || s.isInfinite) return '0:00';
    final min = s ~/ 60;
    final sec = (s % 60).toInt();
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AurixTokens.s20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
        color: AurixTokens.surface1.withValues(alpha: 0.45),
        border: Border.all(color: AurixTokens.stroke(0.14)),
      ),
      child: Column(
        children: [
          // Waveform
          GestureDetector(
            onTapDown: (d) {
              final box = context.findRenderObject() as RenderBox;
              final ratio = d.localPosition.dx / box.size.width;
              _seek(ratio);
            },
            child: SizedBox(
              height: 64,
              width: double.infinity,
              child: CustomPaint(
                painter: _ResultWaveformPainter(
                  data: widget.waveformData,
                  progress: _progress,
                ),
              ),
            ),
          ),
          const SizedBox(height: AurixTokens.s16),

          // Controls
          Row(
            children: [
              AnimatedBuilder(
                animation: _playBounce,
                builder: (context, child) {
                  final s = 1.0 - _playBounce.value * 0.08;
                  return Transform.scale(scale: s, child: child);
                },
                child: GestureDetector(
                  onTap: _toggle,
                  child: AnimatedContainer(
                    duration: AurixTokens.dMedium,
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _playing
                          ? AurixTokens.accent.withValues(alpha: 0.15)
                          : AurixTokens.accent,
                      border: Border.all(
                        color: AurixTokens.accent
                            .withValues(alpha: _playing ? 0.4 : 0),
                        width: 1.5,
                      ),
                      boxShadow: _playing
                          ? null
                          : [
                              BoxShadow(
                                color: AurixTokens.accent
                                    .withValues(alpha: 0.25),
                                blurRadius: 16,
                                spreadRadius: -4,
                              ),
                            ],
                    ),
                    child: Icon(
                      _playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: _playing ? AurixTokens.accent : Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AurixTokens.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        height: 4,
                        child: LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: AurixTokens.surface2,
                          valueColor: AlwaysStoppedAnimation(
                              AurixTokens.accent.withValues(alpha: 0.7)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmt(_progress * _duration),
                            style: TextStyle(
                                fontFamily: AurixTokens.fontMono,
                                fontSize: 11,
                                color: AurixTokens.muted,
                                fontFeatures: AurixTokens.tabularFigures)),
                        Text(_fmt(_duration),
                            style: TextStyle(
                                fontFamily: AurixTokens.fontMono,
                                fontSize: 11,
                                color: AurixTokens.micro,
                                fontFeatures: AurixTokens.tabularFigures)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultWaveformPainter extends CustomPainter {
  final Float32List? data;
  final double progress;

  _ResultWaveformPainter({this.data, this.progress = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final samples = data;
    final midY = size.height / 2;

    if (samples == null || samples.isEmpty) {
      final rng = math.Random(42);
      const count = 80;
      final barW = size.width / count;
      final playedIdx = (count * progress).toInt();
      for (int i = 0; i < count; i++) {
        final x = i * barW + barW / 2;
        final h = (0.15 + rng.nextDouble() * 0.7) * size.height * 0.4;
        final paint = Paint()
          ..color = i <= playedIdx
              ? AurixTokens.accent.withValues(alpha: 0.5)
              : AurixTokens.border.withValues(alpha: 0.3)
          ..strokeWidth = math.max(1.5, barW * 0.5)
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(x, midY - h), Offset(x, midY + h), paint);
      }
      return;
    }

    final barW = size.width / samples.length;
    final playedIdx = (samples.length * progress).toInt();
    for (int i = 0; i < samples.length; i++) {
      final x = i * barW + barW / 2;
      final h = samples[i] * size.height * 0.42;
      final played = i <= playedIdx;
      final paint = Paint()
        ..color = played
            ? AurixTokens.accent.withValues(alpha: 0.55)
            : AurixTokens.border.withValues(alpha: 0.25)
        ..strokeWidth = math.max(1.5, barW * 0.55)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x, midY - h), Offset(x, midY + h), paint);
    }
  }

  @override
  bool shouldRepaint(_ResultWaveformPainter old) =>
      old.data != data || old.progress != progress;
}
