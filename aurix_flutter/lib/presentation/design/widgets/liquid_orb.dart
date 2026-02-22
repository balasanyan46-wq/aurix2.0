import 'package:flutter/material.dart';
import 'package:aurix_flutter/presentation/theme/design_theme.dart';

/// Анимированный градиентный шар — мягкое движение по кривой
class LiquidOrb extends StatefulWidget {
  final Offset? cursorOffset;

  const LiquidOrb({super.key, this.cursorOffset});

  @override
  State<LiquidOrb> createState() => _LiquidOrbState();
}

class _LiquidOrbState extends State<LiquidOrb> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _moveX;
  late Animation<double> _moveY;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
    _moveX = Tween<double>(begin: 0.2, end: 0.8).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));
    _moveY = Tween<double>(begin: 0.15, end: 0.5).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final size = MediaQuery.of(context).size;
        double cx = size.width * _moveX.value;
        double cy = size.height * _moveY.value;
        if (widget.cursorOffset != null) {
          final dx = (widget.cursorOffset!.dx - cx) * 0.02;
          final dy = (widget.cursorOffset!.dy - cy) * 0.02;
          cx += dx.clamp(-80.0, 80.0);
          cy += dy.clamp(-80.0, 80.0);
        }
        return Positioned(
          left: cx - 180,
          top: cy - 180,
          child: IgnorePointer(
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    DesignTheme.neonOrange.withValues(alpha: 0.35),
                    DesignTheme.primaryOrange.withValues(alpha: 0.18),
                    DesignTheme.deepOrange.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 0.7, 1.0],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
