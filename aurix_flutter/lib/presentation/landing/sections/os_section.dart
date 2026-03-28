import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';

class OsSection extends StatelessWidget {
  const OsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return Container(
      color: AurixTokens.surface1.withValues(alpha: 0.3),
      child: LandingSection(
        child: Column(
          children: [
            const SectionLabel(text: 'ПЛАТФОРМА', color: AurixTokens.aiAccent),
            const SizedBox(height: 24),
            Text(
              'Операционная система артиста',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AurixTokens.text,
                fontSize: desktop ? 40 : 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Text(
                'Единая платформа, которая объединяет анализ музыки, аудиторию, стратегию продвижения и AI-инструменты.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AurixTokens.muted, fontSize: desktop ? 16 : 14, height: 1.6),
              ),
            ),
            SizedBox(height: desktop ? 56 : 40),
            // Orbital visual on desktop, vertical list on mobile
            if (desktop)
              const SizedBox(height: 380, child: _OrbitVisual())
            else
              const _ModuleList(),
          ],
        ),
      ),
    );
  }
}

// ── Orbit visual (desktop) with hover cards ──────────────────────

class _OrbitVisual extends StatefulWidget {
  const _OrbitVisual();

  @override
  State<_OrbitVisual> createState() => _OrbitVisualState();
}

class _OrbitVisualState extends State<_OrbitVisual> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _modules = [
    ('Анализ трека', 'AI анализирует жанр, энергию, эмоцию и потенциал', Icons.graphic_eq_rounded),
    ('Аудитория', 'Понимание аудитории: кто слушает и что цепляет', Icons.people_outline_rounded),
    ('Стратегия', 'Стратегия продвижения: когда, где, как', Icons.route_rounded),
    ('Контент', 'Генерация идей для видео, Reels и TikTok', Icons.videocam_outlined),
    ('Рост', 'Системный план роста и развития карьеры', Icons.trending_up_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = 380.0;
          final cx = w / 2;
          final cy = h / 2;
          final r1 = w * 0.28;
          final r1y = r1 * 0.45;
          final r2 = w * 0.38;
          final r2y = r2 * 0.35;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Background orbit paint
              CustomPaint(
                size: Size(w, h),
                painter: _OrbitBgPainter(t: _c.value, w: w, h: h),
              ),
              // Module chips as real widgets
              for (var i = 0; i < _modules.length; i++)
                _buildModuleWidget(i, cx, cy, r1, r1y, r2, r2y, _c.value),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModuleWidget(int i, double cx, double cy, double r1, double r1y, double r2, double r2y, double t) {
    final angle = (i / _modules.length) * math.pi * 2 + t * math.pi * 2;
    final isInner = i % 2 == 0;
    final rx = isInner ? r1 : r2;
    final ry = isInner ? r1y : r2y;
    final mx = cx + math.cos(angle) * rx;
    final my = cy + math.sin(angle) * ry;
    final isHovered = _hoveredIndex == i;

    return Positioned(
      left: mx - 65,
      top: my - 18,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredIndex = i),
        onExit: (_) => setState(() => _hoveredIndex = null),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hover card
            AnimatedOpacity(
              opacity: isHovered ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 160),
              child: Container(
                width: 180,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AurixTokens.surface2,
                  border: Border.all(color: AurixTokens.aiAccent.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: AurixTokens.aiAccent.withValues(alpha: 0.06),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: Text(
                  _modules[i].$2,
                  style: TextStyle(color: AurixTokens.textSecondary, fontSize: 11.5, height: 1.4),
                ),
              ),
            ),
            // Chip
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: isHovered
                    ? AurixTokens.aiAccent.withValues(alpha: 0.12)
                    : AurixTokens.surface1.withValues(alpha: 0.7),
                border: Border.all(
                  color: isHovered
                      ? AurixTokens.aiAccent.withValues(alpha: 0.3)
                      : AurixTokens.stroke(0.10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_modules[i].$3, color: isHovered ? AurixTokens.aiAccent : AurixTokens.muted, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    _modules[i].$1,
                    style: TextStyle(
                      color: isHovered ? AurixTokens.text : AurixTokens.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrbitBgPainter extends CustomPainter {
  final double t;
  final double w;
  final double h;
  _OrbitBgPainter({required this.t, required this.w, required this.h});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = w / 2;
    final cy = h / 2;
    final r1 = w * 0.28;
    final r1y = r1 * 0.45;
    final r2 = w * 0.38;
    final r2y = r2 * 0.35;

    // Draw orbit paths
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AurixTokens.stroke(0.06);

    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: r1 * 2, height: r1y * 2), orbitPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: r2 * 2, height: r2y * 2), orbitPaint);

    // Center glow
    canvas.drawCircle(
      Offset(cx, cy),
      55,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AurixTokens.accent.withValues(alpha: 0.20),
            AurixTokens.aiAccent.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 55)),
    );

    // Center label — ARTIST
    final tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = const TextSpan(
      text: 'ARTIST',
      style: TextStyle(
        color: AurixTokens.text,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: 3,
      ),
    );
    tp.layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));

    // Neural connection lines from modules to center
    for (var i = 0; i < 5; i++) {
      final angle = (i / 5) * math.pi * 2 + t * math.pi * 2;
      final isInner = i % 2 == 0;
      final rx = isInner ? r1 : r2;
      final ry = isInner ? r1y : r2y;
      final mx = cx + math.cos(angle) * rx;
      final my = cy + math.sin(angle) * ry;

      canvas.drawLine(
        Offset(cx, cy),
        Offset(mx, my),
        Paint()
          ..color = AurixTokens.accent.withValues(alpha: 0.06)
          ..strokeWidth = 0.8,
      );

      // Dot at module position
      canvas.drawCircle(
        Offset(mx, my),
        5,
        Paint()
          ..shader = RadialGradient(
            colors: [AurixTokens.accent, AurixTokens.aiAccent],
          ).createShader(Rect.fromCircle(center: Offset(mx, my), radius: 5)),
      );
    }
  }

  @override
  bool shouldRepaint(_OrbitBgPainter old) => old.t != t;
}

// ── Module list (mobile) ────────────────────────────────────────

class _ModuleList extends StatelessWidget {
  const _ModuleList();

  static const _modules = [
    ('Анализ трека', 'Анализ жанра, энергии, эмоции и продакшн-деталей', Icons.graphic_eq_rounded),
    ('Аудитория', 'Понимание аудитории: кто слушает и что цепляет', Icons.people_outline_rounded),
    ('Стратегия', 'Стратегия продвижения: когда, где, как', Icons.route_rounded),
    ('Контент', 'Генерация идей для видео, Reels и TikTok', Icons.videocam_outlined),
    ('Рост', 'Системный план роста и развития карьеры', Icons.trending_up_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _modules.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _ModuleRow(name: _modules[i].$1, desc: _modules[i].$2, icon: _modules[i].$3),
        ],
      ],
    );
  }
}

class _ModuleRow extends StatefulWidget {
  final String name;
  final String desc;
  final IconData icon;
  const _ModuleRow({required this.name, required this.desc, required this.icon});

  @override
  State<_ModuleRow> createState() => _ModuleRowState();
}

class _ModuleRowState extends State<_ModuleRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: _hover ? AurixTokens.surface2 : AurixTokens.bg0.withValues(alpha: 0.6),
          border: Border.all(
            color: _hover ? AurixTokens.aiAccent.withValues(alpha: 0.2) : AurixTokens.stroke(0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [AurixTokens.accent.withValues(alpha: 0.12), AurixTokens.aiAccent.withValues(alpha: 0.08)],
                ),
              ),
              child: Icon(widget.icon, color: AurixTokens.accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.name, style: const TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(widget.desc, style: TextStyle(color: AurixTokens.muted, fontSize: 12.5, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
