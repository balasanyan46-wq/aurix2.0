import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'home_shared.dart';

class ActionCardData {
  const ActionCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.accentColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? accentColor;
}

/// Single combined quick-actions block.
class QuickActionsBlock extends StatelessWidget {
  const QuickActionsBlock({
    super.key,
    required this.onCreateRelease,
    required this.onUploadTrack,
    required this.onGenerateCover,
    required this.onPromotion,
    required this.onStudio,
    required this.onTeam,
  });

  final VoidCallback onCreateRelease;
  final VoidCallback onUploadTrack;
  final VoidCallback onGenerateCover;
  final VoidCallback onPromotion;
  final VoidCallback onStudio;
  final VoidCallback onTeam;

  @override
  Widget build(BuildContext context) {
    final cards = [
      ActionCardData(
        title: 'Новый релиз',
        subtitle: 'Создать',
        icon: Icons.album_rounded,
        onTap: onCreateRelease,
        accentColor: AurixTokens.accent,
      ),
      ActionCardData(
        title: 'Обложка AI',
        subtitle: 'Сгенерировать',
        icon: Icons.auto_awesome_rounded,
        onTap: onGenerateCover,
        accentColor: AurixTokens.aiAccent,
      ),
      ActionCardData(
        title: 'Студия',
        subtitle: 'AI-ассистент',
        icon: Icons.headset_mic_rounded,
        onTap: onStudio,
        accentColor: AurixTokens.coolUndertone,
      ),
      ActionCardData(
        title: 'Промо',
        subtitle: 'Продвижение',
        icon: Icons.campaign_rounded,
        onTap: onPromotion,
        accentColor: AurixTokens.warning,
      ),
      ActionCardData(
        title: 'Загрузить',
        subtitle: 'Трек / стемы',
        icon: Icons.upload_file_rounded,
        onTap: onUploadTrack,
        accentColor: AurixTokens.positive,
      ),
      ActionCardData(
        title: 'Команда',
        subtitle: 'Продакшн',
        icon: Icons.groups_rounded,
        onTap: onTeam,
        accentColor: AurixTokens.muted,
      ),
    ];

    return HomeSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HomeSectionTitle('Быстрые действия', icon: Icons.bolt_rounded),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth > 600 ? 3 : 2;
              const spacing = 10.0;
              final itemWidth = (c.maxWidth - spacing * (cols - 1)) / cols;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: cards.map((card) => SizedBox(
                  width: itemWidth,
                  child: _CompactActionCard(data: card),
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CompactActionCard extends StatefulWidget {
  const _CompactActionCard({required this.data});
  final ActionCardData data;

  @override
  State<_CompactActionCard> createState() => _CompactActionCardState();
}

class _CompactActionCardState extends State<_CompactActionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.data.accentColor ?? AurixTokens.accent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.data.onTap,
        child: AnimatedContainer(
          duration: AurixTokens.dMedium,
          curve: AurixTokens.cEase,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _hovered
                ? AurixTokens.surface2.withValues(alpha: 0.8)
                : AurixTokens.surface1.withValues(alpha: 0.4),
            border: Border.all(
              color: _hovered ? color.withValues(alpha: 0.25) : AurixTokens.stroke(0.1),
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: AurixTokens.dMedium,
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: _hovered ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.data.icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.data.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AurixTokens.fontBody,
                        color: AurixTokens.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      widget.data.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AurixTokens.fontBody,
                        color: AurixTokens.micro,
                        fontSize: 11,
                      ),
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

// Keep ActionCard for backward compat if needed elsewhere
class ActionCard extends StatefulWidget {
  const ActionCard({super.key, required this.data, this.compact = false});
  final ActionCardData data;
  final bool compact;

  @override
  State<ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<ActionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.data.accentColor ?? AurixTokens.accent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.data.onTap,
        child: AnimatedContainer(
          duration: AurixTokens.dMedium,
          curve: AurixTokens.cEase,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
            color: _hovered ? AurixTokens.surface2.withValues(alpha: 0.8) : AurixTokens.surface1.withValues(alpha: 0.5),
            border: Border.all(color: _hovered ? color.withValues(alpha: 0.25) : AurixTokens.stroke(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: AurixTokens.dMedium,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: _hovered ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: _hovered ? 0.25 : 0.12)),
                ),
                child: Icon(widget.data.icon, size: 20, color: color),
              ),
              const SizedBox(height: 12),
              Text(widget.data.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: AurixTokens.fontBody, color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(widget.data.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: AurixTokens.fontBody, color: AurixTokens.micro, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
