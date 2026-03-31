import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';

class PotentialSection extends StatelessWidget {
  const PotentialSection({super.key});

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return Container(
      color: AurixTokens.surface1.withValues(alpha: 0.3),
      child: LandingSection(
        child: desktop
            ? Row(
                children: [
                  const Expanded(child: _ScoreVisual()),
                  const SizedBox(width: 56),
                  Expanded(child: _PotentialCopy(desktop: desktop)),
                ],
              )
            : Column(
                children: [
                  const _ScoreVisual(),
                  const SizedBox(height: 40),
                  _PotentialCopy(desktop: desktop),
                ],
              ),
      ),
    );
  }
}

class _PotentialCopy extends StatelessWidget {
  final bool desktop;
  const _PotentialCopy({required this.desktop});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: desktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        const SectionLabel(text: 'ПОТЕНЦИАЛ РЕЛИЗА'),
        const SizedBox(height: 20),
        Text(
          'Узнай шансы трека\nдо релиза',
          textAlign: desktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            color: AurixTokens.text,
            fontSize: desktop ? 34 : 26,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'AURIX оценивает потенциал трека на основе жанра, энергии, трендов и конкурентного окружения. Не гарантия — но обоснованный прогноз.',
          textAlign: desktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(color: AurixTokens.muted, fontSize: 15, height: 1.6),
        ),
      ],
    );
  }
}

class _ScoreVisual extends StatefulWidget {
  const _ScoreVisual();

  @override
  State<_ScoreVisual> createState() => _ScoreVisualState();
}

class _ScoreVisualState extends State<_ScoreVisual> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 220,
        height: 220,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(painter: _ScorePainter(t: _c.value)),
        ),
      ),
    );
  }
}

class _ScorePainter extends CustomPainter {
  final double t;
  _ScorePainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.42;

    // Background ring
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi * 0.75,
      math.pi * 1.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..color = AurixTokens.stroke(0.10),
    );

    // Progress arc (82%)
    final sweep = math.pi * 1.5 * 0.82;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi * 0.75,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi * 0.75,
          endAngle: -math.pi * 0.75 + sweep,
          colors: [AurixTokens.accent, AurixTokens.aiAccent],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
    );

    // Subtle glow pulse
    final pulse = 0.12 + math.sin(t * math.pi * 2) * 0.04;
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.65,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AurixTokens.accent.withValues(alpha: pulse),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.65)),
    );

    // Score text
    final tp = TextPainter(
      text: const TextSpan(
        text: '82',
        style: TextStyle(
          color: AurixTokens.text,
          fontSize: 52,
          fontWeight: FontWeight.w800,
          fontFamily: AurixTokens.fontBody,
          letterSpacing: -2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2 - 6));

    // "/100" label
    final tp2 = TextPainter(
      text: TextSpan(
        text: '/ 100',
        style: TextStyle(color: AurixTokens.muted, fontSize: 14, fontWeight: FontWeight.w500, fontFamily: AurixTokens.fontBody),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp2.paint(canvas, Offset(cx - tp2.width / 2, cy + tp.height / 2 - 10));
  }

  @override
  bool shouldRepaint(_ScorePainter old) => old.t != t;
}
