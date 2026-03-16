import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:flutter/material.dart';

/// Layered premium backdrop: deep base + warm/cool ambience.
class AurixBackdrop extends StatefulWidget {
  final Widget child;

  const AurixBackdrop({super.key, required this.child});

  @override
  State<AurixBackdrop> createState() => _AurixBackdropState();
}

class _AurixBackdropState extends State<AurixBackdrop> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Offset? _cursor;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (e) => setState(() => _cursor = e.position),
      onExit: (_) => setState(() => _cursor = null),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AurixTokens.bg0,
                  Color(0xFF0A0A12),
                  Color(0xFF08080E),
                ],
              ),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AurixTokens.coolUndertone.withValues(alpha: 0.08),
                    Colors.transparent,
                    AurixTokens.coolUndertone.withValues(alpha: 0.06),
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final size = MediaQuery.of(context).size;
              final t = _controller.value * 2 * 3.14159;
              final mx = size.width * 0.25 + 110 * (0.5 + 0.5 * _sine(t));
              final my = size.height * 0.18 + 70 * _sine(t * 0.7);
              double px = mx;
              double py = my;
              if (_cursor != null) {
                final dx = (_cursor!.dx - mx) * 0.03;
                final dy = (_cursor!.dy - my) * 0.03;
                px += dx.clamp(-40.0, 40.0);
                py += dy.clamp(-40.0, 40.0);
              }
              return Positioned(
                left: px - 230,
                top: py - 210,
                child: Container(
                  width: 500,
                  height: 460,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(300),
                    gradient: RadialGradient(
                      colors: [
                        AurixTokens.accentGlow.withValues(alpha: 0.17),
                        AurixTokens.accentWarm.withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.52, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final size = MediaQuery.of(context).size;
              final t = _controller.value * 2 * 3.14159;
              final mx = size.width * 0.74 + 90 * _sine(t * 0.8 + 1);
              final my = size.height * 0.52 + 60 * _sine(t * 0.5 + 2);
              return Positioned(
                left: mx - 220,
                top: my - 200,
                child: Container(
                  width: 420,
                  height: 380,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(260),
                    gradient: RadialGradient(
                      colors: [
                        AurixTokens.coolUndertone.withValues(alpha: 0.12),
                        const Color(0xFF405B9C).withValues(alpha: 0.07),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.7, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            left: -80,
            right: -80,
            top: -110,
            height: 210,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AurixTokens.accentGlow.withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: -140,
            right: -140,
            top: 110,
            height: 1,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AurixTokens.accentWarm.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.03),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.18),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(child: widget.child),
        ],
      ),
    );
  }

  double _sine(double x) => (x - x.floor() * 2 - 1).abs() * 2 - 1;
}
