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

class QuickActionsBlock extends StatelessWidget {
  const QuickActionsBlock({
    super.key,
    required this.onCreateRelease,
    required this.onUploadTrack,
    required this.onGenerateCover,
    required this.onPromotion,
  });

  final VoidCallback onCreateRelease;
  final VoidCallback onUploadTrack;
  final VoidCallback onGenerateCover;
  final VoidCallback onPromotion;

  @override
  Widget build(BuildContext context) {
    final cards = [
      ActionCardData(
        title: '\u0421\u043e\u0437\u0434\u0430\u0442\u044c \u0440\u0435\u043b\u0438\u0437',
        subtitle: '\u041d\u043e\u0432\u044b\u0439 \u0440\u0435\u043b\u0438\u0437',
        icon: Icons.album_rounded,
        onTap: onCreateRelease,
        accentColor: AurixTokens.accent,
      ),
      ActionCardData(
        title: '\u0417\u0430\u0433\u0440\u0443\u0437\u0438\u0442\u044c \u0442\u0440\u0435\u043a',
        subtitle: '\u0414\u043e\u0431\u0430\u0432\u0438\u0442\u044c \u043c\u0430\u0442\u0435\u0440\u0438\u0430\u043b',
        icon: Icons.upload_file_rounded,
        onTap: onUploadTrack,
        accentColor: AurixTokens.positive,
      ),
      ActionCardData(
        title: '\u041e\u0431\u043b\u043e\u0436\u043a\u0430 AI',
        subtitle: '\u0421\u0433\u0435\u043d\u0435\u0440\u0438\u0440\u043e\u0432\u0430\u0442\u044c',
        icon: Icons.auto_awesome_rounded,
        onTap: onGenerateCover,
        accentColor: AurixTokens.aiAccent,
      ),
      ActionCardData(
        title: '\u041f\u0440\u043e\u0434\u0432\u0438\u0436\u0435\u043d\u0438\u0435',
        subtitle: '\u0417\u0430\u043f\u0443\u0441\u0442\u0438\u0442\u044c \u043f\u0440\u043e\u043c\u043e',
        icon: Icons.campaign_rounded,
        onTap: onPromotion,
        accentColor: AurixTokens.warning,
      ),
    ];

    return HomeSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HomeSectionTitle('\u0411\u044b\u0441\u0442\u0440\u044b\u0435 \u0434\u0435\u0439\u0441\u0442\u0432\u0438\u044f', icon: Icons.bolt_rounded),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final isMobile = c.maxWidth < 600;
              if (isMobile) {
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: cards
                      .map((card) => SizedBox(
                            width: (c.maxWidth - 10) / 2,
                            child: ActionCard(data: card),
                          ))
                      .toList(),
                );
              }
              return Row(
                children: cards
                    .map((card) => Expanded(child: ActionCard(data: card)))
                    .expand((w) => [w, const SizedBox(width: 10)])
                    .toList()
                  ..removeLast(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ToolsBlock extends StatelessWidget {
  const ToolsBlock({
    super.key,
    required this.onStudio,
    required this.onPromotion,
    required this.onTeam,
    required this.onLegal,
  });

  final VoidCallback onStudio;
  final VoidCallback onPromotion;
  final VoidCallback onTeam;
  final VoidCallback onLegal;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 900;
    final cards = [
      ActionCardData(
        title: '\u0421\u0442\u0443\u0434\u0438\u044f',
        subtitle: 'AI-\u0438\u043d\u0441\u0442\u0440\u0443\u043c\u0435\u043d\u0442\u044b',
        icon: Icons.auto_awesome_rounded,
        onTap: onStudio,
        accentColor: AurixTokens.aiAccent,
      ),
      ActionCardData(
        title: '\u041f\u0440\u043e\u0434\u0432\u0438\u0436\u0435\u043d\u0438\u0435',
        subtitle: '\u041a\u0430\u043c\u043f\u0430\u043d\u0438\u0438',
        icon: Icons.campaign_rounded,
        onTap: onPromotion,
        accentColor: AurixTokens.accent,
      ),
      ActionCardData(
        title: '\u041a\u043e\u043c\u0430\u043d\u0434\u0430',
        subtitle: '\u041f\u0440\u043e\u0434\u0430\u043a\u0448\u043d',
        icon: Icons.groups_rounded,
        onTap: onTeam,
        accentColor: AurixTokens.positive,
      ),
      ActionCardData(
        title: '\u042e\u0440\u0438\u0434\u0438\u0447\u0435\u0441\u043a\u0438\u0435',
        subtitle: '\u0414\u043e\u0433\u043e\u0432\u043e\u0440\u044b',
        icon: Icons.gavel_rounded,
        onTap: onLegal,
        accentColor: AurixTokens.warning,
      ),
    ];

    return HomeSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HomeSectionTitle('\u0418\u043d\u0441\u0442\u0440\u0443\u043c\u0435\u043d\u0442\u044b', icon: Icons.build_rounded),
          const SizedBox(height: 14),
          if (isMobile)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: cards
                  .map((c) => SizedBox(
                        width: (MediaQuery.sizeOf(context).width - 72) / 2,
                        child: ActionCard(data: c),
                      ))
                  .toList(),
            )
          else
            Row(
              children: cards
                  .map((card) => Expanded(child: ActionCard(data: card)))
                  .expand((w) => [w, const SizedBox(width: 10)])
                  .toList()
                ..removeLast(),
            ),
        ],
      ),
    );
  }
}

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
            color: _hovered
                ? AurixTokens.surface2.withValues(alpha: 0.8)
                : AurixTokens.surface1.withValues(alpha: 0.5),
            border: Border.all(
              color: _hovered ? color.withValues(alpha: 0.25) : AurixTokens.stroke(0.12),
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.08),
                      blurRadius: 20,
                      spreadRadius: -8,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
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
                  border: Border.all(
                    color: color.withValues(alpha: _hovered ? 0.25 : 0.12),
                  ),
                ),
                child: Icon(widget.data.icon, size: 20, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                widget.data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AurixTokens.fontBody,
                  color: AurixTokens.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.data.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AurixTokens.fontBody,
                  color: AurixTokens.micro,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
