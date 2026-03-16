import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/features/navigator/data/navigator_models.dart';

class NavigatorArticleNextStep extends StatelessWidget {
  const NavigatorArticleNextStep({
    super.key,
    required this.nextStepText,
    required this.actions,
  });

  final String nextStepText;
  final List<NavigatorActionLink> actions;

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      radius: 18,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Следующее действие в AURIX',
            style: TextStyle(
              color: AurixTokens.orange,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            nextStepText,
            style: const TextStyle(color: AurixTokens.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AurixTokens.glass(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AurixTokens.stroke(0.18)),
            ),
            child: const Text(
              'Что это даст: ты закрепишь материал в практике и сдвинешь маршрут на следующий этап.',
              style: TextStyle(
                color: AurixTokens.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: actions.take(3).map(
              (a) {
                final isMain = a.actionType.contains('open_release') ||
                    a.actionType.contains('open_promo') ||
                    a.actionType.contains('open_dnk') ||
                    a.actionType.contains('open_studio');
                final btn = isMain
                    ? FilledButton(
                        onPressed: () => context.go(a.route),
                        child: Text(a.label),
                      )
                    : OutlinedButton(
                        onPressed: () => context.go(a.route),
                        child: Text(a.label),
                      );
                return btn;
              },
            ).toList(),
          ),
        ],
      ),
    );
  }
}
