import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

/// Subtle premium upsell card for professional mixing service.
class UpsellCard extends StatefulWidget {
  final VoidCallback? onTap;

  const UpsellCard({super.key, this.onTap});

  @override
  State<UpsellCard> createState() => _UpsellCardState();
}

class _UpsellCardState extends State<UpsellCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmer;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AurixTokens.dMedium,
          curve: AurixTokens.cEase,
          padding: const EdgeInsets.all(AurixTokens.s20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AurixTokens.aiAccent.withValues(alpha: _hovering ? 0.1 : 0.06),
                AurixTokens.accent.withValues(alpha: _hovering ? 0.06 : 0.03),
              ],
            ),
            border: Border.all(
              color: AurixTokens.aiAccent.withValues(alpha: _hovering ? 0.3 : 0.15),
            ),
          ),
          child: Row(
            children: [
              // Icon with shimmer
              AnimatedBuilder(
                animation: _shimmer,
                builder: (context, child) {
                  return Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
                      gradient: LinearGradient(
                        begin: Alignment(-1.0 + _shimmer.value * 3, 0),
                        end: Alignment(0.0 + _shimmer.value * 3, 0),
                        colors: [
                          AurixTokens.aiAccent.withValues(alpha: 0.08),
                          AurixTokens.aiAccent.withValues(alpha: 0.2),
                          AurixTokens.aiAccent.withValues(alpha: 0.08),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                    child: Icon(
                      Icons.diamond_outlined,
                      size: 24,
                      color: AurixTokens.aiGlow,
                    ),
                  );
                },
              ),
              const SizedBox(width: AurixTokens.s16),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Хочешь звучать как на стримингах?',
                      style: TextStyle(
                        fontFamily: AurixTokens.fontBody,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AurixTokens.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Профессиональное сведение от AI',
                      style: TextStyle(
                        fontFamily: AurixTokens.fontBody,
                        fontSize: 12,
                        color: AurixTokens.aiSoft.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AurixTokens.aiAccent.withValues(alpha: 0.12),
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: AurixTokens.aiGlow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
