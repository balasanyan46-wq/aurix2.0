import 'package:flutter/material.dart';

class NavigatorReveal extends StatefulWidget {
  const NavigatorReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offsetY = 10,
    this.duration = const Duration(milliseconds: 360),
  });

  final Widget child;
  final Duration delay;
  final double offsetY;
  final Duration duration;

  @override
  State<NavigatorReveal> createState() => _NavigatorRevealState();
}

class _NavigatorRevealState extends State<NavigatorReveal> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (!mounted) return;
      setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      opacity: _visible ? 1 : 0,
      child: AnimatedSlide(
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        offset: _visible ? Offset.zero : Offset(0, widget.offsetY / 100),
        child: widget.child,
      ),
    );
  }
}
