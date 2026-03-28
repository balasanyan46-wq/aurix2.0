import 'dart:math';
import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

/// Animated dark gradient background with floating glowing orbs.
class AiMagicBackground extends StatefulWidget {
  final Widget child;
  const AiMagicBackground({super.key, required this.child});

  @override
  State<AiMagicBackground> createState() => _AiMagicBackgroundState();
}

class _AiMagicBackgroundState extends State<AiMagicBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Base gradient
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

            // Orb 1 — large orange, top-right
            Positioned(
              top: -60 + sin(t * 2 * pi) * 20,
              right: -40 + cos(t * 2 * pi) * 15,
              child: _GlowOrb(
                size: 260,
                color: AurixTokens.accent.withValues(alpha: 0.06 + sin(t * 2 * pi) * 0.02),
                blur: 120,
              ),
            ),

            // Orb 2 — purple, bottom-left
            Positioned(
              bottom: -80 + cos(t * 2 * pi + 1.5) * 25,
              left: -60 + sin(t * 2 * pi + 1.5) * 18,
              child: _GlowOrb(
                size: 220,
                color: AurixTokens.aiAccent.withValues(alpha: 0.05 + cos(t * 2 * pi) * 0.02),
                blur: 100,
              ),
            ),

            // Orb 3 — warm orange, center
            Positioned(
              top: MediaQuery.of(context).size.height * 0.4 + sin(t * 2 * pi + 3) * 30,
              left: MediaQuery.of(context).size.width * 0.3 + cos(t * 2 * pi + 3) * 20,
              child: _GlowOrb(
                size: 180,
                color: AurixTokens.accentWarm.withValues(alpha: 0.04 + sin(t * 2 * pi + 2) * 0.015),
                blur: 90,
              ),
            ),

            // Noise overlay
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

            // Content
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
