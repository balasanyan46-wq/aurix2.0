import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/features/navigator/data/navigator_models.dart';
import 'package:aurix_flutter/features/navigator/presentation/widgets/navigator_reveal.dart';

class NavigatorMaterialCard extends StatefulWidget {
  const NavigatorMaterialCard({
    super.key,
    required this.card,
    required this.statusLabel,
    required this.onOpen,
    required this.onSave,
    required this.onComplete,
    this.revealDelay = Duration.zero,
  });

  final NavigatorRecommendationCard card;
  final String statusLabel;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onComplete;
  final Duration revealDelay;

  @override
  State<NavigatorMaterialCard> createState() => _NavigatorMaterialCardState();
}

class _NavigatorMaterialCardState extends State<NavigatorMaterialCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final m = widget.card.material;
    final statusColor = switch (widget.statusLabel) {
      'Прочитано' => AurixTokens.positive,
      'В процессе' => AurixTokens.accentWarm,
      'Сохранено' => AurixTokens.textSecondary,
      _ => AurixTokens.muted,
    };
    return NavigatorReveal(
      delay: widget.revealDelay,
      child: MouseRegion(
        onEnter: (_) {
          if (!isDesktop) return;
          setState(() => _hovered = true);
        },
        onExit: (_) {
          if (!isDesktop) return;
          setState(() {
            _hovered = false;
            _pressed = false;
          });
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (_) {
            if (!isDesktop) return;
            setState(() => _pressed = true);
          },
          onTapUp: (_) {
            if (!isDesktop) return;
            setState(() => _pressed = false);
          },
          onTapCancel: () {
            if (!isDesktop) return;
            setState(() => _pressed = false);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            transform: Matrix4.identity()
              ..translateByDouble(0.0, _hovered ? -2.0 : 0.0, 0.0, 1.0)
              ..scaleByDouble(_pressed ? 0.996 : 1.0, _pressed ? 0.996 : 1.0, 1.0, 1.0),
            child: AurixGlassCard(
            radius: 16,
            padding: EdgeInsets.all(
              isDesktop ? 16 : 13,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _pill(NavigatorClusters.label(m.category), AurixTokens.orange),
                    _pill(m.durationBucket, AurixTokens.textSecondary),
                    _pill(m.difficulty, AurixTokens.textSecondary),
                    _pill(widget.statusLabel, statusColor),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  m.title,
                  style: const TextStyle(
                    color: AurixTokens.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  m.excerpt,
                  style: const TextStyle(
                    color: AurixTokens.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  m.stages.isEmpty
                      ? 'Для кого: артистам, которые хотят системный рост'
                      : 'Для кого: ${m.stages.take(2).join(' / ')}',
                  style: const TextStyle(
                    color: AurixTokens.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: widget.onOpen,
                      icon: const Icon(Icons.menu_book_rounded, size: 16),
                      label: const Text('Открыть'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.onSave,
                      icon: const Icon(Icons.bookmark_border_rounded, size: 16),
                      label: const Text('Сохранить'),
                    ),
                    OutlinedButton(
                      onPressed: widget.onComplete,
                      child: const Text('Прочитано'),
                    ),
                  ],
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
