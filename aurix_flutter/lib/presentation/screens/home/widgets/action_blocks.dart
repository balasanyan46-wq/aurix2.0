import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'home_shared.dart';

class ActionCardData {
  const ActionCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
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
        title: 'Создать релиз',
        subtitle: 'Новый релиз и базовые данные',
        icon: Icons.album_rounded,
        onTap: onCreateRelease,
      ),
      ActionCardData(
        title: 'Загрузить трек',
        subtitle: 'Добавить материал в текущий релиз',
        icon: Icons.upload_file_rounded,
        onTap: onUploadTrack,
      ),
      ActionCardData(
        title: 'Сгенерировать обложку',
        subtitle: 'Быстро получить вариант обложки',
        icon: Icons.auto_awesome_rounded,
        onTap: onGenerateCover,
      ),
      ActionCardData(
        title: 'Запустить продвижение',
        subtitle: 'Перейти к промо и запуску',
        icon: Icons.rocket_launch_rounded,
        onTap: onPromotion,
      ),
    ];

    return HomeSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HomeSectionTitle('Быстрые действия'),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) {
              final isMobile = c.maxWidth < 760;
              final width = isMobile ? c.maxWidth : (c.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: cards
                    .map((card) => SizedBox(width: width, child: ActionCard(data: card)))
                    .toList(),
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
        title: 'Студия',
        subtitle: 'AI-инструменты для релиза',
        icon: Icons.auto_awesome_rounded,
        onTap: onStudio,
      ),
      ActionCardData(
        title: 'Продвижение',
        subtitle: 'Кампании и рекламные шаги',
        icon: Icons.rocket_launch_rounded,
        onTap: onPromotion,
      ),
      ActionCardData(
        title: 'Команда',
        subtitle: 'Исполнители и продакшн-задачи',
        icon: Icons.groups_rounded,
        onTap: onTeam,
      ),
      ActionCardData(
        title: 'Юридические документы',
        subtitle: 'Договоры и правовые шаблоны',
        icon: Icons.gavel_rounded,
        onTap: onLegal,
      ),
    ];

    return HomeSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HomeSectionTitle('Инструменты'),
          const SizedBox(height: 10),
          if (isMobile)
            ...cards
                .map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ActionCard(data: c, compact: true),
                    ))
          else
            Row(
              children: [
                Expanded(flex: 2, child: ActionCard(data: cards[0])),
                const SizedBox(width: 10),
                Expanded(child: ActionCard(data: cards[1], compact: true)),
                const SizedBox(width: 10),
                Expanded(child: ActionCard(data: cards[2], compact: true)),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: ActionCard(data: cards[3])),
              ],
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
    final h = widget.compact ? 106.0 : 126.0;
    final borderColor = _hovered ? AurixTokens.stroke(0.34) : AurixTokens.stroke(0.22);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        constraints: BoxConstraints(minHeight: h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AurixTokens.bg1.withValues(alpha: 0.94),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hovered ? 0.26 : 0.2),
              blurRadius: _hovered ? 18 : 10,
              spreadRadius: -10,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(top: _hovered ? 0 : 2, bottom: _hovered ? 2 : 0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.data.onTap,
              borderRadius: BorderRadius.circular(16),
              child: LayoutBuilder(
                builder: (context, c) {
                  final isNarrow = c.maxWidth < 190;
                  final isUltraNarrow = c.maxWidth < 120;
                  final hPad = isUltraNarrow ? 8.0 : 14.0;
                  final vPad = isUltraNarrow ? 10.0 : 12.0;
                  final iconSize = isUltraNarrow ? 28.0 : 34.0;
                  final iconInner = isUltraNarrow ? 15.0 : 18.0;
                  late final Widget content;
                  if (isUltraNarrow) {
                    content = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: iconSize,
                          height: iconSize,
                          decoration: BoxDecoration(
                            color: AurixTokens.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(widget.data.icon, size: iconInner, color: AurixTokens.orange),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.data.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AurixTokens.text,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                      ],
                    );
                  } else {
                    content = Row(
                      children: [
                        Container(
                          width: iconSize,
                          height: iconSize,
                          decoration: BoxDecoration(
                            color: AurixTokens.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(widget.data.icon, size: iconInner, color: AurixTokens.orange),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.data.title,
                                maxLines: isNarrow ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AurixTokens.text,
                                  fontSize: isNarrow ? 14.5 : 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.data.subtitle,
                                maxLines: isNarrow ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AurixTokens.textSecondary.withValues(alpha: 0.95),
                                  fontSize: isNarrow ? 12 : 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isNarrow)
                          const Icon(Icons.chevron_right_rounded, color: AurixTokens.muted),
                      ],
                    );
                  }
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
                    child: content,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
