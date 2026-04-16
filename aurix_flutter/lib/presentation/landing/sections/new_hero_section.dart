import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';
import 'instant_analysis_flow.dart';

/// Checks viewport width WITHOUT BuildContext — safe to call from initState.
bool _isDesktopView() {
  try {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    return (view.physicalSize.width / view.devicePixelRatio) >= 700;
  } catch (_) {
    return true;
  }
}


/// Hero: rotating pain headlines + track idea input + "Проверить потенциал" CTA.
class NewHeroSection extends StatefulWidget {
  final VoidCallback onRegister;
  final VoidCallback? onDemo;
  const NewHeroSection({super.key, required this.onRegister, this.onDemo});

  @override
  State<NewHeroSection> createState() => _NewHeroSectionState();
}

class _NewHeroSectionState extends State<NewHeroSection> with TickerProviderStateMixin {
  late final AnimationController _waveCtrl;
  late final AnimationController _headlineCtrl;
  late final AnimationController _pulseCtrl;
  Timer? _headlineTimer;
  int _headlineIndex = 0;

  static const _headlines = [
    'Ты не знаешь,\nзалетит твой трек\nили нет.',
    '90% треков тонут\nбез стратегии.\nТвой — следующий?',
    'Ты сливаешь деньги\nна продвижение\nвслепую.',
  ];

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 12));

    if (_isDesktopView()) _waveCtrl.repeat();
    _headlineCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600), value: 1.0);
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2));

    if (_isDesktopView()) _pulseCtrl.repeat(reverse: true);
    _headlineTimer = Timer.periodic(const Duration(seconds: 4), (_) => _nextHeadline());
  }

  void _nextHeadline() {
    _headlineCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() => _headlineIndex = (_headlineIndex + 1) % _headlines.length);
      _headlineCtrl.forward();
    });
  }

  @override
  void dispose() {
    _headlineTimer?.cancel();
    _waveCtrl.dispose();
    _headlineCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);

    return LandingSection(
      padding: EdgeInsets.symmetric(
        horizontal: desktop ? 40 : 20,
        vertical: desktop ? 80 : 48,
      ),
      child: desktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 5, child: _HeroCopy(
                  onRegister: widget.onRegister,
                  headlineCtrl: _headlineCtrl,
                  headlines: _headlines,
                  headlineIndex: _headlineIndex,
                  pulseCtrl: _pulseCtrl,
                )),
                const SizedBox(width: 48),
                Expanded(flex: 5, child: _LiveProductMockup(ctrl: _waveCtrl)),
              ],
            )
          : Column(
              children: [
                _HeroCopy(
                  onRegister: widget.onRegister,
                  headlineCtrl: _headlineCtrl,
                  headlines: _headlines,
                  headlineIndex: _headlineIndex,
                  pulseCtrl: _pulseCtrl,
                ),
                const SizedBox(height: 40),
                _LiveProductMockup(ctrl: _waveCtrl),
              ],
            ),
    );
  }
}

// ── Hero copy with rotating headlines + input ──────────────────────

class _HeroCopy extends StatefulWidget {
  final VoidCallback onRegister;
  final AnimationController headlineCtrl;
  final AnimationController pulseCtrl;
  final List<String> headlines;
  final int headlineIndex;
  const _HeroCopy({
    required this.onRegister,
    required this.headlineCtrl,
    required this.headlines,
    required this.headlineIndex,
    required this.pulseCtrl,
  });

  @override
  State<_HeroCopy> createState() => _HeroCopyState();
}

class _HeroCopyState extends State<_HeroCopy> {
  final _ideaController = TextEditingController();
  bool _inputFocused = false;

  @override
  void dispose() {
    _ideaController.dispose();
    super.dispose();
  }

  void _checkPotential() {
    final idea = _ideaController.text.trim();
    if (idea.isEmpty) {
      // If empty, use a default
      showInstantAnalysis(context, 'Мой новый трек', widget.onRegister);
    } else {
      showInstantAnalysis(context, idea, widget.onRegister);
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return Column(
      crossAxisAlignment: desktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        // Live pill with pulse
        AnimatedBuilder(
          animation: widget.pulseCtrl,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AurixTokens.positive.withValues(alpha: 0.3 + widget.pulseCtrl.value * 0.2)),
                color: AurixTokens.positive.withValues(alpha: 0.06 + widget.pulseCtrl.value * 0.04),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7, height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AurixTokens.positive,
                      boxShadow: [
                        BoxShadow(
                          color: AurixTokens.positive.withValues(alpha: 0.4 + widget.pulseCtrl.value * 0.4),
                          blurRadius: 6 + widget.pulseCtrl.value * 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ОСТАЛОСЬ 47 БЕСПЛАТНЫХ МЕСТ',
                    style: TextStyle(color: AurixTokens.positive, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),

        // Rotating headline with fade
        FadeTransition(
          opacity: widget.headlineCtrl,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: widget.headlineCtrl, curve: Curves.easeOut)),
            child: Text(
              widget.headlines[widget.headlineIndex],
              textAlign: desktop ? TextAlign.left : TextAlign.center,
              style: TextStyle(
                color: AurixTokens.text,
                fontSize: desktop ? 52 : 34,
                fontWeight: FontWeight.w900,
                height: 1.08,
                letterSpacing: -1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Gradient punchline
        GradientText(
          'AURIX считает это до релиза.',
          textAlign: desktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            fontSize: desktop ? 52 : 34,
            fontWeight: FontWeight.w900,
            height: 1.08,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 28),

        // ── Track idea input ──
        Container(
          constraints: BoxConstraints(maxWidth: desktop ? 480 : double.infinity),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _inputFocused
                  ? AurixTokens.accent.withValues(alpha: 0.5)
                  : AurixTokens.stroke(0.15),
              width: _inputFocused ? 1.5 : 1,
            ),
            color: AurixTokens.surface1,
            boxShadow: [
              if (_inputFocused)
                BoxShadow(
                  color: AurixTokens.accent.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(Icons.music_note_rounded, color: AurixTokens.accent.withValues(alpha: 0.5), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Focus(
                  onFocusChange: (f) => setState(() => _inputFocused = f),
                  child: TextField(
                    controller: _ideaController,
                    style: const TextStyle(color: AurixTokens.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Опиши свой трек или вставь ссылку...',
                      hintStyle: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.6), fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onSubmitted: (_) => _checkPotential(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _CheckPotentialButton(onTap: _checkPotential, pulseCtrl: widget.pulseCtrl),
              const SizedBox(width: 6),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Trust + bonus line
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.card_giftcard_rounded, size: 14, color: AurixTokens.aiAccent.withValues(alpha: 0.8)),
            const SizedBox(width: 6),
            Text(
              '50 AI кредитов бесплатно при регистрации',
              style: TextStyle(color: AurixTokens.aiAccent.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, size: 13, color: AurixTokens.micro),
            const SizedBox(width: 6),
            Text(
              'Без карты  ·  Старт за 30 сек  ·  Отмена в любой момент',
              style: TextStyle(color: AurixTokens.micro, fontSize: 11.5, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Glowing CTA button inside input ────────────────────────────────

class _CheckPotentialButton extends StatefulWidget {
  final VoidCallback onTap;
  final AnimationController pulseCtrl;
  const _CheckPotentialButton({required this.onTap, required this.pulseCtrl});

  @override
  State<_CheckPotentialButton> createState() => _CheckPotentialButtonState();
}

class _CheckPotentialButtonState extends State<_CheckPotentialButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: widget.pulseCtrl,
          builder: (context, _) {
            final glow = _hover ? 0.4 : 0.15 + widget.pulseCtrl.value * 0.1;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: _hover
                      ? [AurixTokens.accent, AurixTokens.accentWarm]
                      : [AurixTokens.accent, AurixTokens.accentMuted],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AurixTokens.accent.withValues(alpha: glow),
                    blurRadius: _hover ? 20 : 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'Проверить потенциал',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Live product mockup: animated UI showing track analysis ────────

class _LiveProductMockup extends StatelessWidget {
  final AnimationController ctrl;
  const _LiveProductMockup({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        return Container(
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AurixTokens.surface1,
            border: Border.all(color: AurixTokens.stroke(0.14)),
            boxShadow: [
              BoxShadow(
                color: AurixTokens.accent.withValues(alpha: 0.08),
                blurRadius: 60,
                offset: const Offset(0, 20),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Window chrome
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AurixTokens.stroke(0.08))),
                ),
                child: Row(
                  children: [
                    _dot(const Color(0xFFFF5F57)),
                    const SizedBox(width: 6),
                    _dot(const Color(0xFFFFBD2E)),
                    const SizedBox(width: 6),
                    _dot(const Color(0xFF27C93F)),
                    const SizedBox(width: 16),
                    Text('AURIX AI — Анализ трека', style: TextStyle(color: AurixTokens.micro, fontSize: 11, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Track info
                    Row(
                      children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AurixTokens.accent.withValues(alpha: 0.3), AurixTokens.aiAccent.withValues(alpha: 0.3)],
                            ),
                          ),
                          child: const Icon(Icons.music_note_rounded, color: AurixTokens.accentWarm, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Midnight Dreams', style: TextStyle(color: AurixTokens.text, fontSize: 15, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text('artist_demo · 3:24', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                            ],
                          ),
                        ),
                        // Animated score
                        _AnimatedScore(ctrl: ctrl),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Waveform
                    SizedBox(
                      height: 40,
                      child: CustomPaint(
                        painter: _WaveformPainter(progress: ctrl.value),
                        size: const Size(double.infinity, 40),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Metric bars with animated fills
                    _metric('Потенциал вирусности', 0.82, AurixTokens.accent, '82%'),
                    const SizedBox(height: 10),
                    _metric('Качество продакшна', 0.91, AurixTokens.aiAccent, '91%'),
                    const SizedBox(height: 10),
                    _metric('Вероятность попадания в плейлист', 0.73, AurixTokens.positive, '73%'),
                    const SizedBox(height: 10),
                    _metric('Текстовый hook', 0.67, AurixTokens.warning, '67%'),
                    const SizedBox(height: 18),

                    // AI insight
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AurixTokens.aiAccent.withValues(alpha: 0.06),
                        border: Border.all(color: AurixTokens.aiAccent.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 16, color: AurixTokens.aiGlow),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Сильный drop и мелодический hook. TikTok-фрагмент 0:47–1:02 даст макс. охват. Рекомендация: усилить бас в припеве +2dB.',
                              style: TextStyle(color: AurixTokens.textSecondary, fontSize: 12, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dot(Color c) => Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: c));

  Widget _metric(String label, double fill, Color color, String valueText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: AurixTokens.muted, fontSize: 11.5, fontWeight: FontWeight.w500)),
            Text(valueText, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700, fontFeatures: AurixTokens.tabularFigures)),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          height: 5,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: AurixTokens.stroke(0.08)),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fill,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.6)]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Animated score badge ───────────────────────────────────────────

class _AnimatedScore extends StatelessWidget {
  final AnimationController ctrl;
  const _AnimatedScore({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    // Pulse glow on the score
    final glow = 0.15 + (math.sin(ctrl.value * math.pi * 2) * 0.1).abs();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AurixTokens.positive.withValues(alpha: 0.12),
        border: Border.all(color: AurixTokens.positive.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AurixTokens.positive.withValues(alpha: glow),
            blurRadius: 16,
          ),
        ],
      ),
      child: const Text(
        '82/100',
        style: TextStyle(color: AurixTokens.positive, fontSize: 16, fontWeight: FontWeight.w800, fontFeatures: AurixTokens.tabularFigures),
      ),
    );
  }
}

// ── Waveform painter ───────────────────────────────────────────────

class _WaveformPainter extends CustomPainter {
  final double progress;
  _WaveformPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = 60;
    final barWidth = size.width / barCount * 0.65;
    final gap = size.width / barCount * 0.35;
    final rng = math.Random(42);

    for (int i = 0; i < barCount; i++) {
      final base = rng.nextDouble() * 0.6 + 0.2;
      final wave = math.sin((i / barCount * 4 + progress * math.pi * 2)) * 0.15;
      final h = (base + wave).clamp(0.1, 1.0) * size.height;
      final x = i * (barWidth + gap);
      final played = i / barCount < progress;

      final paint = Paint()
        ..color = played
            ? AurixTokens.accent.withValues(alpha: 0.8)
            : AurixTokens.stroke(0.2);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x + barWidth / 2, size.height / 2), width: barWidth, height: h),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) => old.progress != progress;
}
