import 'dart:math';
import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

/// Animated typing indicator with pulsing orb + bouncing dots.
class AiTypingIndicator extends StatefulWidget {
  const AiTypingIndicator({super.key});

  @override
  State<AiTypingIndicator> createState() => _AiTypingIndicatorState();
}

class _AiTypingIndicatorState extends State<AiTypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsing AI icon
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AurixTokens.accent.withValues(alpha: 0.15 + sin(t * 2 * pi) * 0.1),
                    AurixTokens.aiAccent.withValues(alpha: 0.05),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AurixTokens.accentGlow.withValues(alpha: 0.12 + sin(t * 2 * pi) * 0.08),
                    blurRadius: 16,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: AurixTokens.accent.withValues(alpha: 0.6 + sin(t * 2 * pi) * 0.4),
              ),
            ),
            const SizedBox(width: 10),

            // "Aurix думает" text
            Text(
              'Aurix думает',
              style: TextStyle(
                color: AurixTokens.muted.withValues(alpha: 0.6 + sin(t * 2 * pi) * 0.3),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),

            // Bouncing dots
            ...List.generate(3, (i) {
              final phase = (t + i * 0.2) % 1.0;
              final bounce = sin(phase * pi);
              return Transform.translate(
                offset: Offset(0, -bounce * 4),
                child: Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AurixTokens.accent.withValues(alpha: 0.3 + bounce * 0.7),
                    boxShadow: [
                      BoxShadow(
                        color: AurixTokens.accentGlow.withValues(alpha: bounce * 0.3),
                        blurRadius: 6,
                        spreadRadius: -1,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

/// Shimmer skeleton loader for AI response.
class AiResponseSkeleton extends StatefulWidget {
  const AiResponseSkeleton({super.key});

  @override
  State<AiResponseSkeleton> createState() => _AiResponseSkeletonState();
}

class _AiResponseSkeletonState extends State<AiResponseSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final shimmer = AurixTokens.bg2.withValues(alpha: 0.3 + (_ctrl.value * 0.25));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bar(shimmer, width: 0.85),
            const SizedBox(height: 8),
            _bar(shimmer, width: 0.7),
            const SizedBox(height: 8),
            _bar(shimmer, width: 0.55),
          ],
        );
      },
    );
  }

  Widget _bar(Color color, {required double width}) {
    return FractionallySizedBox(
      widthFactor: width,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
