import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

/// V2 Surface — flat, structured. No glow, no gradient.
/// Bloomberg/Linear-style minimal container.
class AurixSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  const AurixSurface({
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
