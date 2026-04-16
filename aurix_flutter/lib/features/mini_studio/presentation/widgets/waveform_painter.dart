import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

/// Static waveform painter — draws the beat waveform as a background.
class BeatWaveformPainter extends CustomPainter {
  final Float32List? data;
  final double progress; // 0..1 playback progress
  final Color color;

  BeatWaveformPainter({
    this.data,
    this.progress = 0,
    this.color = const Color(0xFF2A2A40),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data == null || data!.isEmpty) return;

    final samples = data!;
    final barWidth = size.width / samples.length;
    final midY = size.height / 2;

    final playedPaint = Paint()
      ..color = AurixTokens.accent.withValues(alpha: 0.35)
      ..strokeCap = StrokeCap.round;

    final unplayedPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeCap = StrokeCap.round;

    final playedIdx = (samples.length * progress).toInt();

    for (int i = 0; i < samples.length; i++) {
      final x = i * barWidth + barWidth / 2;
      final amp = samples[i] * size.height * 0.4;
      final paint = i <= playedIdx ? playedPaint : unplayedPaint;
      paint.strokeWidth = math.max(1.5, barWidth * 0.6);
      canvas.drawLine(
        Offset(x, midY - amp),
        Offset(x, midY + amp),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(BeatWaveformPainter old) =>
      old.data != data || old.progress != progress;
}

/// Live waveform painter — real-time audio visualization.
class LiveWaveformPainter extends CustomPainter {
  final Float32List? data;
  final Color color;
  final double strokeWidth;

  LiveWaveformPainter({
    this.data,
    this.color = const Color(0xFFFF6A1A),
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data == null || data!.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final samples = data!;
    final step = samples.length / size.width;
    final midY = size.height / 2;

    for (int i = 0; i < size.width.toInt(); i++) {
      final idx = (i * step).toInt().clamp(0, samples.length - 1);
      final y = midY + samples[idx] * size.height * 0.45;
      if (i == 0) {
        path.moveTo(i.toDouble(), y);
      } else {
        path.lineTo(i.toDouble(), y);
      }
    }

    // Glow effect
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..strokeWidth = strokeWidth + 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(LiveWaveformPainter old) => true; // always repaint for live data
}

/// Combined waveform display widget with beat background + live vocal overlay.
class WaveformView extends StatelessWidget {
  final Float32List? beatStaticWaveform;
  final Float32List? liveWaveform;
  final double progress;
  final double height;

  const WaveformView({
    super.key,
    this.beatStaticWaveform,
    this.liveWaveform,
    this.progress = 0,
    this.height = 140,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        children: [
          // Beat waveform (background)
          Positioned.fill(
            child: CustomPaint(
              painter: BeatWaveformPainter(
                data: beatStaticWaveform,
                progress: progress,
              ),
            ),
          ),
          // Live vocal waveform (overlay)
          if (liveWaveform != null)
            Positioned.fill(
              child: CustomPaint(
                painter: LiveWaveformPainter(
                  data: liveWaveform,
                  color: AurixTokens.positive.withValues(alpha: 0.8),
                  strokeWidth: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
