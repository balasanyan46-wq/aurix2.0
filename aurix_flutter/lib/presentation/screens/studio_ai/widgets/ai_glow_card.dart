import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

/// Glassmorphism card with glow border and depth.
class AiGlowCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? glowColor;
  final bool enableHover;

  const AiGlowCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.glowColor,
    this.enableHover = false,
  });

  @override
  State<AiGlowCard> createState() => _AiGlowCardState();
}

class _AiGlowCardState extends State<AiGlowCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverCtrl;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _hoverCtrl.dispose();
    super.dispose();
  }

  void _onHover(bool hovering) {
    if (!widget.enableHover) return;
    setState(() => _hovered = hovering);
    if (hovering) {
      _hoverCtrl.forward();
    } else {
      _hoverCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final glow = widget.glowColor ?? AurixTokens.accent;

    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: AnimatedBuilder(
        animation: _hoverCtrl,
        builder: (context, child) {
          final hoverVal = _hoverCtrl.value;
          final scale = 1.0 + hoverVal * 0.01;

          return Transform.scale(
            scale: scale,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  // Depth shadow
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2 + hoverVal * 0.1),
                    blurRadius: 24 + hoverVal * 12,
                    offset: const Offset(0, 8),
                    spreadRadius: -8,
                  ),
                  // Glow
                  BoxShadow(
                    color: glow.withValues(alpha: 0.06 + hoverVal * 0.08),
                    blurRadius: 32 + hoverVal * 16,
                    spreadRadius: -12,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: widget.padding,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AurixTokens.glass(0.06 + hoverVal * 0.02),
                          AurixTokens.glass(0.03),
                          AurixTokens.bg2.withValues(alpha: 0.3),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _hovered
                            ? glow.withValues(alpha: 0.25)
                            : AurixTokens.stroke(0.12),
                      ),
                    ),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Small glassmorphism container for inline elements.
class AiGlassChip extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AiGlassChip({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AurixTokens.glass(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AurixTokens.stroke(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}
