import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';

/// Wraps a section in a hover-lift premium card.
class HomeSectionCard extends StatelessWidget {
  const HomeSectionCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    return PremiumHoverLift(
      enabled: desktop,
      child: PremiumSectionCard(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}

class HomeSectionTitle extends StatelessWidget {
  const HomeSectionTitle(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AurixTokens.text,
        fontSize: 17,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.1,
      ),
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
    return const PremiumHeroBlock(
      title: 'Центр управления релизом',
      subtitle:
          'Ключевые действия, текущий фокус и прогресс кампании в одном месте. Чистый операционный обзор без визуального шума.',
      pills: [
        PremiumChip(label: 'Release OS', icon: Icons.album_rounded, selected: true),
        PremiumChip(label: 'Фокус недели', icon: Icons.track_changes_rounded),
        PremiumChip(label: 'Рост и аналитика', icon: Icons.insights_rounded),
      ],
      trailing: Icon(
        Icons.auto_graph_rounded,
        size: 28,
        color: AurixTokens.accentWarm,
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
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _show ? Offset.zero : const Offset(0, 0.04),
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
