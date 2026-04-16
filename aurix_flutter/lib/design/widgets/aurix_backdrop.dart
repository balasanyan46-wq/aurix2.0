import 'package:flutter/foundation.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:flutter/material.dart';

/// Layered premium backdrop — optimized for mobile.
///
/// On mobile: static gradient only (no animation, no hover).
/// On desktop: animated orbs + cursor parallax.
class AurixBackdrop extends StatefulWidget {
  final Widget child;
  const AurixBackdrop({super.key, required this.child});

  @override
  State<AurixBackdrop> createState() => _AurixBackdropState();
}

class _AurixBackdropState extends State<AurixBackdrop>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  AnimationController? _controller;
  Offset? _cursor;
  bool _isDesktop = true;
  Size _cachedSize = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final w = MediaQuery.sizeOf(context).width;
    _isDesktop = w >= 700;
    _cachedSize = MediaQuery.sizeOf(context);

    // Only create animation on desktop
    if (_isDesktop && _controller == null) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 12),
      )..repeat();
    } else if (!_isDesktop && _controller != null) {
      _controller!.dispose();
      _controller = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause animation when app is backgrounded
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _controller?.stop();
    } else if (state == AppLifecycleState.resumed && _isDesktop) {
      _controller?.repeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = Positioned.fill(child: widget.child);

    // Mobile: static gradient only — zero animation overhead
    if (!_isDesktop) {
      return Stack(
        fit: StackFit.expand,
        children: [_staticBackground(), child],
      );
    }

    // Desktop: animated orbs
    return MouseRegion(
      onHover: (e) {
        // Throttle: only update if moved >4px
        if (_cursor != null && (e.position - _cursor!).distance < 4) return;
        setState(() => _cursor = e.position);
      },
      onExit: (_) => setState(() => _cursor = null),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _staticBackground(),
          _coolGradient(),
          RepaintBoundary(child: _animatedOrb1()),
          RepaintBoundary(child: _animatedOrb2()),
          _topGlow(),
          _topLine(),
          _bottomVignette(),
          child,
        ],
      ),
    );
  }

  Widget _staticBackground() => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AurixTokens.bg0, Color(0xFF0A0A12), Color(0xFF08080E)],
      ),
    ),
  );

  Widget _coolGradient() => IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            AurixTokens.coolUndertone.withValues(alpha: 0.08),
            Colors.transparent,
            AurixTokens.coolUndertone.withValues(alpha: 0.06),
          ],
          stops: const [0, 0.45, 1],
        ),
      ),
    ),
  );

  Widget _animatedOrb1() {
    if (_controller == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _controller!,
      builder: (_, __) {
        final t = _controller!.value * 6.2832;
        final mx = _cachedSize.width * 0.25 + 110 * _sine(t);
        final my = _cachedSize.height * 0.18 + 70 * _sine(t * 0.7);
        double px = mx, py = my;
        if (_cursor != null) {
          px += ((_cursor!.dx - mx) * 0.03).clamp(-40, 40);
          py += ((_cursor!.dy - my) * 0.03).clamp(-40, 40);
        }
        return Positioned(
          left: px - 230, top: py - 210,
          child: Container(
            width: 500, height: 460,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(300),
              gradient: RadialGradient(colors: [
                AurixTokens.accentGlow.withValues(alpha: 0.17),
                AurixTokens.accentWarm.withValues(alpha: 0.1),
                Colors.transparent,
              ], stops: const [0, 0.52, 1]),
            ),
          ),
        );
      },
    );
  }

  Widget _animatedOrb2() {
    if (_controller == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _controller!,
      builder: (_, __) {
        final t = _controller!.value * 6.2832;
        final mx = _cachedSize.width * 0.74 + 90 * _sine(t * 0.8 + 1);
        final my = _cachedSize.height * 0.52 + 60 * _sine(t * 0.5 + 2);
        return Positioned(
          left: mx - 220, top: my - 200,
          child: Container(
            width: 420, height: 380,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(260),
              gradient: RadialGradient(colors: [
                AurixTokens.coolUndertone.withValues(alpha: 0.12),
                const Color(0xFF405B9C).withValues(alpha: 0.07),
                Colors.transparent,
              ], stops: const [0, 0.7, 1]),
            ),
          ),
        );
      },
    );
  }

  Widget _topGlow() => Positioned(
    left: -80, right: -80, top: -110, height: 210,
    child: IgnorePointer(child: DecoratedBox(
      decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [AurixTokens.accentGlow.withValues(alpha: 0.1), Colors.transparent],
      )),
    )),
  );

  Widget _topLine() => Positioned(
    left: -140, right: -140, top: 110, height: 1,
    child: IgnorePointer(child: DecoratedBox(
      decoration: BoxDecoration(gradient: LinearGradient(colors: [
        Colors.transparent, AurixTokens.accentWarm.withValues(alpha: 0.08), Colors.transparent,
      ])),
    )),
  );

  Widget _bottomVignette() => IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.black.withValues(alpha: 0.03), Colors.transparent, Colors.black.withValues(alpha: 0.18)],
      )),
    ),
  );

  double _sine(double x) => (x - x.floor() * 2 - 1).abs() * 2 - 1;
}
