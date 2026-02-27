import 'package:flutter/material.dart';

/// Lightweight scroll reveal: fade-in + slide-up once when visible.
///
/// No heavy deps; uses RenderBox localToGlobal checks on scroll notifications.
class RevealOnScroll extends StatefulWidget {
  const RevealOnScroll({
    super.key,
    required this.child,
    this.scrollListenable,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.curve = Curves.easeOutCubic,
    this.offsetY = 14,
    this.viewportEnter = 0.86,
    this.disabled = false,
  });

  final Widget child;
  final Listenable? scrollListenable;
  final Duration delay;
  final Duration duration;
  final Curve curve;
  final double offsetY;
  final double viewportEnter;
  final bool disabled;

  @override
  State<RevealOnScroll> createState() => _RevealOnScrollState();
}

class _RevealOnScrollState extends State<RevealOnScroll> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _c, curve: widget.curve);
    _slide = Tween<Offset>(begin: Offset(0, widget.offsetY / 100), end: Offset.zero).animate(
      CurvedAnimation(parent: _c, curve: widget.curve),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.scrollListenable?.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didUpdateWidget(covariant RevealOnScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollListenable != widget.scrollListenable) {
      oldWidget.scrollListenable?.removeListener(_check);
      widget.scrollListenable?.addListener(_check);
    }
  }

  void _check() {
    if (!mounted || _shown || widget.disabled) return;
    final ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return;

    final top = ro.localToGlobal(Offset.zero).dy;
    final h = ro.size.height;
    final vh = MediaQuery.sizeOf(context).height;

    final enterY = vh * widget.viewportEnter;
    final isVisible = top < enterY && (top + h) > vh * 0.08;
    if (!isVisible) return;

    _shown = true;
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    widget.scrollListenable?.removeListener(_check);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.disabled) return widget.child;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

