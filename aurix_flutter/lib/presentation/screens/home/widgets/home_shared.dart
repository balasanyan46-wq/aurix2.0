import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/presentation/providers/subscription_provider.dart';

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
  const HomeSectionTitle(this.title, {super.key, this.icon, this.trailing});
  final String title;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
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
        if (trailing != null) ...[
          const Spacer(),
          trailing!,
        ],
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

/// Hero greeting with user avatar, name, plan badge and date.
class HomeDashboardHeader extends ConsumerWidget {
  const HomeDashboardHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final plan = ref.watch(effectivePlanProvider);
    final isMobile = MediaQuery.sizeOf(context).width < 900;

    final artistName = profile?.artistName;
    final userName = profile?.name ?? user?.name;
    final displayName = (artistName != null && artistName.length > 1)
        ? artistName
        : (userName != null && userName.length > 1)
            ? userName
            : null;
    final greeting = _greeting();
    final dateStr = _dateString();

    return Container(
      padding: EdgeInsets.all(isMobile ? 18 : 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AurixTokens.accent.withValues(alpha: 0.08),
            AurixTokens.bg1.withValues(alpha: 0.95),
            AurixTokens.aiAccent.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: AurixTokens.accent.withValues(alpha: 0.06),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: isMobile ? 48 : 56,
            height: isMobile ? 48 : 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AurixTokens.accent, AurixTokens.accentWarm],
              ),
              boxShadow: [
                BoxShadow(
                  color: AurixTokens.accent.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _initials(displayName),
                style: TextStyle(
                  fontFamily: AurixTokens.fontHeading,
                  color: Colors.white,
                  fontSize: isMobile ? 18 : 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    fontFamily: AurixTokens.fontBody,
                    color: AurixTokens.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayName ?? 'Добро пожаловать',
                  style: TextStyle(
                    fontFamily: AurixTokens.fontHeading,
                    color: AurixTokens.text,
                    fontSize: isMobile ? 20 : 26,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontFamily: AurixTokens.fontBody,
                    color: AurixTokens.micro,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _PlanBadge(plan: plan),
        ],
      ),
    );
  }

  static String _initials(String? name) {
    if (name == null || name.isEmpty) return 'A';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return 'Доброй ночи';
    if (h < 12) return 'Доброе утро';
    if (h < 18) return 'Добрый день';
    return 'Добрый вечер';
  }

  static String _dateString() {
    final now = DateTime.now();
    const months = ['января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря'];
    const days = ['Понедельник','Вторник','Среда','Четверг','Пятница','Суббота','Воскресенье'];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.plan});
  final String plan;

  @override
  Widget build(BuildContext context) {
    final label = switch (plan) {
      'empire' => 'EMPIRE',
      'breakthrough' => 'BREAKTHROUGH',
      'start' => 'START',
      _ => 'FREE',
    };
    final color = switch (plan) {
      'empire' => AurixTokens.warning,
      'breakthrough' => AurixTokens.accent,
      'start' => AurixTokens.positive,
      _ => AurixTokens.muted,
    };
    final isTop = plan == 'empire' || plan == 'breakthrough';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: isTop
            ? LinearGradient(
                colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.06)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isTop ? null : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: isTop
            ? [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isTop) ...[
            Icon(Icons.diamond_rounded, size: 16, color: color),
            const SizedBox(height: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: AurixTokens.fontMono,
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
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
              PremiumSkeletonBox(height: 14, width: 100),
              SizedBox(height: 6),
              PremiumSkeletonBox(height: 24, width: 220),
            ],
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: PremiumSectionCard(child: PremiumSkeletonBox(height: 72))),
            SizedBox(width: 12),
            Expanded(child: PremiumSectionCard(child: PremiumSkeletonBox(height: 72))),
            SizedBox(width: 12),
            Expanded(child: PremiumSectionCard(child: PremiumSkeletonBox(height: 72))),
          ],
        ),
        SizedBox(height: 16),
        PremiumSectionCard(child: PremiumSkeletonBox(height: 160)),
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
