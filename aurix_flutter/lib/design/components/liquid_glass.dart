import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

/// iOS-inspired Liquid Glass material levels.
/// No BackdropFilter (macOS-safe).
enum GlassLevel {
  light,  // subtle
  medium, // panels
  strong, // modals, emphasis
}

/// Liquid Glass container — blur-less glass, thin border, subtle shadow.
/// Use orange sparingly (active, CTA, highlights only).
class LiquidGlass extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final GlassLevel level;
  final bool hoverScale;
  final bool showOrangeBorderOnHover;

  const LiquidGlass({
    super.key,
    required this.child,
    this.padding,
    this.radius = 16,
    this.level = GlassLevel.medium,
    this.hoverScale = true,
    this.showOrangeBorderOnHover = false,
  });

  static double _opacity(GlassLevel level) {
    switch (level) {
      case GlassLevel.light:
        return 0.04;
      case GlassLevel.medium:
        return 0.08;
      case GlassLevel.strong:
        return 0.12;
    }
  }

  static double _strokeOpacity(GlassLevel level) {
    switch (level) {
      case GlassLevel.light:
        return 0.08;
      case GlassLevel.medium:
        return 0.12;
      case GlassLevel.strong:
        return 0.16;
    }
  }

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.basic,
        child: AnimatedScale(
          scale: (widget.hoverScale && _hover) ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: widget.padding ?? const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AurixTokens.glass(
                LiquidGlass._opacity(widget.level) + (_hover ? 0.02 : 0),
              ),
              borderRadius: BorderRadius.circular(widget.radius),
              border: Border.all(
                color: (widget.showOrangeBorderOnHover && _hover)
                    ? AurixTokens.orange.withValues(alpha: 0.5)
                    : AurixTokens.stroke(LiquidGlass._strokeOpacity(widget.level)),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
