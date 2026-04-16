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


class AnalysisSection extends StatelessWidget {
  const AnalysisSection({super.key});

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return LandingSection(
      child: SplitCanvas(
        reversed: false,
        left: _AnalysisCopy(desktop: desktop),
        right: const _AnalysisPanel(),
      ),
    );
  }
}

class _AnalysisCopy extends StatelessWidget {
  final bool desktop;
  const _AnalysisCopy({required this.desktop});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: desktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        const SectionLabel(text: 'АНАЛИЗ ТРЕКА'),
        const SizedBox(height: 24),
        Text(
          'AI понимает\nтвою музыку',
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
          'Загрузи трек — и получи детальный AI-анализ за секунды. Жанр, энергия, эмоция, виральность, совпадение с аудиторией и рекомендации по продвижению.',
          textAlign: desktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(color: AurixTokens.muted, fontSize: 15, height: 1.6),
        ),
        const SizedBox(height: 28),
        // Key metrics list
        ..._metrics.map((m) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisSize: desktop ? MainAxisSize.min : MainAxisSize.max,
            mainAxisAlignment: desktop ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: m.$2,
                ),
              ),
              const SizedBox(width: 10),
              Text(m.$1, style: TextStyle(color: AurixTokens.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        )),
      ],
    );
  }

  static const _metrics = [
    ('Жанр и поджанр', AurixTokens.accent),
    ('Энергия и настроение', AurixTokens.aiAccent),
    ('Виральность и потенциал', AurixTokens.accent),
    ('Совпадение с аудиторией', AurixTokens.aiAccent),
    ('Стратегия промо', AurixTokens.accent),
  ];
}

// ── Mock analysis panel with animated waveform ──────────────────

class _AnalysisPanel extends StatelessWidget {
  const _AnalysisPanel();

  @override
  Widget build(BuildContext context) {
    return MockUIPanel(
      title: 'Анализ трека',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Track info header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AurixTokens.aiAccent.withValues(alpha: 0.3), AurixTokens.accent.withValues(alpha: 0.2)],
                  ),
                ),
                child: const Icon(Icons.music_note_rounded, color: AurixTokens.text, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Midnight Drive', style: TextStyle(color: AurixTokens.text, fontSize: 15, fontWeight: FontWeight.w700)),
                  Text('Demo Artist • 3:42', style: TextStyle(color: AurixTokens.micro, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Animated waveform
          Container(
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: AurixTokens.bg0.withValues(alpha: 0.5),
            ),
            child: const _AnimatedWaveform(),
          ),
          const SizedBox(height: 24),
          // Metrics with glowing bars
          const _GlowMetricBar(label: 'Жанр', value: 'Dark Pop', fill: 0.82, color: AurixTokens.accent),
          const SizedBox(height: 14),
          const _GlowMetricBar(label: 'Энергия', value: '78%', fill: 0.78, color: AurixTokens.aiAccent),
          const SizedBox(height: 14),
          const _GlowMetricBar(label: 'Эмоция', value: 'Меланхолия', fill: 0.65, color: AurixTokens.accent),
          const SizedBox(height: 14),
          const _GlowMetricBar(label: 'Виральность', value: '72%', fill: 0.72, color: AurixTokens.aiAccent),
          const SizedBox(height: 14),
          const _GlowMetricBar(label: 'Совпадение с аудиторией', value: '85%', fill: 0.85, color: AurixTokens.accent),
          const SizedBox(height: 20),
          // Classification chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ClassChip('Dark Pop', AurixTokens.aiAccent),
              _ClassChip('Lo-Fi', AurixTokens.accent),
              _ClassChip('Atmospheric', AurixTokens.aiAccent),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClassChip extends StatelessWidget {
  final String label;
  final Color color;
  const _ClassChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Glowing metric bar ──────────────────────────────────────────

class _GlowMetricBar extends StatefulWidget {
  final String label;
  final String value;
  final double fill;
  final Color color;
  const _GlowMetricBar({required this.label, required this.value, required this.fill, this.color = AurixTokens.accent});

  @override
  State<_GlowMetricBar> createState() => _GlowMetricBarState();
}

class _GlowMetricBarState extends State<_GlowMetricBar> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.label, style: TextStyle(color: AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w500)),
              Text(widget.value, style: TextStyle(color: AurixTokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: AurixTokens.stroke(0.08),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: widget.fill.clamp(0, 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(
                    colors: [widget.color, widget.color.withValues(alpha: 0.6)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: _hover ? 0.35 : 0.12),
                      blurRadius: _hover ? 10 : 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated waveform ───────────────────────────────────────────

class _AnimatedWaveform extends StatefulWidget {
  const _AnimatedWaveform();

  @override
  State<_AnimatedWaveform> createState() => _AnimatedWaveformState();
}

class _AnimatedWaveformState extends State<_AnimatedWaveform> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));

    if (_isDesktopView()) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        size: const Size(double.infinity, 44),
        painter: _WaveformPainter(t: _c.value),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double t;
  _WaveformPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final count = (size.width / 3.5).floor();
    final barW = 2.0;
    final gap = (size.width - count * barW) / (count + 1);

    for (var i = 0; i < count; i++) {
      final progress = i / count;
      final x = gap + i * (barW + gap);

      // Generate waveform height with subtle animation
      final base = 0.5 + 0.3 * _wave(progress * 12) + 0.2 * _wave(progress * 28 + 1.5);
      final animated = base + 0.08 * math.sin(t * math.pi * 2 + progress * math.pi * 4);
      final h = (8 + 28 * animated.clamp(0.15, 1.0));

      // Playhead position (animated)
      final playhead = t;
      final isPlayed = progress < playhead;

      final rect = Rect.fromLTWH(x, (size.height - h) / 2, barW, h);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: isPlayed
                ? [
                    AurixTokens.accent.withValues(alpha: 0.6),
                    AurixTokens.aiAccent.withValues(alpha: 0.8),
                  ]
                : [
                    AurixTokens.accent.withValues(alpha: 0.15),
                    AurixTokens.aiAccent.withValues(alpha: 0.25),
                  ],
          ).createShader(rect),
      );
    }
  }

  double _wave(double x) => (x - x.floor()) * 2 - 1;

  @override
  bool shouldRepaint(_WaveformPainter old) => old.t != t;
}
