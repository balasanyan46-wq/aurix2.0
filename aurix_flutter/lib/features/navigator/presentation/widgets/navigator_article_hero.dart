import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/features/navigator/data/navigator_models.dart';

class NavigatorArticleHero extends StatelessWidget {
  const NavigatorArticleHero({
    super.key,
    required this.material,
    this.badges = const [],
    this.reason,
  });

  final NavigatorMaterial material;
  final List<String> badges;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Умный разбор',
            style: TextStyle(
              color: AurixTokens.orange,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(NavigatorClusters.label(material.category), AurixTokens.orange),
              _pill('${material.readingTimeMinutes} мин', AurixTokens.textSecondary),
              _pill(material.difficulty, AurixTokens.textSecondary),
              ...badges.take(2).map((b) => _pill(b, _badgeColor(b))),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            material.title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800, height: 1.15),
          ),
          const SizedBox(height: 10),
          Text(
            material.excerpt,
            style: const TextStyle(
              color: AurixTokens.textSecondary,
              height: 1.5,
              fontSize: 15,
            ),
          ),
          if (reason != null && reason!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AurixTokens.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AurixTokens.orange.withValues(alpha: 0.22)),
              ),
              child: Text(
                'Почему это тебе сейчас: $reason',
                style: const TextStyle(
                  color: AurixTokens.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
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

  Color _badgeColor(String badge) {
    switch (badge) {
      case 'Критично':
        return const Color(0xFFFF7A7A);
      case 'Следующий шаг':
        return const Color(0xFF7AA8FF);
      case 'Для релиза':
        return const Color(0xFFFFB05C);
      case 'Для твоего рынка':
      case 'Локально важно':
        return const Color(0xFF69A7FF);
      default:
        return AurixTokens.orange;
    }
  }
}
