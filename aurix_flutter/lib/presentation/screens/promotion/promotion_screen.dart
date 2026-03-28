import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_page_scaffold.dart';
import 'package:aurix_flutter/presentation/screens/studio_ai/generate_cover_screen.dart';
import 'package:aurix_flutter/presentation/screens/studio_ai/studio_ai_screen.dart';

/// Promo hub — 4 promotion tools.
class PromotionScreen extends StatelessWidget {
  const PromotionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumPageScaffold(
      title: 'Промо',
      subtitle: 'Продвигай музыку и создавай контент',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(children: [
            _PromoCard(
              icon: Icons.videocam_rounded,
              title: 'Контент',
              description: 'Reels-идеи и видео для продвижения',
              accent: AurixTokens.accent,
              onTap: () => _openChat(context, 'reels'),
            ),
            const SizedBox(height: 14),
            _PromoCard(
              icon: Icons.palette_rounded,
              title: 'Визуал',
              description: 'Обложка и промо-видео для трека',
              accent: AurixTokens.aiAccent,
              onTap: () => _openVisual(context),
            ),
            const SizedBox(height: 14),
            _PromoCard(
              icon: Icons.rocket_launch_rounded,
              title: 'Продвижение',
              description: 'Стратегия выхода и продвижения',
              accent: AurixTokens.positive,
              onTap: () => _openChat(context, 'chat'),
            ),
            const SizedBox(height: 14),
            _PromoCard(
              icon: Icons.analytics_rounded,
              title: 'Анализ',
              description: 'Разбор трека и аудитории',
              accent: AurixTokens.warning,
              onTap: () => _openChat(context, 'analyze'),
            ),
          ]),
        ),
      ],
    );
  }

  void _openChat(BuildContext context, String mode) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PromoChatWrapper(mode: mode),
      ),
    );
  }

  void _openVisual(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _VisualHubScreen()),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Visual Hub — cover + video
// ══════════════════════════════════════════════════════════════

class _VisualHubScreen extends StatelessWidget {
  const _VisualHubScreen();

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
        title: const Text(
          'Визуал',
          style: TextStyle(color: AurixTokens.text, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(children: [
              _PromoCard(
                icon: Icons.palette_rounded,
                title: 'Создать обложку',
                description: 'Сгенерируем обложку под твой стиль',
                accent: AurixTokens.aiAccent,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GenerateCoverScreen()),
                ),
              ),
              const SizedBox(height: 14),
              _PromoCard(
                icon: Icons.videocam_rounded,
                title: 'Создать видео',
                description: 'Промо-видео из твоего трека',
                accent: AurixTokens.accent,
                onTap: () {
                  Navigator.of(context).pop();
                  GoRouter.of(context).push('/promo/video');
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Chat Wrapper
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
        title: const Text(
          'Aurix AI',
          style: TextStyle(color: AurixTokens.text, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: const StudioAiScreen(),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Promo Card (reused across the file)
// ══════════════════════════════════════════════════════════════

class _PromoCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final VoidCallback onTap;

  const _PromoCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_PromoCard> createState() => _PromoCardState();
}

class _PromoCardState extends State<_PromoCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _hovered
                    ? widget.accent.withValues(alpha: 0.08)
                    : AurixTokens.glass(0.05),
                AurixTokens.bg2.withValues(alpha: _hovered ? 0.4 : 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hovered
                  ? widget.accent.withValues(alpha: 0.3)
                  : AurixTokens.stroke(0.1),
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.08),
                      blurRadius: 32,
                      spreadRadius: -8,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: RadialGradient(colors: [
                  widget.accent.withValues(alpha: _hovered ? 0.2 : 0.12),
                  widget.accent.withValues(alpha: 0.03),
                ]),
                border: Border.all(
                  color: widget.accent.withValues(alpha: _hovered ? 0.25 : 0.1),
                ),
              ),
              child: Icon(widget.icon, size: 24, color: widget.accent),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: AurixTokens.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.description,
                    style: TextStyle(
                      color: AurixTokens.muted.withValues(alpha: 0.7),
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: _hovered ? widget.accent : AurixTokens.muted.withValues(alpha: 0.4),
            ),
          ]),
        ),
      ),
    );
  }
}
