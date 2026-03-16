import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/features/navigator/data/navigator_models.dart';

class NavigatorQuickActionCard extends StatelessWidget {
  const NavigatorQuickActionCard({
    super.key,
    required this.quickAction,
    required this.whyNow,
    required this.estimatedMinutes,
  });

  final NavigatorQuickAction quickAction;
  final String whyNow;
  final int estimatedMinutes;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return AurixGlassCard(
      radius: 18,
      padding: EdgeInsets.all(isDesktop ? 16 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Следующий лучший шаг',
            style: TextStyle(
              color: AurixTokens.orange,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            quickAction.title,
            style: TextStyle(
              color: AurixTokens.text,
              fontWeight: FontWeight.w800,
              fontSize: isDesktop ? 19 : 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            quickAction.description,
            style: const TextStyle(color: AurixTokens.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 6),
          Text(
            'Почему сейчас: $whyNow',
            style: const TextStyle(color: AurixTokens.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            'Оценка по времени: ~${estimatedMinutes.clamp(5, 45)} минут',
            style: const TextStyle(
              color: AurixTokens.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => context.go(quickAction.actionLink.route),
            icon: const Icon(Icons.play_arrow_rounded, size: 16),
            label: Text(quickAction.actionLink.label),
          ),
          const SizedBox(height: 8),
          const Text(
            'После выполнения: ты закрываешь узкое место и продвигаешь маршрут к следующему этапу.',
            style: TextStyle(color: AurixTokens.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
