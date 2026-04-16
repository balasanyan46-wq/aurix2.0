import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_page_scaffold.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';
import 'package:aurix_flutter/presentation/screens/studio_ai/generate_cover_screen.dart';
import 'package:aurix_flutter/presentation/screens/studio_ai/studio_ai_screen.dart';
import 'package:aurix_flutter/core/services/event_tracker.dart';
import 'package:aurix_flutter/design/widgets/section_onboarding.dart';

/// Content Engine — the creative control system for promotion.
class PromotionScreen extends StatefulWidget {
  const PromotionScreen({super.key});

  @override
  State<PromotionScreen> createState() => _PromotionScreenState();
}

class _PromotionScreenState extends State<PromotionScreen> {
  @override
  void initState() {
    super.initState();
    EventTracker.track('viewed_promo');
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final isMedium = MediaQuery.sizeOf(context).width >= 600;

    return PremiumPageScaffold(
      title: '\u041a\u043e\u043d\u0442\u0435\u043d\u0442 = \u0440\u043e\u0441\u0442',
      subtitle:
          '\u0421\u043e\u0437\u0434\u0430\u0432\u0430\u0439 \u043a\u043e\u043d\u0442\u0435\u043d\u0442, \u043a\u043e\u0442\u043e\u0440\u044b\u0439 \u043f\u0440\u043e\u0434\u0432\u0438\u0433\u0430\u0435\u0442. \u0412\u0438\u0437\u0443\u0430\u043b, \u0432\u0438\u0434\u0435\u043e, \u0441\u0442\u0440\u0430\u0442\u0435\u0433\u0438\u044f \u2014 \u0432\u0441\u0451 \u0432 \u043e\u0434\u043d\u043e\u043c \u043c\u0435\u0441\u0442\u0435.',
      systemLabel: 'CONTENT ENGINE',
      systemColor: AurixTokens.accent,
      children: [
        SectionOnboarding(tip: OnboardingTips.promo),
        // Live stats bar
        FadeInSlide(
          delayMs: 60,
          child: _ContentStatsBar(isDesktop: isDesktop),
        ),
        const SizedBox(height: 20),
        // Main grid
        _ContentGrid(isDesktop: isDesktop, isMedium: isMedium),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Live Stats Bar — engagement overview
// ══════════════════════════════════════════════════════════════

class _ContentStatsBar extends StatelessWidget {
  const _ContentStatsBar({required this.isDesktop});
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 14,
        vertical: isDesktop ? 14 : 10,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
        gradient: LinearGradient(
          colors: [
            AurixTokens.surface1.withValues(alpha: 0.6),
            AurixTokens.surface2.withValues(alpha: 0.3),
          ],
        ),
        border: Border.all(color: AurixTokens.stroke(0.14)),
      ),
      child: Row(
        children: [
          _StatChip(
            icon: Icons.trending_up_rounded,
            label: '\u041e\u0445\u0432\u0430\u0442',
            value: '+24%',
            color: AurixTokens.positive,
          ),
          const SizedBox(width: 16),
          _StatChip(
            icon: Icons.visibility_rounded,
            label: '\u041f\u0440\u043e\u0441\u043c\u043e\u0442\u0440\u044b',
            value: '12.4K',
            color: AurixTokens.accent,
          ),
          const SizedBox(width: 16),
          _StatChip(
            icon: Icons.favorite_rounded,
            label: 'ER',
            value: '6.2%',
            color: AurixTokens.aiAccent,
          ),
          if (isDesktop) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AurixTokens.positive.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AurixTokens.positive.withValues(alpha: 0.15)),
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
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '\u0412\u0441\u0435 \u0441\u0438\u0441\u0442\u0435\u043c\u044b \u0430\u043a\u0442\u0438\u0432\u043d\u044b',
                    style: TextStyle(
                      fontFamily: AurixTokens.fontMono,
                      color: AurixTokens.positive,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: AurixTokens.fontMono,
                color: AurixTokens.micro,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontFamily: AurixTokens.fontMono,
                color: AurixTokens.text,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFeatures: AurixTokens.tabularFigures,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Content Grid — 2x2 on desktop, stack on mobile
// ══════════════════════════════════════════════════════════════

class _ContentGrid extends StatelessWidget {
  const _ContentGrid({required this.isDesktop, required this.isMedium});
  final bool isDesktop;
  final bool isMedium;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _ContentBlockData(
        tag: 'REELS / TIKTOK',
        title: '\u041a\u043e\u043d\u0442\u0435\u043d\u0442-\u043c\u0430\u0448\u0438\u043d\u0430',
        subtitle: 'AI \u0433\u0435\u043d\u0435\u0440\u0438\u0440\u0443\u0435\u0442 \u0438\u0434\u0435\u0438 \u0434\u043b\u044f Reels, TikTok, Shorts',
        icon: Icons.videocam_rounded,
        accent: AurixTokens.accent,
        viralScore: 87,
        difficulty: '\u041b\u0451\u0433\u043a\u0438\u0439',
        difficultyColor: AurixTokens.positive,
        previewType: _PreviewType.reels,
        cta: '\u0421\u043e\u0437\u0434\u0430\u0442\u044c \u0438\u0434\u0435\u0438',
        onTap: () => _openChat(context, 'reels'),
      ),
      _ContentBlockData(
        tag: '\u0412\u0418\u0417\u0423\u0410\u041b',
        title: '\u041e\u0431\u043b\u043e\u0436\u043a\u0430 & \u0412\u0438\u0434\u0435\u043e',
        subtitle: 'AI-\u043e\u0431\u043b\u043e\u0436\u043a\u0438, \u043f\u0440\u043e\u043c\u043e-\u0432\u0438\u0434\u0435\u043e \u0438 \u0432\u0438\u0437\u0443\u0430\u043b\u044c\u043d\u044b\u0439 \u0441\u0442\u0438\u043b\u044c',
        icon: Icons.palette_rounded,
        accent: AurixTokens.aiAccent,
        viralScore: 72,
        difficulty: '\u0421\u0440\u0435\u0434\u043d\u0438\u0439',
        difficultyColor: AurixTokens.warning,
        previewType: _PreviewType.visual,
        cta: '\u041e\u0442\u043a\u0440\u044b\u0442\u044c \u0441\u0442\u0443\u0434\u0438\u044e',
        onTap: () => _openVisual(context),
      ),
      _ContentBlockData(
        tag: '\u0421\u0422\u0420\u0410\u0422\u0415\u0413\u0418\u042f',
        title: '\u0420\u043e\u0443\u0434\u043c\u0430\u043f \u043f\u0440\u043e\u0434\u0432\u0438\u0436\u0435\u043d\u0438\u044f',
        subtitle: '\u041f\u043e\u043b\u043d\u0430\u044f \u0441\u0442\u0440\u0430\u0442\u0435\u0433\u0438\u044f \u0432\u044b\u0445\u043e\u0434\u0430 \u0438 \u043f\u0440\u043e\u0434\u0432\u0438\u0436\u0435\u043d\u0438\u044f \u0440\u0435\u043b\u0438\u0437\u0430',
        icon: Icons.rocket_launch_rounded,
        accent: AurixTokens.positive,
        viralScore: 64,
        difficulty: '\u041f\u0440\u043e\u0434\u0432\u0438\u043d\u0443\u0442\u044b\u0439',
        difficultyColor: AurixTokens.accent,
        previewType: _PreviewType.roadmap,
        cta: '\u041f\u043e\u0441\u0442\u0440\u043e\u0438\u0442\u044c \u043f\u043b\u0430\u043d',
        onTap: () => _openChat(context, 'chat'),
      ),
      _ContentBlockData(
        tag: '\u0410\u041d\u0410\u041b\u0418\u0417',
        title: '\u0420\u0430\u0437\u0431\u043e\u0440 & \u0418\u043d\u0441\u0430\u0439\u0442\u044b',
        subtitle: '\u0413\u043b\u0443\u0431\u043e\u043a\u0438\u0439 \u0430\u043d\u0430\u043b\u0438\u0437 \u0442\u0440\u0435\u043a\u0430, \u0430\u0443\u0434\u0438\u0442\u043e\u0440\u0438\u0438 \u0438 \u043a\u043e\u043d\u043a\u0443\u0440\u0435\u043d\u0442\u043e\u0432',
        icon: Icons.analytics_rounded,
        accent: AurixTokens.warning,
        viralScore: 91,
        difficulty: '\u041b\u0451\u0433\u043a\u0438\u0439',
        difficultyColor: AurixTokens.positive,
        previewType: _PreviewType.insights,
        cta: '\u0410\u043d\u0430\u043b\u0438\u0437\u0438\u0440\u043e\u0432\u0430\u0442\u044c',
        onTap: () => _openChat(context, 'analyze'),
      ),
    ];

    if (isMedium) {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FadeInSlide(
                  delayMs: 100,
                  child: _ContentBlock(data: cards[0]),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FadeInSlide(
                  delayMs: 160,
                  child: _ContentBlock(data: cards[1]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FadeInSlide(
                  delayMs: 220,
                  child: _ContentBlock(data: cards[2]),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FadeInSlide(
                  delayMs: 280,
                  child: _ContentBlock(data: cards[3]),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Mobile: stacked
    return Column(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          FadeInSlide(
            delayMs: 100 + i * 60,
            child: _ContentBlock(data: cards[i]),
          ),
          if (i < cards.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }

  static void _openChat(BuildContext context, String mode) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PromoChatWrapper(mode: mode),
      ),
    );
  }

  static void _openVisual(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _VisualHubScreen()),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Content Block — big interactive card with preview, stats, CTA
// ══════════════════════════════════════════════════════════════

enum _PreviewType { reels, visual, roadmap, insights }

class _ContentBlockData {
  const _ContentBlockData({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.viralScore,
    required this.difficulty,
    required this.difficultyColor,
    required this.previewType,
    required this.cta,
    required this.onTap,
  });

  final String tag;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final int viralScore;
  final String difficulty;
  final Color difficultyColor;
  final _PreviewType previewType;
  final String cta;
  final VoidCallback onTap;
}

class _ContentBlock extends StatefulWidget {
  const _ContentBlock({required this.data});
  final _ContentBlockData data;

  @override
  State<_ContentBlock> createState() => _ContentBlockState();
}

class _ContentBlockState extends State<_ContentBlock> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: d.onTap,
        child: AnimatedContainer(
          duration: AurixTokens.dMedium,
          curve: AurixTokens.cEase,
          padding: const EdgeInsets.all(0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AurixTokens.radiusHero),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _hovered
                    ? d.accent.withValues(alpha: 0.06)
                    : AurixTokens.surface1.withValues(alpha: 0.5),
                AurixTokens.bg1.withValues(alpha: _hovered ? 0.9 : 0.95),
              ],
            ),
            border: Border.all(
              color: _hovered
                  ? d.accent.withValues(alpha: 0.3)
                  : AurixTokens.stroke(0.14),
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: d.accent.withValues(alpha: 0.1),
                      blurRadius: 40,
                      spreadRadius: -12,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : AurixTokens.subtleShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview area
              _PreviewArea(
                type: d.previewType,
                accent: d.accent,
                hovered: _hovered,
              ),
              // Content area
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tag + viral score row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: d.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: d.accent.withValues(alpha: 0.15)),
                          ),
                          child: Text(
                            d.tag,
                            style: TextStyle(
                              fontFamily: AurixTokens.fontMono,
                              color: d.accent,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const Spacer(),
                        _ViralScoreBadge(score: d.viralScore, accent: d.accent),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Title
                    Text(
                      d.title,
                      style: TextStyle(
                        fontFamily: AurixTokens.fontHeading,
                        color: AurixTokens.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Subtitle
                    Text(
                      d.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AurixTokens.fontBody,
                        color: AurixTokens.muted,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Bottom row: difficulty + CTA
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: d.difficultyColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.speed_rounded, size: 11, color: d.difficultyColor),
                              const SizedBox(width: 4),
                              Text(
                                d.difficulty,
                                style: TextStyle(
                                  fontFamily: AurixTokens.fontBody,
                                  color: d.difficultyColor,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        AnimatedContainer(
                          duration: AurixTokens.dFast,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _hovered
                                ? d.accent.withValues(alpha: 0.15)
                                : d.accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _hovered
                                  ? d.accent.withValues(alpha: 0.35)
                                  : d.accent.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                d.cta,
                                style: TextStyle(
                                  fontFamily: AurixTokens.fontBody,
                                  color: _hovered ? d.accent : AurixTokens.text,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              AnimatedContainer(
                                duration: AurixTokens.dFast,
                                transform: Matrix4.translationValues(
                                  _hovered ? 2.0 : 0.0,
                                  0.0,
                                  0.0,
                                ),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 13,
                                  color: _hovered ? d.accent : AurixTokens.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Viral Score Badge
// ══════════════════════════════════════════════════════════════

class _ViralScoreBadge extends StatelessWidget {
  const _ViralScoreBadge({required this.score, required this.accent});
  final int score;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.12),
            AurixTokens.aiAccent.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, size: 11, color: accent),
          const SizedBox(width: 3),
          Text(
            '$score',
            style: TextStyle(
              fontFamily: AurixTokens.fontMono,
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              fontFeatures: AurixTokens.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Preview Area — visual mock content for each card type
// ══════════════════════════════════════════════════════════════

class _PreviewArea extends StatefulWidget {
  const _PreviewArea({
    required this.type,
    required this.accent,
    required this.hovered,
  });
  final _PreviewType type;
  final Color accent;
  final bool hovered;

  @override
  State<_PreviewArea> createState() => _PreviewAreaState();
}

class _PreviewAreaState extends State<_PreviewArea>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
          child: SizedBox(
            height: 120,
            width: double.infinity,
            child: Stack(
              children: [
                // Background gradient
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.accent.withValues(alpha: 0.06),
                          AurixTokens.bg0.withValues(alpha: 0.8),
                          widget.accent.withValues(alpha: 0.03),
                        ],
                      ),
                    ),
                  ),
                ),
                // Animated glow orb
                Positioned(
                  right: -20 + math.sin(_pulse.value * math.pi * 2) * 10,
                  top: -10 + math.cos(_pulse.value * math.pi * 2) * 8,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          widget.accent.withValues(
                            alpha: widget.hovered ? 0.12 : 0.06,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Type-specific preview content
                _buildPreview(),
                // Subtle grid overlay
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GridOverlayPainter(
                      opacity: widget.hovered ? 0.06 : 0.03,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreview() {
    switch (widget.type) {
      case _PreviewType.reels:
        return _ReelsPreview(accent: widget.accent, t: _pulse.value);
      case _PreviewType.visual:
        return _VisualPreview(accent: widget.accent, t: _pulse.value);
      case _PreviewType.roadmap:
        return _RoadmapPreview(accent: widget.accent, t: _pulse.value);
      case _PreviewType.insights:
        return _InsightsPreview(accent: widget.accent, t: _pulse.value);
    }
  }
}

// ── Reels Preview: phone mockup frames ──

class _ReelsPreview extends StatelessWidget {
  const _ReelsPreview({required this.accent, required this.t});
  final Color accent;
  final double t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Row(
        children: [
          for (int i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _PhoneMockup(
                accent: accent,
                fillProgress: (0.4 + i * 0.25).clamp(0.0, 1.0),
                isActive: i == 0,
                t: t,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhoneMockup extends StatelessWidget {
  const _PhoneMockup({
    required this.accent,
    required this.fillProgress,
    required this.isActive,
    required this.t,
  });
  final Color accent;
  final double fillProgress;
  final bool isActive;
  final double t;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AurixTokens.bg0.withValues(alpha: 0.6),
        border: Border.all(
          color: isActive
              ? accent.withValues(alpha: 0.35)
              : AurixTokens.stroke(0.1),
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          const SizedBox(height: 6),
          // Mock content lines
          for (int j = 0; j < 3; j++) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 6 + j * 2.0),
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: j == 0
                      ? accent.withValues(alpha: 0.2)
                      : AurixTokens.stroke(0.08),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          const Spacer(),
          // Play indicator
          if (isActive)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.25),
                      border: Border.all(color: accent.withValues(alpha: 0.4)),
                    ),
                    child: Icon(Icons.play_arrow_rounded, size: 9, color: accent),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 22),
        ],
      ),
    );
  }
}

// ── Visual Preview: album cover mockups ──

class _VisualPreview extends StatelessWidget {
  const _VisualPreview({required this.accent, required this.t});
  final Color accent;
  final double t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Row(
        children: [
          // Main cover mockup
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.2),
                  AurixTokens.aiAccent.withValues(alpha: 0.15),
                  accent.withValues(alpha: 0.1),
                ],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.12),
                  blurRadius: 16,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 28,
                    color: accent.withValues(alpha: 0.4),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  left: 6,
                  right: 6,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: accent.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Style options
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  Container(
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: i == 0
                          ? accent.withValues(alpha: 0.1)
                          : AurixTokens.surface1.withValues(alpha: 0.4),
                      border: Border.all(
                        color: i == 0
                            ? accent.withValues(alpha: 0.2)
                            : AurixTokens.stroke(0.06),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 6),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: i == 0
                                ? accent.withValues(alpha: 0.25)
                                : AurixTokens.stroke(0.1),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: AurixTokens.stroke(0.08),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Roadmap Preview: timeline mockup ──

class _RoadmapPreview extends StatelessWidget {
  const _RoadmapPreview({required this.accent, required this.t});
  final Color accent;
  final double t;

  @override
  Widget build(BuildContext context) {
    final labels = ['\u041f\u0440\u0435-\u0440\u0435\u043b\u0438\u0437', '\u0417\u0430\u043f\u0443\u0441\u043a', '\u041f\u043e\u0441\u0442-\u043f\u0440\u043e\u043c\u043e'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
      child: Row(
        children: [
          for (int i = 0; i < 3; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= 1
                      ? accent.withValues(alpha: 0.25)
                      : AurixTokens.stroke(0.1),
                ),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == 0
                        ? accent.withValues(alpha: 0.2)
                        : AurixTokens.surface1.withValues(alpha: 0.5),
                    border: Border.all(
                      color: i == 0
                          ? accent.withValues(alpha: 0.4)
                          : AurixTokens.stroke(0.12),
                      width: i == 0 ? 2 : 1,
                    ),
                    boxShadow: i == 0
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.2),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: i == 0
                        ? Icon(Icons.check_rounded, size: 14, color: accent)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontFamily: AurixTokens.fontMono,
                              color: AurixTokens.micro,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  labels[i],
                  style: TextStyle(
                    fontFamily: AurixTokens.fontMono,
                    color: i == 0 ? accent : AurixTokens.micro,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Insights Preview: mini chart bars ──

class _InsightsPreview extends StatelessWidget {
  const _InsightsPreview({required this.accent, required this.t});
  final Color accent;
  final double t;

  @override
  Widget build(BuildContext context) {
    final heights = [0.4, 0.65, 0.5, 0.85, 0.7, 0.9, 0.55, 0.75];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < heights.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AnimatedContainer(
                    duration: AurixTokens.dMedium,
                    height: 80 * heights[i] *
                        (0.8 + math.sin(t * math.pi * 2 + i * 0.5) * 0.2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          accent.withValues(
                            alpha: i == heights.length - 2 ? 0.35 : 0.15,
                          ),
                          accent.withValues(alpha: 0.05),
                        ],
                      ),
                      border: Border.all(
                        color: accent.withValues(
                          alpha: i == heights.length - 2 ? 0.3 : 0.1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Grid Overlay Painter — subtle tech grid on previews
// ══════════════════════════════════════════════════════════════

class _GridOverlayPainter extends CustomPainter {
  const _GridOverlayPainter({required this.opacity});
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AurixTokens.text.withValues(alpha: opacity)
      ..strokeWidth = 0.5;

    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridOverlayPainter old) => old.opacity != opacity;
}

// ══════════════════════════════════════════════════════════════
// Visual Hub — cover + video (redesigned)
// ══════════════════════════════════════════════════════════════

class _VisualHubScreen extends StatelessWidget {
  const _VisualHubScreen();

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AurixTokens.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '\u0412\u0438\u0437\u0443\u0430\u043b\u044c\u043d\u0430\u044f \u0441\u0442\u0443\u0434\u0438\u044f',
          style: TextStyle(
            fontFamily: AurixTokens.fontHeading,
            color: AurixTokens.text,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: FadeInSlide(
                          delayMs: 60,
                          child: _VisualToolCard(
                            icon: Icons.palette_rounded,
                            title: '\u0421\u043e\u0437\u0434\u0430\u0442\u044c \u043e\u0431\u043b\u043e\u0436\u043a\u0443',
                            description: '\u0421\u0433\u0435\u043d\u0435\u0440\u0438\u0440\u0443\u0435\u043c \u043e\u0431\u043b\u043e\u0436\u043a\u0443 \u043f\u043e\u0434 \u0442\u0432\u043e\u0439 \u0441\u0442\u0438\u043b\u044c',
                            accent: AurixTokens.aiAccent,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const GenerateCoverScreen()),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FadeInSlide(
                          delayMs: 120,
                          child: _VisualToolCard(
                            icon: Icons.videocam_rounded,
                            title: '\u0421\u043e\u0437\u0434\u0430\u0442\u044c \u0432\u0438\u0434\u0435\u043e',
                            description: '\u041f\u0440\u043e\u043c\u043e-\u0432\u0438\u0434\u0435\u043e \u0438\u0437 \u0442\u0432\u043e\u0435\u0433\u043e \u0442\u0440\u0435\u043a\u0430',
                            accent: AurixTokens.accent,
                            onTap: () {
                              Navigator.of(context).pop();
                              GoRouter.of(context).push('/promo/video');
                            },
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      FadeInSlide(
                        delayMs: 60,
                        child: _VisualToolCard(
                          icon: Icons.palette_rounded,
                          title: '\u0421\u043e\u0437\u0434\u0430\u0442\u044c \u043e\u0431\u043b\u043e\u0436\u043a\u0443',
                          description: '\u0421\u0433\u0435\u043d\u0435\u0440\u0438\u0440\u0443\u0435\u043c \u043e\u0431\u043b\u043e\u0436\u043a\u0443 \u043f\u043e\u0434 \u0442\u0432\u043e\u0439 \u0441\u0442\u0438\u043b\u044c',
                          accent: AurixTokens.aiAccent,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const GenerateCoverScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FadeInSlide(
                        delayMs: 120,
                        child: _VisualToolCard(
                          icon: Icons.videocam_rounded,
                          title: '\u0421\u043e\u0437\u0434\u0430\u0442\u044c \u0432\u0438\u0434\u0435\u043e',
                          description: '\u041f\u0440\u043e\u043c\u043e-\u0432\u0438\u0434\u0435\u043e \u0438\u0437 \u0442\u0432\u043e\u0435\u0433\u043e \u0442\u0440\u0435\u043a\u0430',
                          accent: AurixTokens.accent,
                          onTap: () {
                            Navigator.of(context).pop();
                            GoRouter.of(context).push('/promo/video');
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _VisualToolCard extends StatefulWidget {
  const _VisualToolCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_VisualToolCard> createState() => _VisualToolCardState();
}

class _VisualToolCardState extends State<_VisualToolCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AurixTokens.dMedium,
          curve: AurixTokens.cEase,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AurixTokens.radiusHero),
            gradient: AurixTokens.cardGradient,
            border: Border.all(
              color: _hovered
                  ? widget.accent.withValues(alpha: 0.3)
                  : AurixTokens.stroke(0.14),
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.1),
                      blurRadius: 32,
                      spreadRadius: -8,
                    ),
                  ]
                : AurixTokens.subtleShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: AurixTokens.dMedium,
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: widget.accent.withValues(alpha: _hovered ? 0.18 : 0.1),
                  border: Border.all(
                    color: widget.accent.withValues(alpha: _hovered ? 0.3 : 0.12),
                  ),
                ),
                child: Icon(widget.icon, size: 24, color: widget.accent),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: TextStyle(
                  fontFamily: AurixTokens.fontHeading,
                  color: AurixTokens.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.description,
                style: TextStyle(
                  fontFamily: AurixTokens.fontBody,
                  color: AurixTokens.muted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              AnimatedContainer(
                duration: AurixTokens.dFast,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: _hovered ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.accent.withValues(alpha: _hovered ? 0.3 : 0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '\u041e\u0442\u043a\u0440\u044b\u0442\u044c',
                      style: TextStyle(
                        fontFamily: AurixTokens.fontBody,
                        color: _hovered ? widget.accent : AurixTokens.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: _hovered ? widget.accent : AurixTokens.muted,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Chat Wrapper (preserved)
// ══════════════════════════════════════════════════════════════

class _PromoChatWrapper extends StatelessWidget {
  final String mode;
  const _PromoChatWrapper({required this.mode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AurixTokens.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Aurix AI',
          style: TextStyle(
            fontFamily: AurixTokens.fontHeading,
            color: AurixTokens.text,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: const StudioAiScreen(),
    );
  }
}
