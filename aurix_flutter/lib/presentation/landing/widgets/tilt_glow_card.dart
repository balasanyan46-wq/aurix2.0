import 'dart:math' as math;

import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class TiltGlowCard extends StatefulWidget {
  const TiltGlowCard({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.borderRadius = 16,
    this.padding,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final double borderRadius;
  final EdgeInsets? padding;

  @override
  State<TiltGlowCard> createState() => _TiltGlowCardState();
}

class _TiltGlowCardState extends State<TiltGlowCard> {
  bool _hover = false;
  Offset _p = Offset.zero; // -1..1

  bool get _canTilt {
    final mq = MediaQuery.of(context);
    final isTouchLike = mq.size.width < 900;
    final reduce = mq.accessibleNavigation;
    if (reduce) return false;
    return widget.enabled && !isTouchLike;
  }

  void _updatePointer(PointerHoverEvent e, Size size) {
    final local = e.localPosition;
    final dx = ((local.dx / size.width) - 0.5) * 2;
    final dy = ((local.dy / size.height) - 0.5) * 2;
    setState(() => _p = Offset(dx.clamp(-1, 1), dy.clamp(-1, 1)));
  }

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(widget.borderRadius);
    final pad = widget.padding ?? EdgeInsets.zero;
    final tilt = _canTilt ? 0.045 : 0.0; // radians ~2.6deg
    final rx = -_p.dy * tilt;
    final ry = _p.dx * tilt;

    final shadow = _hover
        ? [
            BoxShadow(
              color: AurixTokens.orange.withValues(alpha: 0.18),
              blurRadius: 26,
              spreadRadius: -10,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 18,
              spreadRadius: -10,
              offset: const Offset(0, 12),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 14,
              spreadRadius: -12,
              offset: const Offset(0, 10),
            ),
          ];

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: pad,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: shadow,
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Stack(
          children: [
            // Gradient border shimmer (static, cheap)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: r,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AurixTokens.orange.withValues(alpha: _hover ? 0.26 : 0.12),
                      Colors.white.withValues(alpha: _hover ? 0.08 : 0.03),
                      AurixTokens.orange2.withValues(alpha: _hover ? 0.22 : 0.10),
                    ],
                  ),
                ),
              ),
            ),
            // Inner glass
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: r,
                    color: _hover ? AurixTokens.glass(0.055) : AurixTokens.glass(0.035),
                    border: Border.all(color: AurixTokens.stroke(_hover ? 0.16 : 0.12)),
                  ),
                ),
              ),
            ),
            // Cursor glow hotspot (cheap radial)
            if (_canTilt && _hover)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.85,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(_p.dx, _p.dy),
                          radius: 1.1,
                          colors: [
                            AurixTokens.orange.withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                          stops: const [0, 1],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Content
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: ClipRRect(
                  borderRadius: r,
                  child: Padding(
                    padding: const EdgeInsets.all(0),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (_canTilt) {
      card = MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() { _hover = false; _p = Offset.zero; }),
        onHover: (e) {
          final rb = context.findRenderObject();
          if (rb is RenderBox && rb.hasSize) _updatePointer(e, rb.size);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          transformAlignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0018)
            ..rotateX(rx)
            ..rotateY(ry)
            ..translate(0.0, _hover ? -2.0 : 0.0, 0.0),
          child: card,
        ),
      );
    } else {
      card = MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: card,
      );
    }

    if (widget.onTap == null) return card;
    return InkWell(
      onTap: widget.onTap,
      borderRadius: r,
      child: card,
    );
  }
}

