import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

/// Living futuristic backdrop: mesh + orange glow + subtle motion + cursor parallax.
/// No BackdropFilter (macOS-safe).
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
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AurixTokens.bg0,
                  Color(0xFF0E0C0A),
                  AurixTokens.bg0,
                ],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final size = MediaQuery.of(context).size;
              final t = _controller.value * 2 * 3.14159;
              final mx = size.width * 0.3 + 80 * (0.5 + 0.5 * _sine(t));
              final my = size.height * 0.2 + 60 * _sine(t * 0.7);
              double px = mx;
              double py = my;
              if (_cursor != null) {
                final dx = (_cursor!.dx - mx) * 0.03;
                final dy = (_cursor!.dy - my) * 0.03;
                px += dx.clamp(-40.0, 40.0);
                py += dy.clamp(-40.0, 40.0);
              }
              return Positioned(
                left: px - 150,
                top: py - 150,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AurixTokens.orange.withValues(alpha: 0.25),
                        AurixTokens.orange2.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
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
              final mx = size.width * 0.7 + 70 * _sine(t * 0.8 + 1);
              final my = size.height * 0.5 + 50 * _sine(t * 0.5 + 2);
              return Positioned(
                left: mx - 120,
                top: my - 120,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AurixTokens.orange2.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.8],
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned.fill(child: widget.child),
        ],
      ),
    );
  }

  double _sine(double x) => (x - x.floor() * 2 - 1).abs() * 2 - 1;
}
