import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';

/// Checks viewport width WITHOUT BuildContext — safe to call from initState.
bool _isDesktopView() {
  try {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    return (view.physicalSize.width / view.devicePixelRatio) >= 700;
  } catch (_) {
    return true;
  }
}


class HeroSection extends StatelessWidget {
  final VoidCallback onRegister;
  final VoidCallback onDemo;
  const HeroSection({super.key, required this.onRegister, required this.onDemo});

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return LandingSection(
      padding: EdgeInsets.symmetric(
        horizontal: desktop ? 40 : 20,
        vertical: desktop ? 48 : 28,
      ),
      child: Column(
        children: [
          SizedBox(height: desktop ? 60 : 28),
          // AI Orb with orbit modules
          const _HeroOrbField(),
          SizedBox(height: desktop ? 48 : 28),
          // Headline
          Text(
            'Музыке больше не нужна удача.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AurixTokens.text,
              fontSize: desktop ? 56 : 30,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 8),
          GradientText(
            'Ей нужна стратегия.',
            style: TextStyle(
              fontSize: desktop ? 56 : 30,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 20),
          // Subheadline
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Text(
              'AURIX — AI-операционная система артиста. Анализ музыки, понимание аудитории, стратегия продвижения, контент и дистрибуция — в одной платформе.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AurixTokens.muted,
                fontSize: desktop ? 18 : 15,
                height: 1.65,
              ),
            ),
          ),
          const SizedBox(height: 36),
          // CTAs
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              PrimaryCta(label: 'Начать бесплатно', onTap: onRegister),
              OutlineCta(label: 'Посмотреть демо', onTap: onDemo),
            ],
          ),
          SizedBox(height: desktop ? 56 : 36),
        ],
      ),
    );
  }
}

// ── Hero orb field with particles, neural lines, and widget-based orbit modules ──

class _HeroOrbField extends StatefulWidget {
  const _HeroOrbField();

  @override
  State<_HeroOrbField> createState() => _HeroOrbFieldState();
}

class _HeroOrbFieldState extends State<_HeroOrbField> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 25));

    if (_isDesktopView()) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _modules = [
    _OrbitModule('Анализ трека', 'AI анализирует жанр, эмоцию, энергию и потенциал трека.', Icons.graphic_eq_rounded),
    _OrbitModule('Аудитория', 'AI определяет, кто слушает и что цепляет аудиторию.', Icons.people_outline_rounded),
    _OrbitModule('Стратегия', 'AI строит план продвижения: когда, где и как.', Icons.route_rounded),
    _OrbitModule('Контент', 'AI генерирует идеи видео под твой стиль и тренды.', Icons.videocam_outlined),
    _OrbitModule('Рост', 'AI ведёт системный план развития карьеры.', Icons.trending_up_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    final fieldSize = desktop ? 440.0 : 320.0;

    return SizedBox(
      width: fieldSize,
      height: fieldSize,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Stack(
            children: [
              // Background particles + neural lines + orb core
              CustomPaint(
                size: Size(fieldSize, fieldSize),
                painter: _HeroBackgroundPainter(t: _c.value, fieldSize: fieldSize),
              ),
              // Orbit module chips as real widgets (for hover/tooltip)
              ..._buildModuleWidgets(fieldSize, _c.value, desktop),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildModuleWidgets(double fieldSize, double t, bool desktop) {
    final cx = fieldSize / 2;
    final cy = fieldSize / 2;
    final orbitR = fieldSize * 0.42;
    final widgets = <Widget>[];

    for (var i = 0; i < _modules.length; i++) {
      final angle = (i / _modules.length) * math.pi * 2 + t * math.pi * 2 - math.pi / 2;
      final mx = cx + math.cos(angle) * orbitR;
      final my = cy + math.sin(angle) * orbitR;

      widgets.add(
        Positioned(
          left: mx - (desktop ? 52 : 40),
          top: my - (desktop ? 16 : 14),
          child: _OrbitChip(
            module: _modules[i],
            desktop: desktop,
          ),
        ),
      );
    }
    return widgets;
  }
}

class _OrbitModule {
  final String label;
  final String tooltip;
  final IconData icon;
  const _OrbitModule(this.label, this.tooltip, this.icon);
}

class _OrbitChip extends StatefulWidget {
  final _OrbitModule module;
  final bool desktop;
  const _OrbitChip({required this.module, required this.desktop});

  @override
  State<_OrbitChip> createState() => _OrbitChipState();
}

class _OrbitChipState extends State<_OrbitChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tooltip card
          AnimatedOpacity(
            opacity: _hover ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 180),
            child: AnimatedSlide(
              offset: _hover ? Offset.zero : const Offset(0, 0.1),
              duration: const Duration(milliseconds: 180),
              child: Container(
                width: widget.desktop ? 200 : 160,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AurixTokens.surface2,
                  border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: AurixTokens.accent.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  widget.module.tooltip,
                  style: TextStyle(
                    color: AurixTokens.textSecondary,
                    fontSize: widget.desktop ? 11.5 : 10.5,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
          // Module chip
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              horizontal: widget.desktop ? 12 : 8,
              vertical: widget.desktop ? 6 : 5,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: _hover
                  ? AurixTokens.accent.withValues(alpha: 0.14)
                  : AurixTokens.surface1.withValues(alpha: 0.8),
              border: Border.all(
                color: _hover
                    ? AurixTokens.accent.withValues(alpha: 0.35)
                    : AurixTokens.stroke(0.12),
              ),
              boxShadow: [
                if (_hover)
                  BoxShadow(
                    color: AurixTokens.accent.withValues(alpha: 0.12),
                    blurRadius: 12,
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.module.icon,
                  color: _hover ? AurixTokens.accent : AurixTokens.muted,
                  size: widget.desktop ? 14 : 12,
                ),
                SizedBox(width: widget.desktop ? 6 : 4),
                Text(
                  widget.module.label,
                  style: TextStyle(
                    color: _hover ? AurixTokens.text : AurixTokens.muted.withValues(alpha: 0.8),
                    fontSize: widget.desktop ? 11.5 : 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Background painter: orb core + particles + neural lines ──

class _HeroBackgroundPainter extends CustomPainter {
  final double t;
  final double fieldSize;
  _HeroBackgroundPainter({required this.t, required this.fieldSize});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final orbR = fieldSize * 0.26; // Bigger orb
    final orbitR = fieldSize * 0.42;

    // ── Particle field ──
    final rng = math.Random(42);
    for (var i = 0; i < 40; i++) {
      final px = rng.nextDouble() * size.width;
      final py = rng.nextDouble() * size.height;
      final phase = rng.nextDouble() * math.pi * 2;
      final drift = math.sin(t * math.pi * 2 + phase) * 3;
      final alpha = 0.08 + rng.nextDouble() * 0.12;
      final radius = 1.0 + rng.nextDouble() * 1.5;
      canvas.drawCircle(
        Offset(px + drift, py + drift * 0.5),
        radius,
        Paint()..color = AurixTokens.accent.withValues(alpha: alpha),
      );
    }

    // ── Outer ambient glow ──
    canvas.drawCircle(
      Offset(cx, cy),
      orbitR * 1.15,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AurixTokens.accent.withValues(alpha: 0.07),
            AurixTokens.aiAccent.withValues(alpha: 0.04),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: orbitR * 1.15)),
    );

    // ── Orbit ring ──
    canvas.drawCircle(
      Offset(cx, cy),
      orbitR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AurixTokens.stroke(0.08),
    );

    // ── Secondary orbit ring (inner) ──
    canvas.drawCircle(
      Offset(cx, cy),
      orbitR * 0.65,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = AurixTokens.stroke(0.05),
    );

    // ── Neural connection lines from modules to core ──
    for (var i = 0; i < 5; i++) {
      final angle = (i / 5) * math.pi * 2 + t * math.pi * 2 - math.pi / 2;
      final mx = cx + math.cos(angle) * orbitR;
      final my = cy + math.sin(angle) * orbitR;
      final coreX = cx + math.cos(angle) * orbR * 0.8;
      final coreY = cy + math.sin(angle) * orbR * 0.8;

      // Dashed neural line
      final lineLen = (Offset(mx, my) - Offset(coreX, coreY)).distance;
      final dashCount = (lineLen / 8).floor();
      for (var d = 0; d < dashCount; d++) {
        final frac = d / dashCount;
        final nextFrac = (d + 0.5) / dashCount;
        if (d.isEven) {
          final x1 = coreX + (mx - coreX) * frac;
          final y1 = coreY + (my - coreY) * frac;
          final x2 = coreX + (mx - coreX) * nextFrac;
          final y2 = coreY + (my - coreY) * nextFrac;
          // Pulse alpha along the line
          final pulseAlpha = 0.06 + 0.06 * math.sin(t * math.pi * 4 + i * 1.2 + frac * math.pi);
          canvas.drawLine(
            Offset(x1, y1),
            Offset(x2, y2),
            Paint()
              ..color = AurixTokens.accent.withValues(alpha: pulseAlpha)
              ..strokeWidth = 0.8,
          );
        }
      }

      // Module dot (glow)
      canvas.drawCircle(
        Offset(mx, my),
        10,
        Paint()..color = AurixTokens.accent.withValues(alpha: 0.06),
      );
      canvas.drawCircle(
        Offset(mx, my),
        4,
        Paint()
          ..shader = RadialGradient(
            colors: [AurixTokens.accent, AurixTokens.accent.withValues(alpha: 0.3)],
          ).createShader(Rect.fromCircle(center: Offset(mx, my), radius: 4)),
      );
    }

    // ── Main orb — outer glow ──
    canvas.drawCircle(
      Offset(cx, cy),
      orbR * 1.4,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AurixTokens.accent.withValues(alpha: 0.18),
            AurixTokens.aiAccent.withValues(alpha: 0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: orbR * 1.4)),
    );

    // ── Main orb body ──
    final slowT = t * 0.3;
    final angle = slowT * math.pi * 2;
    final shift = Offset(math.cos(angle) * orbR * 0.12, math.sin(angle) * orbR * 0.08);
    canvas.drawCircle(
      Offset(cx, cy),
      orbR * 0.78,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(shift.dx / orbR, shift.dy / orbR),
          radius: 1.2,
          colors: [
            AurixTokens.accent.withValues(alpha: 0.70),
            AurixTokens.aiAccent.withValues(alpha: 0.50),
            AurixTokens.bg0.withValues(alpha: 0.9),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: orbR * 0.78)),
    );

    // ── Inner bright core ──
    canvas.drawCircle(
      Offset(cx + shift.dx * 0.3, cy + shift.dy * 0.3),
      orbR * 0.22,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.35),
            AurixTokens.accent.withValues(alpha: 0.15),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx + shift.dx * 0.3, cy + shift.dy * 0.3), radius: orbR * 0.22)),
    );

    // ── Pulsing ring on orb ──
    final pulseR = orbR * (0.82 + 0.08 * math.sin(t * math.pi * 3));
    canvas.drawCircle(
      Offset(cx, cy),
      pulseR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AurixTokens.accent.withValues(alpha: 0.10 + 0.05 * math.sin(t * math.pi * 3)),
    );
  }

  @override
  bool shouldRepaint(_HeroBackgroundPainter old) => old.t != t;
}
