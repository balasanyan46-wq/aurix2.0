import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:flutter/material.dart';

/// Core premium surface with clean separation from backdrop.
class AurixSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  const AurixSurface({
    super.key,
    required this.child,
    this.padding,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AurixTokens.bgElevated.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AurixTokens.stroke(0.22), width: 1),
        boxShadow: [...AurixTokens.subtleShadow],
      ),
      child: child,
    );
  }
}
