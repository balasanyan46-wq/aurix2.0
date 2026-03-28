import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';

class DnaSection extends StatelessWidget {
  const DnaSection({super.key});

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return Container(
      color: AurixTokens.surface1.withValues(alpha: 0.25),
      child: LandingSection(
        child: SplitCanvas(
          reversed: true,
          left: _DnaCopy(desktop: desktop),
          right: const _DnaVisual(),
        ),
      ),
    );
  }
}

class _DnaCopy extends StatelessWidget {
  final bool desktop;
  const _DnaCopy({required this.desktop});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: desktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        const SectionLabel(text: 'ДНК АРТИСТА', color: AurixTokens.aiAccent),
        const SizedBox(height: 24),
        Text(
          'У каждого артиста\nесть свой ДНК',
          textAlign: desktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            color: AurixTokens.text,
            fontSize: desktop ? 38 : 28,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'AURIX строит AI-профиль артиста на основе его музыки, аудитории и контента. Это карта для принятия решений — не абстрактная аналитика.',
          textAlign: desktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(color: AurixTokens.muted, fontSize: 15, height: 1.6),
        ),
        const SizedBox(height: 28),
        // DNA parameters
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: desktop ? WrapAlignment.start : WrapAlignment.center,
          children: const [
            _DnaTag('Жанр'),
            _DnaTag('Энергия'),
            _DnaTag('Эмоция'),
            _DnaTag('Аудитория'),
            _DnaTag('Контент'),
            _DnaTag('Рост'),
          ],
        ),
        const SizedBox(height: 28),
        // AI insight quote
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: AurixTokens.aiAccent.withValues(alpha: 0.04),
            border: Border(
              left: BorderSide(color: AurixTokens.aiAccent.withValues(alpha: 0.4), width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Инсайт',
                style: TextStyle(color: AurixTokens.aiAccent, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
              ),
              const SizedBox(height: 6),
              Text(
                '«Ты артист с тёмной атмосферной эстетикой и сильным эмоциональным звучанием. Твоя аудитория хорошо реагирует на короткие видео и TikTok.»',
                style: TextStyle(
                  color: AurixTokens.textSecondary,
                  fontSize: 13.5,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DnaTag extends StatelessWidget {
  final String label;
  const _DnaTag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AurixTokens.aiAccent.withValues(alpha: 0.08),
        border: Border.all(color: AurixTokens.aiAccent.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(color: AurixTokens.aiGlow, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── DNA radar visual ────────────────────────────────────────────

class _DnaVisual extends StatefulWidget {
  const _DnaVisual();

  @override
  State<_DnaVisual> createState() => _DnaVisualState();
}

class _DnaVisualState extends State<_DnaVisual> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(painter: _DnaNetworkPainter(t: _c.value)),
      ),
    );
  }
}

class _DnaNetworkPainter extends CustomPainter {
  final double t;
  _DnaNetworkPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.38;
    final labels = ['Жанр', 'Энергия', 'Эмоция', 'Аудитория', 'Контент', 'Рост'];
    final values = [0.85, 0.72, 0.90, 0.78, 0.65, 0.68];
    final n = labels.length;

    // Axis lines
    final axisPaint = Paint()
      ..color = AurixTokens.stroke(0.08)
      ..strokeWidth = 1;
    for (var i = 0; i < n; i++) {
      final a = (i / n) * math.pi * 2 - math.pi / 2;
      canvas.drawLine(Offset(cx, cy), Offset(cx + math.cos(a) * r, cy + math.sin(a) * r), axisPaint);
    }

    // Concentric rings
    for (var ring = 1; ring <= 3; ring++) {
      final rr = r * ring / 3;
      final path = Path();
      for (var i = 0; i <= n; i++) {
        final a = (i % n / n) * math.pi * 2 - math.pi / 2;
        final p = Offset(cx + math.cos(a) * rr, cy + math.sin(a) * rr);
        if (i == 0) path.moveTo(p.dx, p.dy); else path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, Paint()..color = AurixTokens.stroke(0.06)..style = PaintingStyle.stroke..strokeWidth = 0.8);
    }

    // Data polygon
    final dataPath = Path();
    final points = <Offset>[];
    for (var i = 0; i <= n; i++) {
      final idx = i % n;
      final a = (idx / n) * math.pi * 2 - math.pi / 2;
      final pulse = 1.0 + math.sin(t * math.pi * 2 + idx * 0.8) * 0.04;
      final v = values[idx] * pulse;
      final p = Offset(cx + math.cos(a) * r * v, cy + math.sin(a) * r * v);
      points.add(p);
      if (i == 0) dataPath.moveTo(p.dx, p.dy); else dataPath.lineTo(p.dx, p.dy);
    }

    // Fill
    canvas.drawPath(
      dataPath,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          colors: [AurixTokens.aiAccent.withValues(alpha: 0.18), AurixTokens.accent.withValues(alpha: 0.08)],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
    );

    // Stroke
    canvas.drawPath(dataPath, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.8..color = AurixTokens.aiAccent.withValues(alpha: 0.55));

    // Dots + labels
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < n; i++) {
      // Glow behind dot
      canvas.drawCircle(points[i], 8, Paint()..color = AurixTokens.aiAccent.withValues(alpha: 0.10));
      canvas.drawCircle(points[i], 4, Paint()..color = AurixTokens.aiAccent.withValues(alpha: 0.8));
      canvas.drawCircle(points[i], 2, Paint()..color = Colors.white.withValues(alpha: 0.9));

      final a = (i / n) * math.pi * 2 - math.pi / 2;
      final lx = cx + math.cos(a) * (r + 22);
      final ly = cy + math.sin(a) * (r + 22);
      tp.text = TextSpan(text: labels[i], style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w500));
      tp.layout();
      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_DnaNetworkPainter old) => old.t != t;
}
