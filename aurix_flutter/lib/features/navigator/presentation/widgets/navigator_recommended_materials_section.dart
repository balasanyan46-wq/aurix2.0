import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/features/navigator/data/navigator_models.dart';
import 'package:aurix_flutter/features/navigator/presentation/navigator_controller.dart';
import 'package:aurix_flutter/features/navigator/presentation/widgets/navigator_material_card.dart';

class NavigatorRecommendedMaterialsSection extends StatelessWidget {
  const NavigatorRecommendedMaterialsSection({
    super.key,
    required this.requiredCards,
    required this.additionalCards,
    required this.controller,
  });

  final List<NavigatorRecommendationCard> requiredCards;
  final List<NavigatorRecommendationCard> additionalCards;
  final NavigatorController controller;

  @override
  Widget build(BuildContext context) {
    if (requiredCards.isEmpty && additionalCards.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Материалы, отфильтрованные под тебя',
          style: TextStyle(
            color: AurixTokens.text,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Сначала главное: 3 обязательных и 2 дополнительных шага маршрута.',
          style: TextStyle(color: AurixTokens.textSecondary),
        ),
        const SizedBox(height: 12),
        if (requiredCards.isNotEmpty) ...[
          const _SubTitle('3 обязательных'),
          const SizedBox(height: 8),
          ...requiredCards.take(3).toList().asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: NavigatorMaterialCard(
                    card: entry.value,
                    revealDelay: Duration(milliseconds: 40 * entry.key),
                    statusLabel: controller.materialStatus(entry.value.material.id),
                    onOpen: () {
                      controller.markOpened(entry.value.material.id);
                      context.push('/navigator/article/${entry.value.material.slug}');
                    },
                    onSave: () => controller.toggleSaved(entry.value.material.id),
                    onComplete: () =>
                        controller.toggleCompleted(entry.value.material.id),
                  ),
                ),
              ),
          const SizedBox(height: 8),
        ],
        if (additionalCards.isNotEmpty) ...[
          const _SubTitle('2 дополнительных'),
          const SizedBox(height: 8),
          ...additionalCards.take(2).toList().asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: NavigatorMaterialCard(
                    card: entry.value,
                    revealDelay: Duration(milliseconds: 40 * entry.key),
                    statusLabel: controller.materialStatus(entry.value.material.id),
                    onOpen: () {
                      controller.markOpened(entry.value.material.id);
                      context.push('/navigator/article/${entry.value.material.slug}');
                    },
                    onSave: () => controller.toggleSaved(entry.value.material.id),
                    onComplete: () =>
                        controller.toggleCompleted(entry.value.material.id),
                  ),
                ),
              ),
        ],
      ],
    );
  }
}

class _SubTitle extends StatelessWidget {
  final String text;
  const _SubTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AurixTokens.text,
        fontWeight: FontWeight.w800,
        fontSize: 16,
      ),
    );
  }
}
