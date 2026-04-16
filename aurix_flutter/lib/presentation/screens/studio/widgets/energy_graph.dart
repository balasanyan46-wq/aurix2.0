import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import '../models/audio_analysis_result.dart';

/// Animated energy-over-time waveform with hook & drop markers and glow effects.
class EnergyGraph extends StatefulWidget {
  final List<StructurePoint> structure;
  final List<double> waveformPeaks;
  final double hookTime;
  final double dropTime;
  final double duration;

  const EnergyGraph({
    super.key,
    required this.structure,
    this.waveformPeaks = const [],
    required this.hookTime,
    required this.dropTime,
    required this.duration,
  });

  @override
  State<EnergyGraph> createState() => _EnergyGraphState();
}

class _EnergyGraphState extends State<EnergyGraph>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _revealAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _revealAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutQuart,
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AurixTokens.stroke(0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AnimatedBuilder(
          animation: _revealAnim,
          builder: (_, __) => CustomPaint(
            size: const Size(double.infinity, 180),
            painter: _WaveformPainter(
              structure: widget.structure,
              waveformPeaks: widget.waveformPeaks,
              hookTime: widget.hookTime,
              dropTime: widget.dropTime,
              duration: widget.duration,
              revealProgress: _revealAnim.value,
            ),
          ),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<StructurePoint> structure;
  final List<double> waveformPeaks;
  final double hookTime;
  final double dropTime;
  final double duration;
  final double revealProgress;

  _WaveformPainter({
    required this.structure,
    required this.waveformPeaks,
    required this.hookTime,
    required this.dropTime,
    required this.duration,
    required this.revealProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (duration <= 0) return;

    final w = size.width;
    final h = size.height;
    final topPad = 28.0;
    final botPad = 20.0;
    final graphH = h - topPad - botPad;
    final midY = topPad + graphH / 2;

    // Visible portion based on reveal animation
    final visibleW = w * revealProgress;

    // ── Background grid ──
    final gridPaint = Paint()
      ..color = AurixTokens.muted.withValues(alpha: 0.06)
      ..strokeWidth = 0.5;

    for (var i = 0; i <= 4; i++) {
      final y = topPad + (graphH * i / 4);
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // Use waveform peaks if available (mirrored bars), else energy line
    if (waveformPeaks.isNotEmpty) {
      _drawWaveformBars(canvas, size, midY, graphH, visibleW);
    } else if (structure.isNotEmpty) {
      _drawEnergyWave(canvas, size, topPad, graphH, visibleW);
    }

    // ── Section labels at bottom ──
    // (kept simple — just time markers)

    // ── Hook marker ──
    if (hookTime > 0 && hookTime < duration) {
      final hx = (hookTime / duration) * w;
      if (hx <= visibleW) {
        _drawGlowMarker(canvas, size, hx, const Color(0xFF22C55E), 'H', topPad, graphH);
      }
    }

    // ── Drop marker ──
    if (dropTime > 0 && dropTime < duration) {
      final dx = (dropTime / duration) * w;
      if (dx <= visibleW) {
        _drawGlowMarker(canvas, size, dx, const Color(0xFFEF4444), 'D', topPad, graphH);
      }
    }

    // ── Time labels ──
    if (revealProgress > 0.5) {
      final labelAlpha = ((revealProgress - 0.5) * 2).clamp(0.0, 1.0);
      final textStyle = TextStyle(
        color: AurixTokens.muted.withValues(alpha: 0.5 * labelAlpha),
        fontSize: 9,
      );

      _drawText(canvas, '0:00', Offset(4, h - 14), textStyle);

      final endMin = (duration ~/ 60);
      final endSec = (duration % 60).toInt();
      _drawText(canvas, '$endMin:${endSec.toString().padLeft(2, '0')}',
          Offset(w - 28, h - 14), textStyle);

      final midSec = duration / 2;
      final midMin = (midSec ~/ 60);
      final midS = (midSec % 60).toInt();
      _drawText(canvas, '$midMin:${midS.toString().padLeft(2, '0')}',
          Offset(w / 2 - 10, h - 14), textStyle);
    }
  }

  void _drawWaveformBars(Canvas canvas, Size size, double midY, double graphH, double visibleW) {
    final n = waveformPeaks.length;
    if (n == 0) return;

    final barWidth = size.width / n;
    final halfH = graphH / 2;

    for (var i = 0; i < n; i++) {
      final x = i * barWidth + barWidth / 2;
      if (x > visibleW) break;

      final amp = waveformPeaks[i].clamp(0.0, 1.0);
      final barH = amp * halfH * 0.9;

      // Color based on position (gradient across the waveform)
      final t = i / n;
      final color = Color.lerp(
        AurixTokens.accent,
        const Color(0xFF8B5CF6),
        t,
      )!;

      // Glow for high peaks
      if (amp > 0.7) {
        final glowPaint = Paint()
          ..color = color.withValues(alpha: 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, midY), width: barWidth * 0.8, height: barH * 2 + 4),
            const Radius.circular(3),
          ),
          glowPaint,
        );
      }

      final barPaint = Paint()
        ..color = color.withValues(alpha: 0.6 + amp * 0.4);

      // Top bar (mirrored up)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - barWidth * 0.35, midY - barH, barWidth * 0.7, barH),
          const Radius.circular(2),
        ),
        barPaint,
      );

      // Bottom bar (mirrored down)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - barWidth * 0.35, midY, barWidth * 0.7, barH),
          const Radius.circular(2),
        ),
        barPaint,
      );
    }
  }

  void _drawEnergyWave(Canvas canvas, Size size, double topPad, double graphH, double visibleW) {
    final fillPath = Path();
    final linePath = Path();
    var started = false;

    for (var i = 0; i < structure.length; i++) {
      final p = structure[i];
      final x = (p.time / duration) * size.width;
      if (x > visibleW) break;

      final y = topPad + graphH * (1.0 - p.energy.clamp(0, 1));

      if (!started) {
        fillPath.moveTo(x, topPad + graphH);
        fillPath.lineTo(x, y);
        linePath.moveTo(x, y);
        started = true;
      } else {
        fillPath.lineTo(x, y);
        linePath.lineTo(x, y);
      }
    }

    if (!started) return;

    // Close fill to bottom
    final lastVisibleX = math.min(visibleW, (structure.last.time / duration) * size.width);
    fillPath.lineTo(lastVisibleX, topPad + graphH);
    fillPath.close();

    // Gradient fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AurixTokens.accent.withValues(alpha: 0.35),
          const Color(0xFF8B5CF6).withValues(alpha: 0.1),
          AurixTokens.accent.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Glow line
    final glowPaint = Paint()
      ..color = AurixTokens.accent.withValues(alpha: 0.2)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(linePath, glowPaint);

    // Main line
    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [AurixTokens.accent, const Color(0xFF8B5CF6)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(linePath, linePaint);
  }

  void _drawGlowMarker(Canvas canvas, Size size, double x, Color color,
      String label, double topPad, double graphH) {
    // Glow behind the line
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawLine(
      Offset(x, topPad),
      Offset(x, topPad + graphH),
      glowPaint..strokeWidth = 8,
    );

    // Dashed vertical line
    final markerPaint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1.5;

    for (var y = topPad; y < topPad + graphH; y += 6) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, (y + 3).clamp(0, size.height)),
        markerPaint,
      );
    }

    // Badge with glow
    final badgeGlow = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(x, 14), 12, badgeGlow);

    final badgePaint = Paint()..color = color;
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, 14), width: 20, height: 18),
      const Radius.circular(6),
    );
    canvas.drawRRect(badgeRect, badgePaint);

    _drawText(
      canvas,
      label,
      Offset(x - 4, 7),
      const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
    );
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.revealProgress != revealProgress ||
      old.structure != structure ||
      old.waveformPeaks != waveformPeaks ||
      old.hookTime != hookTime ||
      old.dropTime != dropTime;
}
