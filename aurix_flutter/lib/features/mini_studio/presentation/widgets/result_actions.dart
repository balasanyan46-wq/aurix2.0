import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

/// Five main action cards for the result screen.
class ResultActions extends StatelessWidget {
  final VoidCallback? onImproveTrack;
  final VoidCallback? onAutoPolish;
  final VoidCallback? onRelease;
  final VoidCallback? onPromo;
  final VoidCallback? onShare;

  const ResultActions({
    super.key,
    this.onImproveTrack,
    this.onAutoPolish,
    this.onRelease,
    this.onPromo,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionCard(
          icon: Icons.auto_awesome_rounded,
          title: 'Улучшить трек',
          subtitle: 'AI анализ и рекомендации',
          color: AurixTokens.aiAccent,
          isPrimary: true,
          onTap: onImproveTrack,
        ),
        const SizedBox(height: AurixTokens.s10),
        _ActionCard(
          icon: Icons.tune_rounded,
          title: 'Сделать звук лучше',
          subtitle: 'Автоматическое улучшение звучания',
          color: AurixTokens.accent,
          onTap: onAutoPolish,
        ),
        const SizedBox(height: AurixTokens.s10),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.rocket_launch_rounded,
                title: 'Выпустить',
                subtitle: 'На стриминги',
                color: AurixTokens.positive,
                compact: true,
                onTap: onRelease,
              ),
            ),
            const SizedBox(width: AurixTokens.s10),
            Expanded(
              child: _ActionCard(
                icon: Icons.campaign_rounded,
                title: 'Промо',
                subtitle: 'Продвижение',
                color: AurixTokens.warning,
                compact: true,
                onTap: onPromo,
              ),
            ),
            const SizedBox(width: AurixTokens.s10),
            Expanded(
              child: _ActionCard(
                icon: Icons.share_rounded,
                title: 'Поделиться',
                subtitle: 'Ссылка',
                color: AurixTokens.textSecondary,
                compact: true,
                onTap: onShare,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isPrimary;
  final bool compact;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.isPrimary = false,
    this.compact = false,
    this.onTap,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounce;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    final primary = widget.isPrimary;
    final compact = widget.compact;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTapDown: (_) => _bounce.forward(),
        onTapUp: (_) {
          _bounce.reverse();
          widget.onTap?.call();
        },
        onTapCancel: () => _bounce.reverse(),
        child: AnimatedBuilder(
          animation: _bounce,
          builder: (context, child) {
            final scale = 1.0 - _bounce.value * 0.03;
            return Transform.scale(scale: scale, child: child);
          },
          child: AnimatedContainer(
            duration: AurixTokens.dMedium,
            curve: AurixTokens.cEase,
            padding: EdgeInsets.all(compact ? AurixTokens.s12 : AurixTokens.s16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
              gradient: primary
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        c.withValues(alpha: _hovering ? 0.18 : 0.12),
                        c.withValues(alpha: _hovering ? 0.08 : 0.04),
                      ],
                    )
                  : null,
              color: primary
                  ? null
                  : (_hovering
                      ? AurixTokens.surface1.withValues(alpha: 0.6)
                      : AurixTokens.surface1.withValues(alpha: 0.35)),
              border: Border.all(
                color: primary
                    ? c.withValues(alpha: _hovering ? 0.4 : 0.25)
                    : AurixTokens.stroke(_hovering ? 0.22 : 0.12),
                width: primary ? 1.5 : 1,
              ),
              boxShadow: _hovering
                  ? [
                      BoxShadow(
                        color: c.withValues(alpha: primary ? 0.12 : 0.05),
                        blurRadius: 20,
                        spreadRadius: -6,
                      ),
                    ]
                  : null,
            ),
            child: compact ? _compactLayout(c) : _fullLayout(c, primary),
          ),
        ),
      ),
    );
  }

  Widget _fullLayout(Color c, bool primary) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
            color: c.withValues(alpha: 0.12),
          ),
          child: Icon(widget.icon, size: 22, color: c),
        ),
        const SizedBox(width: AurixTokens.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  fontFamily: AurixTokens.fontBody,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: primary ? c : AurixTokens.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.subtitle,
                style: TextStyle(
                  fontFamily: AurixTokens.fontBody,
                  fontSize: 12,
                  color: AurixTokens.muted,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: AurixTokens.micro,
        ),
      ],
    );
  }

  Widget _compactLayout(Color c) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AurixTokens.radiusXs),
            color: c.withValues(alpha: 0.1),
          ),
          child: Icon(widget.icon, size: 18, color: c),
        ),
        const SizedBox(height: AurixTokens.s8),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AurixTokens.fontBody,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AurixTokens.text,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          widget.subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AurixTokens.fontBody,
            fontSize: 10,
            color: AurixTokens.micro,
          ),
        ),
      ],
    );
  }
}
