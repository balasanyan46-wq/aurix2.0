import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Checks viewport width WITHOUT BuildContext — safe from initState.
bool _isDesktopView() {
  try {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    return (view.physicalSize.width / view.devicePixelRatio) >= 700;
  } catch (_) {
    return true;
  }
}


/// Jarvis-style holographic orb — golden star particles, orbital rings, energy core.
class JarvisLoader extends StatefulWidget {
  final String statusText;
  final int step;
  final int totalSteps;

  const JarvisLoader({
    super.key,
    required this.statusText,
    this.step = 0,
    this.totalSteps = 5,
  });

  @override
  State<JarvisLoader> createState() => _JarvisLoaderState();
}

class _JarvisLoaderState extends State<JarvisLoader>
    with TickerProviderStateMixin {
  late AnimationController _orbCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _sparkCtrl;
  bool _soundStarted = false;
  JSObject? _audioCtx;

  @override
  void initState() {
    super.initState();
    _orbCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 12));

    if (_isDesktopView()) _orbCtrl.repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

    if (_isDesktopView()) _pulseCtrl.repeat(reverse: true);
    _sparkCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4));

    if (_isDesktopView()) _sparkCtrl.repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_soundStarted) {
        _soundStarted = true;
        _startAmbientSound();
      }
    });
  }

  // ── Ambient sound engine ──
  void _startAmbientSound() {
    try {
      final jsWindow = globalContext;
      final acClass = jsWindow.getProperty('AudioContext'.toJS);
      if (acClass == null) return;
      _audioCtx = (acClass as JSFunction).callAsConstructor() as JSObject;
      final ctx = _audioCtx!;

      // Layer 1: Deep sub drone (40Hz)
      _createDrone(ctx, 40, 0.04, 'sine');
      // Layer 2: Warm hum (120Hz)
      _createDrone(ctx, 120, 0.02, 'triangle');
      // Layer 3: Ethereal pad (high shimmer)
      _createShimmer(ctx);
      // Layer 4: Rhythmic pulse every 2s
      _createPulseBeats(ctx);
    } catch (_) {}
  }

  void _createDrone(JSObject ctx, double freq, double vol, String type) {
    try {
      final osc = ctx.callMethod('createOscillator'.toJS) as JSObject;
      final gain = ctx.callMethod('createGain'.toJS) as JSObject;
      final dest = ctx.getProperty('destination'.toJS) as JSObject;
      osc.setProperty('type'.toJS, type.toJS);
      (osc.getProperty('frequency'.toJS) as JSObject).setProperty('value'.toJS, freq.toJS);
      (gain.getProperty('gain'.toJS) as JSObject).setProperty('value'.toJS, vol.toJS);
      osc.callMethod('connect'.toJS, gain);
      gain.callMethod('connect'.toJS, dest);
      final now = (ctx.getProperty('currentTime'.toJS) as JSNumber).toDartDouble;
      osc.callMethod('start'.toJS, now.toJS);
      osc.callMethod('stop'.toJS, (now + 120).toJS);
    } catch (_) {}
  }

  void _createShimmer(JSObject ctx) {
    try {
      // Two detuned high oscillators for shimmer effect
      for (final detune in [0.0, 3.0]) {
        final osc = ctx.callMethod('createOscillator'.toJS) as JSObject;
        final gain = ctx.callMethod('createGain'.toJS) as JSObject;
        final dest = ctx.getProperty('destination'.toJS) as JSObject;
        osc.setProperty('type'.toJS, 'sine'.toJS);
        (osc.getProperty('frequency'.toJS) as JSObject).setProperty('value'.toJS, (880 + detune).toJS);
        (gain.getProperty('gain'.toJS) as JSObject).setProperty('value'.toJS, (0.006).toJS);
        osc.callMethod('connect'.toJS, gain);
        gain.callMethod('connect'.toJS, dest);
        final now = (ctx.getProperty('currentTime'.toJS) as JSNumber).toDartDouble;
        osc.callMethod('start'.toJS, now.toJS);
        osc.callMethod('stop'.toJS, (now + 120).toJS);
      }
    } catch (_) {}
  }

  void _createPulseBeats(JSObject ctx) {
    try {
      final now = (ctx.getProperty('currentTime'.toJS) as JSNumber).toDartDouble;
      for (int i = 0; i < 30; i++) {
        final t = now + i * 2.0;
        // Short ping
        final osc = ctx.callMethod('createOscillator'.toJS) as JSObject;
        final gain = ctx.callMethod('createGain'.toJS) as JSObject;
        final dest = ctx.getProperty('destination'.toJS) as JSObject;
        osc.setProperty('type'.toJS, 'sine'.toJS);
        final freq = osc.getProperty('frequency'.toJS) as JSObject;
        freq.callMethod('setValueAtTime'.toJS, (600.0).toJS, t.toJS);
        freq.callMethod('exponentialRampToValueAtTime'.toJS, (200.0).toJS, (t + 0.15).toJS);
        final g = gain.getProperty('gain'.toJS) as JSObject;
        g.callMethod('setValueAtTime'.toJS, (0.025).toJS, t.toJS);
        g.callMethod('linearRampToValueAtTime'.toJS, (0.0).toJS, (t + 0.4).toJS);
        osc.callMethod('connect'.toJS, gain);
        gain.callMethod('connect'.toJS, dest);
        osc.callMethod('start'.toJS, t.toJS);
        osc.callMethod('stop'.toJS, (t + 0.5).toJS);
      }
    } catch (_) {}
  }

  void _stopSound() {
    try {
      _audioCtx?.callMethod('close'.toJS);
    } catch (_) {}
    _audioCtx = null;
  }

  @override
  void dispose() {
    _stopSound();
    _orbCtrl.dispose();
    _pulseCtrl.dispose();
    _sparkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (widget.step + 1) / widget.totalSteps;

    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      // ── Holographic orb ──
      SizedBox(
        width: 300,
        height: 300,
        child: AnimatedBuilder(
          animation: Listenable.merge([_orbCtrl, _pulseCtrl, _sparkCtrl]),
          builder: (_, __) => CustomPaint(
            painter: _HoloOrbPainter(
              time: _orbCtrl.value,
              pulse: _pulseCtrl.value,
              sparkPhase: _sparkCtrl.value,
              progress: progress,
            ),
          ),
        ),
      ),
      const SizedBox(height: 36),

      // ── Status text ──
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: Text(
          widget.statusText,
          key: ValueKey(widget.statusText),
          style: TextStyle(
            fontFamily: AurixTokens.fontHeading,
            color: const Color(0xFFFFD080),
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ),
      const SizedBox(height: 20),

      // ── Progress bar ──
      SizedBox(
        width: 180,
        child: Column(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: const Color(0xFFFFB347).withValues(alpha: 0.08),
              color: const Color(0xFFFFB347),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toInt()}%',
            style: TextStyle(
              fontFamily: AurixTokens.fontMono,
              color: const Color(0xFFFFB347).withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ]),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
// Holographic Orb Painter
// ══════════════════════════════════════════════════════════════

class _HoloOrbPainter extends CustomPainter {
  final double time;
  final double pulse;
  final double sparkPhase;
  final double progress;

  static const _gold = Color(0xFFFFB347);
  static const _goldBright = Color(0xFFFFD080);
  static const _goldDim = Color(0xFF996622);
  static const _white = Color(0xFFFFEECC);

  _HoloOrbPainter({
    required this.time,
    required this.pulse,
    required this.sparkPhase,
    required this.progress,
  });

  final _rng = math.Random(777);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);
    final R = size.width / 2 - 10;

    // ── 1. Outer glow bloom ──
    canvas.drawCircle(
      center,
      R * (1.1 + pulse * 0.08),
      Paint()
        ..shader = ui.Gradient.radial(center, R * 1.2, [
          _gold.withValues(alpha: 0.06 + pulse * 0.04),
          _gold.withValues(alpha: 0.02),
          Colors.transparent,
        ], [0.0, 0.5, 1.0]),
    );

    // ── 2. Star particles (sphere distribution) ──
    _drawStarParticles(canvas, center, R);

    // ── 3. Orbital rings (gyroscope style) ──
    _drawOrbitalRing(canvas, center, R * 0.88, time * math.pi * 2, 0.3, 1.8, _gold.withValues(alpha: 0.35));
    _drawOrbitalRing(canvas, center, R * 0.72, -time * math.pi * 2 * 0.7, 0.6, 1.2, _gold.withValues(alpha: 0.2));
    _drawOrbitalRing(canvas, center, R * 0.55, time * math.pi * 2 * 1.3, -0.4, 1.0, _goldBright.withValues(alpha: 0.15));

    // ── 4. Energy arcs ──
    _drawEnergyArcs(canvas, center, R * 0.7);

    // ── 5. Inner core ──
    final coreR = R * (0.12 + pulse * 0.04);
    canvas.drawCircle(
      center,
      coreR * 2.5,
      Paint()
        ..shader = ui.Gradient.radial(center, coreR * 2.5, [
          _goldBright.withValues(alpha: 0.25 + pulse * 0.15),
          _gold.withValues(alpha: 0.08),
          Colors.transparent,
        ], [0.0, 0.4, 1.0]),
    );
    canvas.drawCircle(
      center,
      coreR,
      Paint()
        ..shader = ui.Gradient.radial(center, coreR, [
          _white.withValues(alpha: 0.9),
          _goldBright.withValues(alpha: 0.6),
          _gold.withValues(alpha: 0.2),
        ], [0.0, 0.4, 1.0]),
    );

    // ── 6. Progress arc (outer) ──
    final progressPaint = Paint()
      ..color = _goldBright.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: R + 4),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      progressPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: R + 4),
      -math.pi / 2 + math.pi * 2 * progress,
      math.pi * 2 * (1 - progress),
      false,
      Paint()
        ..color = _gold.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // ── 7. Scan lines (subtle) ──
    for (int i = 0; i < 3; i++) {
      final angle = time * math.pi * 2 + i * math.pi * 2 / 3;
      final endP = Offset(cx + math.cos(angle) * R * 0.9, cy + math.sin(angle) * R * 0.9);
      canvas.drawLine(
        center,
        endP,
        Paint()
          ..shader = ui.Gradient.linear(center, endP, [
            Colors.transparent,
            _gold.withValues(alpha: 0.08),
            _goldBright.withValues(alpha: 0.12),
            Colors.transparent,
          ], [0.0, 0.3, 0.7, 1.0])
          ..strokeWidth = 0.8,
      );
    }
  }

  void _drawStarParticles(Canvas canvas, Offset center, double R) {
    final count = 120;
    final rng = math.Random(42);

    for (int i = 0; i < count; i++) {
      // Fibonacci sphere distribution
      final phi = math.acos(1 - 2 * (i + 0.5) / count);
      final theta = math.pi * (1 + math.sqrt(5)) * i;

      // Animate: rotate + breathe
      final rotatedTheta = theta + time * math.pi * 2 * (0.2 + (i % 3) * 0.1);
      final breathe = 1.0 + math.sin(time * math.pi * 2 * 2 + i * 0.3) * 0.06 * pulse;
      final r = R * 0.75 * breathe;

      // Project 3D → 2D
      final x3d = r * math.sin(phi) * math.cos(rotatedTheta);
      final y3d = r * math.sin(phi) * math.sin(rotatedTheta);
      final z3d = r * math.cos(phi);

      // Simple perspective
      final depth = (z3d / (R * 0.75) + 1) / 2; // 0..1, 1 = front
      final px = center.dx + x3d;
      final py = center.dy + y3d * 0.85; // slight vertical compression

      final alpha = (0.15 + depth * 0.7) * (0.7 + pulse * 0.3);
      final sz = (0.5 + depth * 2.5) * (0.8 + pulse * 0.2);

      // Twinkle
      final twinkle = (math.sin(sparkPhase * math.pi * 2 * 3 + i * 1.7) * 0.5 + 0.5);

      final color = depth > 0.6
          ? Color.lerp(_goldBright, _white, twinkle * 0.5)!
          : Color.lerp(_goldDim, _gold, depth)!;

      canvas.drawCircle(
        Offset(px, py),
        sz,
        Paint()..color = color.withValues(alpha: alpha * (0.6 + twinkle * 0.4)),
      );

      // Glow for bright particles
      if (depth > 0.7 && twinkle > 0.6) {
        canvas.drawCircle(
          Offset(px, py),
          sz * 3,
          Paint()..color = _gold.withValues(alpha: alpha * 0.1),
        );
      }
    }
  }

  void _drawOrbitalRing(Canvas canvas, Offset center, double radius, double rotation, double tiltY, double width, Color color) {
    final points = 60;
    final path = ui.Path();

    for (int i = 0; i <= points; i++) {
      final t = i / points;
      final angle = t * math.pi * 2 + rotation;

      // 3D circle tilted on Y axis
      final x3d = radius * math.cos(angle);
      final z3d = radius * math.sin(angle);
      final y3d = z3d * math.sin(tiltY);
      final z_proj = z3d * math.cos(tiltY);

      final px = center.dx + x3d;
      final py = center.dy + y3d;

      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawEnergyArcs(Canvas canvas, Offset center, double R) {
    final arcCount = 5;
    final rng = math.Random(99);

    for (int i = 0; i < arcCount; i++) {
      final startAngle = rng.nextDouble() * math.pi * 2 + time * math.pi * 4;
      final arcLen = 0.3 + rng.nextDouble() * 0.5;
      final r = R * (0.4 + rng.nextDouble() * 0.5);
      final alpha = (0.05 + pulse * 0.08) * (math.sin(sparkPhase * math.pi * 2 * 2 + i * 2) * 0.5 + 0.5);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        startAngle,
        arcLen,
        false,
        Paint()
          ..color = _goldBright.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HoloOrbPainter old) => true;
}
