import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

/// V2: Flat surface, no glow, no gradient. Structured container.
/// Alias for AurixSurface for backward compatibility.
class AurixGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  const AurixGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AurixTokens.border, width: 1),
      ),
      child: child,
    );
  }
}
