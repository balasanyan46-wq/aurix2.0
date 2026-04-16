import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

/// Premium AURIX logo with gradient icon, glow, and refined typography.
class AurixPremiumLogo extends StatelessWidget {
  const AurixPremiumLogo({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 28.0 : 34.0;
    final fontSize = compact ? 14.0 : 16.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon mark
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.3),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFF8C42), // accent orange
                Color(0xFFFF6B1A), // deeper orange
                Color(0xFFE85D10), // warm
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF8C42).withValues(alpha: 0.35),
                blurRadius: 16,
                spreadRadius: -4,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: const Color(0xFFFF6B1A).withValues(alpha: 0.15),
                blurRadius: 32,
                spreadRadius: -8,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: CustomPaint(
              size: Size(size * 0.5, size * 0.5),
              painter: _AurixIconPainter(),
            ),
          ),
        ),
        SizedBox(width: compact ? 8 : 10),
        // Wordmark
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFE8E6F0),
              Color(0xFFCCCAD6),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(bounds),
          child: Text(
            'AURIX',
            style: TextStyle(
              fontFamily: AurixTokens.fontDisplay,
              color: Colors.white,
              fontSize: fontSize,
              letterSpacing: 4,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for the "A" icon with a modern geometric design.
class _AurixIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Stylized "A" shape — modern geometric
    final path = Path()
      ..moveTo(w * 0.5, h * 0.05) // top center
      ..lineTo(w * 0.88, h * 0.95) // bottom right
      ..lineTo(w * 0.68, h * 0.95) // inner right
      ..lineTo(w * 0.58, h * 0.65) // crossbar right
      ..lineTo(w * 0.42, h * 0.65) // crossbar left
      ..lineTo(w * 0.32, h * 0.95) // inner left
      ..lineTo(w * 0.12, h * 0.95) // bottom left
      ..close();

    canvas.drawPath(path, paint);

    // Cut out the inner triangle
    final cutPaint = Paint()
      ..blendMode = BlendMode.clear;

    final cutPath = Path()
      ..moveTo(w * 0.5, h * 0.32)
      ..lineTo(w * 0.55, h * 0.52)
      ..lineTo(w * 0.45, h * 0.52)
      ..close();

    canvas.saveLayer(Rect.fromLTWH(0, 0, w, h), Paint());
    canvas.drawPath(path, paint);
    canvas.drawPath(cutPath, cutPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
