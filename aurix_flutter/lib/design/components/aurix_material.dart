import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/components/liquid_glass.dart';

/// Unified iOS-like glass material. Level 1=light, 2=medium, 3=strong.
/// Orange used only as accent, not as card fill.
class AurixMaterial extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final int level;
  final bool hoverScale;

  const AurixMaterial({
    super.key,
    required this.child,
    this.padding,
    this.radius = 16,
    this.level = 2,
    this.hoverScale = true,
  });

  GlassLevel get _glassLevel {
    switch (level) {
      case 1:
        return GlassLevel.light;
      case 3:
        return GlassLevel.strong;
      default:
        return GlassLevel.medium;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      level: _glassLevel,
      padding: padding,
      radius: radius,
      hoverScale: hoverScale,
      showOrangeBorderOnHover: false,
      child: child,
    );
  }
}
