import 'dart:math';
import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

/// Фон с «магической» подсветкой.
/// Desktop: 3 плавающие сферы + шумовой оверлей (анимация 8сек).
/// Mobile: статичный градиент с одной сферой БЕЗ blur — в 10+ раз легче.
class AiMagicBackground extends StatefulWidget {
  final Widget child;
  const AiMagicBackground({super.key, required this.child});

  @override
  State<AiMagicBackground> createState() => _AiMagicBackgroundState();
}

class _AiMagicBackgroundState extends State<AiMagicBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  AnimationController? _ctrl;
  bool _isMobile = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final w = MediaQuery.sizeOf(context).width;
    final mobile = w < 700;
    if (mobile != _isMobile || (!mobile && _ctrl == null)) {
      _isMobile = mobile;
      _ctrl?.dispose();
      _ctrl = null;
      if (!mobile) {
        _ctrl = AnimationController(
          vsync: this,
          duration: const Duration(seconds: 8),
        )..repeat();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Пауза анимации когда вкладка неактивна — экономит батарею
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _ctrl?.stop();
    } else if (state == AppLifecycleState.resumed && !_isMobile) {
      _ctrl?.repeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mobile: статичный градиент + одна мягкая засветка через RadialGradient
    // (без blurRadius — это дёшево). НИКАКОЙ анимации.
    if (_isMobile) {
      return Stack(fit: StackFit.expand, children: [
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AurixTokens.bg0, AurixTokens.bg1, Color(0xFF0D0D18)]))),
        DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(
          center: const Alignment(0.6, -0.8), radius: 1.3,
          colors: [
            AurixTokens.accent.withValues(alpha: 0.08),
            Colors.transparent,
          ]))),
        DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(
          center: const Alignment(-0.7, 0.6), radius: 1.1,
          colors: [
            AurixTokens.aiAccent.withValues(alpha: 0.06),
            Colors.transparent,
          ]))),
        widget.child,
      ]);
    }

    // Desktop: прежняя версия с анимацией
    return AnimatedBuilder(
      animation: _ctrl!,
      builder: (context, child) {
        final t = _ctrl!.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AurixTokens.bg0,
                    AurixTokens.bg1,
                    const Color(0xFF0D0D18),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -60 + sin(t * 2 * pi) * 20,
              right: -40 + cos(t * 2 * pi) * 15,
              child: _GlowOrb(
                size: 260,
                color: AurixTokens.accent.withValues(alpha: 0.06 + sin(t * 2 * pi) * 0.02),
                blur: 120,
              ),
            ),
            Positioned(
              bottom: -80 + cos(t * 2 * pi + 1.5) * 25,
              left: -60 + sin(t * 2 * pi + 1.5) * 18,
              child: _GlowOrb(
                size: 220,
                color: AurixTokens.aiAccent.withValues(alpha: 0.05 + cos(t * 2 * pi) * 0.02),
                blur: 100,
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.4 + sin(t * 2 * pi + 3) * 30,
              left: MediaQuery.of(context).size.width * 0.3 + cos(t * 2 * pi + 3) * 20,
              child: _GlowOrb(
                size: 180,
                color: AurixTokens.accentWarm.withValues(alpha: 0.04 + sin(t * 2 * pi + 2) * 0.015),
                blur: 90,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.03,
                  child: Image.asset(
                    'assets/noise.png',
                    repeat: ImageRepeat.repeat,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double blur;

  const _GlowOrb({
    required this.size,
    required this.color,
    required this.blur,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: blur,
            spreadRadius: size * 0.3,
          ),
        ],
      ),
    );
  }
}
