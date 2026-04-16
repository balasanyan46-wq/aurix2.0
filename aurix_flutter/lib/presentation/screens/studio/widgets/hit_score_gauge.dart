import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

/// Animated circular gauge for hit score with glow effect.
class HitScoreGauge extends StatefulWidget {
  final int score;
  final String verdict;
  final int viralProbability;

  const HitScoreGauge({
    super.key,
    required this.score,
    required this.verdict,
    required this.viralProbability,
  });

  @override
  State<HitScoreGauge> createState() => _HitScoreGaugeState();
}

class _HitScoreGaugeState extends State<HitScoreGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scoreAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _scoreAnim = Tween<double>(begin: 0, end: widget.score / 100)
        .animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0, 0.7, curve: Curves.easeOutCubic),
    ));
    _glowAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    ));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _color(int score) {
    if (score >= 70) return const Color(0xFF22C55E);
    if (score >= 40) return const Color(0xFFEAB308);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(widget.score);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.08 * _glowAnim.value),
                AurixTokens.bg1.withValues(alpha: 0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: color.withValues(alpha: 0.2 * _glowAnim.value),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08 * _glowAnim.value),
                blurRadius: 40,
                spreadRadius: -8,
              ),
            ],
          ),
          child: Column(children: [
            // Header
            Text(
              'HIT PREDICTOR',
              style: TextStyle(
                color: color.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 20),

            // Circular gauge
            SizedBox(
              width: 180,
              height: 180,
              child: CustomPaint(
                painter: _GaugePainter(
                  progress: _scoreAnim.value,
                  color: color,
                  glowIntensity: _glowAnim.value,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${(_scoreAnim.value * 100).toInt()}',
                        style: TextStyle(
                          color: color,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                          height: 1,
                        ),
                      ),
                      Text(
                        '/ 100',
                        style: TextStyle(
                          color: color.withValues(alpha: 0.4),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Verdict
            AnimatedOpacity(
              opacity: _glowAnim.value,
              duration: Duration.zero,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Text(
                  widget.verdict,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Viral probability bar
            AnimatedOpacity(
              opacity: _glowAnim.value,
              duration: Duration.zero,
              child: Row(children: [
                Icon(Icons.whatshot_rounded, size: 16,
                    color: AurixTokens.muted.withValues(alpha: 0.5)),
                const SizedBox(width: 6),
                Text('Вирусность',
                    style: TextStyle(
                        color: AurixTokens.muted.withValues(alpha: 0.6),
                        fontSize: 12)),
                const Spacer(),
                Text('${widget.viralProbability}%',
                    style: TextStyle(
                        color: AurixTokens.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(height: 6),
            AnimatedOpacity(
              opacity: _glowAnim.value,
              duration: Duration.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (widget.viralProbability / 100) * _scoreAnim.value / (widget.score / 100).clamp(0.01, 1),
                  backgroundColor: AurixTokens.glass(0.08),
                  color: color,
                  minHeight: 6,
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double glowIntensity;

  _GaugePainter({
    required this.progress,
    required this.color,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const startAngle = math.pi * 0.75;
    const sweepTotal = math.pi * 1.5;

    // Background arc
    final bgPaint = Paint()
      ..color = AurixTokens.glass(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      bgPaint,
    );

    // Glow arc
    if (glowIntensity > 0) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.15 * glowIntensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepTotal * progress,
        false,
        glowPaint,
      );
    }

    // Progress arc with gradient
    if (progress > 0) {
      final progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + sweepTotal * progress,
          colors: [
            color.withValues(alpha: 0.5),
            color,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepTotal * progress,
        false,
        progressPaint,
      );

      // Dot at the end of progress
      final endAngle = startAngle + sweepTotal * progress;
      final dotX = center.dx + radius * math.cos(endAngle);
      final dotY = center.dy + radius * math.sin(endAngle);

      // Dot glow
      canvas.drawCircle(
        Offset(dotX, dotY),
        8,
        Paint()
          ..color = color.withValues(alpha: 0.3 * glowIntensity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // Dot
      canvas.drawCircle(Offset(dotX, dotY), 5, Paint()..color = color);
      canvas.drawCircle(Offset(dotX, dotY), 2.5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.progress != progress || old.glowIntensity != glowIntensity;
}
