import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';

/// Track readiness block with animated circular gauge + sub-scores.
class TrackReadinessBlock extends StatefulWidget {
  final int overallPercent;
  final int soundPercent;
  final int hookPercent;
  final int ideaPercent;

  const TrackReadinessBlock({
    super.key,
    this.overallPercent = 63,
    this.soundPercent = 70,
    this.hookPercent = 55,
    this.ideaPercent = 80,
  });

  @override
  State<TrackReadinessBlock> createState() => _TrackReadinessBlockState();
}

class _TrackReadinessBlockState extends State<TrackReadinessBlock>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _anim.forward();
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AurixTokens.s24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
        color: AurixTokens.surface1.withValues(alpha: 0.4),
        border: Border.all(color: AurixTokens.stroke(0.12)),
      ),
      child: Column(
        children: [
          // Circular gauge + label
          Row(
            children: [
              // Circular progress
              AnimatedBuilder(
                animation: _anim,
                builder: (context, _) {
                  final curved = Curves.easeOutCubic.transform(_anim.value);
                  return SizedBox(
                    width: 88,
                    height: 88,
                    child: CustomPaint(
                      painter: _CircularGaugePainter(
                        progress: (widget.overallPercent / 100) * curved,
                        color: _colorForPercent(widget.overallPercent),
                      ),
                      child: Center(
                        child: Text(
                          '${(widget.overallPercent * curved).round()}%',
                          style: TextStyle(
                            fontFamily: AurixTokens.fontDisplay,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AurixTokens.text,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: AurixTokens.s20),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Готовность трека',
                      style: TextStyle(
                        fontFamily: AurixTokens.fontBody,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AurixTokens.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Анализ на основе структуры, звука и подачи',
                      style: TextStyle(
                        fontFamily: AurixTokens.fontBody,
                        fontSize: 12,
                        color: AurixTokens.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AurixTokens.s20),

          // Sub-scores
          FadeInSlide(
            delayMs: 500,
            child: _SubScore(
              label: 'Звук',
              percent: widget.soundPercent,
              animation: _anim,
              icon: Icons.graphic_eq_rounded,
            ),
          ),
          const SizedBox(height: AurixTokens.s10),
          FadeInSlide(
            delayMs: 650,
            child: _SubScore(
              label: 'Хук',
              percent: widget.hookPercent,
              animation: _anim,
              icon: Icons.bolt_rounded,
            ),
          ),
          const SizedBox(height: AurixTokens.s10),
          FadeInSlide(
            delayMs: 800,
            child: _SubScore(
              label: 'Идея',
              percent: widget.ideaPercent,
              animation: _anim,
              icon: Icons.lightbulb_outline_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForPercent(int p) {
    if (p >= 75) return AurixTokens.positive;
    if (p >= 50) return AurixTokens.accent;
    return AurixTokens.warning;
  }
}

/// Circular gauge painter with glow.
class _CircularGaugePainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;

  _CircularGaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 6;
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    // Background track
    final bgPaint = Paint()
      ..color = AurixTokens.surface2.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      glowPaint,
    );

    // Progress arc
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_CircularGaugePainter old) =>
      old.progress != progress || old.color != color;
}

/// Horizontal sub-score row with animated bar.
class _SubScore extends StatelessWidget {
  final String label;
  final int percent;
  final Animation<double> animation;
  final IconData icon;

  const _SubScore({
    required this.label,
    required this.percent,
    required this.animation,
    required this.icon,
  });

  Color get _color {
    if (percent >= 75) return AurixTokens.positive;
    if (percent >= 50) return AurixTokens.accent;
    return AurixTokens.warning;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final curved = Curves.easeOutCubic.transform(animation.value);
        final animatedPercent = (percent * curved).round();
        final barFill = (percent / 100) * curved;

        return Row(
          children: [
            Icon(icon, size: 16, color: _color.withValues(alpha: 0.7)),
            const SizedBox(width: AurixTokens.s8),
            SizedBox(
              width: 44,
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: AurixTokens.fontBody,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AurixTokens.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: 6,
                  child: Stack(
                    children: [
                      Container(color: AurixTokens.surface2.withValues(alpha: 0.5)),
                      FractionallySizedBox(
                        widthFactor: barFill,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: _color,
                            boxShadow: [
                              BoxShadow(
                                color: _color.withValues(alpha: 0.35),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AurixTokens.s8),
            SizedBox(
              width: 32,
              child: Text(
                '$animatedPercent%',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: AurixTokens.fontMono,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _color,
                  fontFeatures: AurixTokens.tabularFigures,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
