import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import '../models/audio_analysis_result.dart';

/// Energy-over-time graph with hook & drop markers.
class EnergyGraph extends StatelessWidget {
  final List<StructurePoint> structure;
  final double hookTime;
  final double dropTime;
  final double duration;

  const EnergyGraph({
    super.key,
    required this.structure,
    required this.hookTime,
    required this.dropTime,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AurixTokens.stroke(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          size: const Size(double.infinity, 160),
          painter: _EnergyPainter(
            structure: structure,
            hookTime: hookTime,
            dropTime: dropTime,
            duration: duration,
          ),
        ),
      ),
    );
  }
}

class _EnergyPainter extends CustomPainter {
  final List<StructurePoint> structure;
  final double hookTime;
  final double dropTime;
  final double duration;

  _EnergyPainter({
    required this.structure,
    required this.hookTime,
    required this.dropTime,
    required this.duration,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (structure.isEmpty || duration <= 0) return;

    final w = size.width;
    final h = size.height;
    final pad = 24.0;
    final graphH = h - pad;

    // ── Draw grid lines ──
    final gridPaint = Paint()
      ..color = AurixTokens.muted.withValues(alpha: 0.1)
      ..strokeWidth = 0.5;

    for (var i = 0; i <= 4; i++) {
      final y = pad + (graphH * i / 4);
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // ── Draw energy fill + line ──
    final fillPath = Path();
    final linePath = Path();
    var started = false;

    for (var i = 0; i < structure.length; i++) {
      final p = structure[i];
      final x = (p.time / duration) * w;
      final y = pad + graphH * (1.0 - p.energy.clamp(0, 1));

      if (!started) {
        fillPath.moveTo(x, h);
        fillPath.lineTo(x, y);
        linePath.moveTo(x, y);
        started = true;
      } else {
        fillPath.lineTo(x, y);
        linePath.lineTo(x, y);
      }
    }

    // Close fill path
    if (started && structure.isNotEmpty) {
      final lastX = (structure.last.time / duration) * w;
      fillPath.lineTo(lastX, h);
      fillPath.close();
    }

    // Fill gradient
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AurixTokens.accent.withValues(alpha: 0.3),
          AurixTokens.accent.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(fillPath, fillPaint);

    // Line
    final linePaint = Paint()
      ..color = AurixTokens.accent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(linePath, linePaint);

    // ── Hook marker ──
    if (hookTime > 0 && hookTime < duration) {
      _drawMarker(canvas, size, hookTime, const Color(0xFF22C55E), 'H', pad, graphH);
    }

    // ── Drop marker ──
    if (dropTime > 0 && dropTime < duration) {
      _drawMarker(canvas, size, dropTime, AurixTokens.danger, 'D', pad, graphH);
    }

    // ── Time labels ──
    final textStyle = TextStyle(
      color: AurixTokens.muted.withValues(alpha: 0.5),
      fontSize: 9,
    );

    // Start
    _drawText(canvas, '0:00', Offset(4, h - 14), textStyle);

    // End
    final endMin = (duration ~/ 60);
    final endSec = (duration % 60).toInt();
    _drawText(canvas, '$endMin:${endSec.toString().padLeft(2, '0')}',
        Offset(w - 28, h - 14), textStyle);

    // Mid
    final midSec = duration / 2;
    final midMin = (midSec ~/ 60);
    final midS = (midSec % 60).toInt();
    _drawText(canvas, '$midMin:${midS.toString().padLeft(2, '0')}',
        Offset(w / 2 - 10, h - 14), textStyle);
  }

  void _drawMarker(Canvas canvas, Size size, double time, Color color,
      String label, double pad, double graphH) {
    final x = (time / duration) * size.width;

    // Vertical dashed line
    final markerPaint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1.5;

    for (var y = pad; y < size.height; y += 6) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, (y + 3).clamp(0, size.height)),
        markerPaint,
      );
    }

    // Label badge
    final badgePaint = Paint()..color = color;
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, 10), width: 18, height: 16),
      const Radius.circular(4),
    );
    canvas.drawRRect(badgeRect, badgePaint);

    _drawText(
      canvas,
      label,
      Offset(x - 3.5, 4),
      const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
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
  bool shouldRepaint(covariant _EnergyPainter old) =>
      old.structure != structure ||
      old.hookTime != hookTime ||
      old.dropTime != dropTime;
}
