import 'package:flutter/material.dart';

/// Very lightweight parallax: translates child based on scroll offset.
class ParallaxLayer extends StatefulWidget {
  const ParallaxLayer({
    super.key,
    required this.child,
    required this.scrollListenable,
    this.depth = 0.08,
    this.maxShift = 40,
    this.disabled = false,
  });

  final Widget child;
  final Listenable scrollListenable;
  final double depth;
  final double maxShift;
  final bool disabled;

  @override
  State<ParallaxLayer> createState() => _ParallaxLayerState();
}

class _ParallaxLayerState extends State<ParallaxLayer> {
  double _shift = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollListenable.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void didUpdateWidget(covariant ParallaxLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollListenable != widget.scrollListenable) {
      oldWidget.scrollListenable.removeListener(_onScroll);
      widget.scrollListenable.addListener(_onScroll);
    }
  }

  void _onScroll() {
    if (!mounted || widget.disabled) return;
    final scrollable = Scrollable.maybeOf(context);
    final pos = scrollable?.position;
    final off = pos?.pixels ?? 0.0;
    final next = (-off * widget.depth).clamp(-widget.maxShift, widget.maxShift).toDouble();
    if ((_shift - next).abs() < 0.2) return;
    setState(() => _shift = next);
  }

  @override
  void dispose() {
    widget.scrollListenable.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.disabled) return widget.child;
    return Transform.translate(
      offset: Offset(0, _shift),
      child: widget.child,
    );
  }
}

