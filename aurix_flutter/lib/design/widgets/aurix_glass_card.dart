import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:flutter/material.dart';

/// Backward-compatible premium card shell.
class AurixGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  const AurixGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AurixTokens.bg1.withValues(alpha: 0.92),
            AurixTokens.bg2.withValues(alpha: 0.86),
          ],
        ),
        border: Border.all(color: AurixTokens.stroke(0.24), width: 1),
        boxShadow: [...AurixTokens.subtleShadow],
      ),
      child: Container(
        padding: padding ?? const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.03),
              Colors.transparent,
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}
