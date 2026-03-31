import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';

/// Wraps a section in a hover-lift premium card.
class HomeSectionCard extends StatelessWidget {
  const HomeSectionCard({super.key, required this.child, this.glowColor});
  final Widget child;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    return PremiumHoverLift(
      enabled: desktop,
      child: PremiumSectionCard(
        padding: const EdgeInsets.all(20),
        glowColor: glowColor,
        child: child,
      ),
    );
  }
}

class HomeSectionTitle extends StatelessWidget {
  const HomeSectionTitle(this.title, {super.key, this.icon});
  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: AurixTokens.accent),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: TextStyle(
            fontFamily: AurixTokens.fontHeading,
            color: AurixTokens.text,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}

class HomeMetricTile extends StatelessWidget {
  const HomeMetricTile({super.key, required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return PremiumMetricTile(label: title, value: value);
  }
}

class HomeDashboardHeader extends StatelessWidget {
  const HomeDashboardHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 900;
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AurixTokens.radiusHero),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AurixTokens.bg1,
            AurixTokens.surface2.withValues(alpha: 0.8),
            AurixTokens.bg1.withValues(alpha: 0.95),
          ],
        ),
        border: Border.all(color: AurixTokens.stroke(0.18)),
        boxShadow: AurixTokens.elevatedShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // System label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AurixTokens.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AurixTokens.positive,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AurixTokens.positive.withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  'ARTIST CONTROL SYSTEM',
                  style: TextStyle(
                    fontFamily: AurixTokens.fontMono,
                    color: AurixTokens.accentWarm,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '\u0426\u0435\u043d\u0442\u0440 \u0443\u043f\u0440\u0430\u0432\u043b\u0435\u043d\u0438\u044f',
            style: TextStyle(
              fontFamily: AurixTokens.fontHeading,
              color: AurixTokens.text,
              fontSize: isMobile ? 24 : 30,
              height: 1.1,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\u041a\u043b\u044e\u0447\u0435\u0432\u044b\u0435 \u0434\u0435\u0439\u0441\u0442\u0432\u0438\u044f, \u0442\u0435\u043a\u0443\u0449\u0438\u0439 \u0444\u043e\u043a\u0443\u0441 \u0438 \u043f\u0440\u043e\u0433\u0440\u0435\u0441\u0441 \u043a\u0430\u043c\u043f\u0430\u043d\u0438\u0438.',
            style: TextStyle(
              fontFamily: AurixTokens.fontBody,
              color: AurixTokens.muted,
              height: 1.5,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              PremiumChip(label: 'Release OS', icon: Icons.album_rounded, selected: true),
              PremiumChip(label: '\u0424\u043e\u043a\u0443\u0441 \u043d\u0435\u0434\u0435\u043b\u0438', icon: Icons.track_changes_rounded),
              PremiumChip(label: '\u0420\u043e\u0441\u0442 \u0438 \u0430\u043d\u0430\u043b\u0438\u0442\u0438\u043a\u0430', icon: Icons.insights_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class HomeLoadingSkeleton extends StatelessWidget {
  const HomeLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        PremiumSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumSkeletonBox(height: 18, width: 260),
              SizedBox(height: 8),
              PremiumSkeletonBox(height: 12, width: 340),
            ],
          ),
        ),
        SizedBox(height: 16),
        PremiumSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumSkeletonBox(height: 22, width: 200),
              SizedBox(height: 12),
              PremiumSkeletonBox(height: 10),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: PremiumSkeletonBox(height: 44)),
                  SizedBox(width: 10),
                  Expanded(child: PremiumSkeletonBox(height: 44)),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        PremiumSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumSkeletonBox(height: 16, width: 180),
              SizedBox(height: 12),
              PremiumSkeletonBox(height: 96),
            ],
          ),
        ),
      ],
    );
  }
}

/// Staggered fade-slide entrance animation.
class HomeAppear extends StatefulWidget {
  const HomeAppear({
    super.key,
    required this.child,
    required this.delayMs,
    required this.reduceMotion,
  });

  final Widget child;
  final int delayMs;
  final bool reduceMotion;

  @override
  State<HomeAppear> createState() => _HomeAppearState();
}

class _HomeAppearState extends State<HomeAppear> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    if (widget.reduceMotion) {
      _show = true;
    } else {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) setState(() => _show = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduceMotion) return widget.child;
    return AnimatedOpacity(
      opacity: _show ? 1 : 0,
      duration: AurixTokens.dEntrance,
      curve: AurixTokens.cEase,
      child: AnimatedSlide(
        offset: _show ? Offset.zero : const Offset(0, 0.03),
        duration: AurixTokens.dEntrance,
        curve: AurixTokens.cEase,
        child: widget.child,
      ),
    );
  }
}
