import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';
import 'widgets/result_player.dart';
import 'widgets/track_readiness.dart';
import 'widgets/result_actions.dart';
import 'widgets/upsell_card.dart';

/// Track Result Screen — post-export engagement screen.
///
/// Shows the exported track with waveform player, readiness analysis,
/// action buttons for next steps, and subtle upsell.
class TrackResultScreen extends StatefulWidget {
  /// Blob URL for the exported audio file.
  final String? blobUrl;

  /// Optional waveform data from the studio.
  final Float32List? waveformData;

  /// Track name for display.
  final String trackName;

  const TrackResultScreen({
    super.key,
    this.blobUrl,
    this.waveformData,
    this.trackName = 'Мой демо',
  });

  @override
  State<TrackResultScreen> createState() => _TrackResultScreenState();
}

class _TrackResultScreenState extends State<TrackResultScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerGlow;
  Offset _parallax = Offset.zero;

  @override
  void initState() {
    super.initState();
    _headerGlow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _headerGlow.dispose();
    super.dispose();
  }

  void _onDownload() {
    if (widget.blobUrl == null) return;
    final a = web.document.createElement('a') as web.HTMLAnchorElement;
    a.href = widget.blobUrl!;
    a.download = '${widget.trackName}.wav';
    a.click();
  }

  void _onImproveTrack() {
    // Navigate to AI analysis with track context
    context.push('/ai?mode=analyze');
  }

  void _onAutoPolish() {
    // Navigate to AI with auto-polish mode
    context.push('/ai?mode=polish&prompt=Улучши звучание моего демо трека');
  }

  void _onRelease() {
    context.push('/releases/create');
  }

  void _onPromo() {
    context.push('/promo');
  }

  void _onShare() {
    // Generate share link (placeholder - would integrate with smart-link)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Ссылка скопирована'),
        backgroundColor: AurixTokens.positive,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
        ),
      ),
    );
  }

  void _onUpsell() {
    context.push('/ai?mode=mix&prompt=Сделай профессиональное сведение');
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: MouseRegion(
        onHover: (e) {
          setState(() {
            _parallax = Offset(
              (e.position.dx / mq.size.width - 0.5) * 10,
              (e.position.dy / mq.size.height - 0.5) * 6,
            );
          });
        },
        child: Stack(
          children: [
            // Atmospheric background
            _ResultBackground(
              parallax: _parallax,
              glowAnimation: _headerGlow,
            ),

            // Content
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: _buildContent(mq.size.width > 700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AurixTokens.s16,
        vertical: AurixTokens.s8,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AurixTokens.surface1.withValues(alpha: 0.5),
                border: Border.all(color: AurixTokens.stroke(0.15)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: AurixTokens.textSecondary,
              ),
            ),
          ),
          const Spacer(),
          // Download button
          GestureDetector(
            onTap: _onDownload,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: AurixTokens.surface1.withValues(alpha: 0.5),
                border: Border.all(color: AurixTokens.stroke(0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_rounded,
                      size: 16, color: AurixTokens.accent),
                  const SizedBox(width: 6),
                  Text(
                    'WAV',
                    style: TextStyle(
                      fontFamily: AurixTokens.fontMono,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AurixTokens.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isWide) {
    final maxWidth = isWide ? 520.0 : double.infinity;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AurixTokens.s20),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AurixTokens.s24),

              // ─── Header ───
              FadeInSlide(
                delayMs: 0,
                child: _buildHeader(),
              ),
              const SizedBox(height: AurixTokens.s32),

              // ─── Player ───
              FadeInSlide(
                delayMs: 150,
                child: ResultPlayer(
                  blobUrl: widget.blobUrl ?? '',
                  waveformData: widget.waveformData,
                ),
              ),
              const SizedBox(height: AurixTokens.s24),

              // ─── Track Readiness ───
              FadeInSlide(
                delayMs: 300,
                child: const TrackReadinessBlock(
                  overallPercent: 63,
                  soundPercent: 70,
                  hookPercent: 55,
                  ideaPercent: 80,
                ),
              ),
              const SizedBox(height: AurixTokens.s24),

              // ─── Actions ───
              FadeInSlide(
                delayMs: 450,
                child: ResultActions(
                  onImproveTrack: _onImproveTrack,
                  onAutoPolish: _onAutoPolish,
                  onRelease: _onRelease,
                  onPromo: _onPromo,
                  onShare: _onShare,
                ),
              ),
              const SizedBox(height: AurixTokens.s24),

              // ─── Upsell ───
              FadeInSlide(
                delayMs: 600,
                child: UpsellCard(onTap: _onUpsell),
              ),

              const SizedBox(height: AurixTokens.s48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _headerGlow,
      builder: (context, child) {
        return Column(
          children: [
            // Success checkmark
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AurixTokens.positive.withValues(
                      alpha: 0.12 + _headerGlow.value * 0.08,
                    ),
                    Colors.transparent,
                  ],
                ),
                border: Border.all(
                  color: AurixTokens.positive.withValues(alpha: 0.25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AurixTokens.positive.withValues(
                      alpha: 0.1 + _headerGlow.value * 0.08,
                    ),
                    blurRadius: 24,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Icon(
                Icons.check_rounded,
                size: 28,
                color: AurixTokens.positive,
              ),
            ),
            const SizedBox(height: AurixTokens.s16),

            // Title
            Text(
              'Твой трек готов',
              style: TextStyle(
                fontFamily: AurixTokens.fontDisplay,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AurixTokens.text,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: AurixTokens.s6),

            // Subtitle
            Text(
              'Осталось немного до финального звучания',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AurixTokens.fontBody,
                fontSize: 14,
                color: AurixTokens.muted,
                height: 1.5,
              ),
            ),

            // Track name badge
            if (widget.trackName.isNotEmpty) ...[
              const SizedBox(height: AurixTokens.s12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: AurixTokens.surface1.withValues(alpha: 0.5),
                  border: Border.all(color: AurixTokens.stroke(0.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.music_note_rounded,
                      size: 14,
                      color: AurixTokens.accent.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.trackName,
                      style: TextStyle(
                        fontFamily: AurixTokens.fontBody,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AurixTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Atmospheric background for result screen.
class _ResultBackground extends StatelessWidget {
  final Offset parallax;
  final AnimationController glowAnimation;

  const _ResultBackground({
    required this.parallax,
    required this.glowAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, _) {
        return Stack(
          children: [
            Container(color: const Color(0xFF050505)),

            // Success glow (green, top-center)
            Positioned(
              left: size.width / 2 - 180 + parallax.dx,
              top: -60 + parallax.dy,
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AurixTokens.positive.withValues(
                        alpha: 0.03 + glowAnimation.value * 0.015,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Purple orb (bottom-right)
            Positioned(
              right: -60 + parallax.dx * 0.5,
              bottom: size.height * 0.3 + parallax.dy * 0.4,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AurixTokens.aiAccent.withValues(alpha: 0.02),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Bottom gradient fade
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: size.height * 0.3,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF050505).withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
