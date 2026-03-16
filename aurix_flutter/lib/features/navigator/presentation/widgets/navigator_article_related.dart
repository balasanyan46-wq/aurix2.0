import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/features/navigator/data/navigator_models.dart';

class NavigatorArticleRelated extends StatelessWidget {
  const NavigatorArticleRelated({
    super.key,
    required this.items,
    required this.onOpen,
  });

  final List<NavigatorMaterial> items;
  final ValueChanged<NavigatorMaterial> onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Продолжить маршрут',
          style: TextStyle(
            color: AurixTokens.text,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 8),
        ...items.take(3).map(
          (m) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AurixGlassCard(
              radius: 14,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _pill(NavigatorClusters.label(m.category), AurixTokens.orange),
                      _pill('${m.readingTimeMinutes} мин', AurixTokens.textSecondary),
                      _pill(_relatedBadge(m), const Color(0xFF7AA8FF)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    m.title,
                    style: const TextStyle(
                      color: AurixTokens.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    m.excerpt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AurixTokens.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _reasonAfterRead(m),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AurixTokens.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => onOpen(m),
                    child: const Text('Открыть'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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

  String _relatedBadge(NavigatorMaterial m) {
    if (m.category == NavigatorClusters.legalSafety ||
        m.category == NavigatorClusters.contractsRights ||
        m.category == NavigatorClusters.artistBrand) {
      return 'Юр. база';
    }
    if (m.category == NavigatorClusters.yandexMusic ||
        m.category == NavigatorClusters.vkMusic) {
      return 'Для твоего рынка';
    }
    return 'Следующий шаг';
  }

  String _reasonAfterRead(NavigatorMaterial m) {
    if (m.category == NavigatorClusters.yandexMusic ||
        m.category == NavigatorClusters.vkMusic) {
      return 'Логичное продолжение: усилить платформенную стратегию после текущего разбора.';
    }
    if (m.category == NavigatorClusters.legalSafety ||
        m.category == NavigatorClusters.contractsRights ||
        m.category == NavigatorClusters.artistBrand) {
      return 'После этого материала важно закрыть правовые риски и укрепить базу.';
    }
    return 'Этот материал продолжает текущую логику маршрута без лишнего шума.';
  }
}
