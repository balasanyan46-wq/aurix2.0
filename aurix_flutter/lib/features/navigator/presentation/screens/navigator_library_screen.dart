import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:aurix_flutter/features/navigator/data/navigator_models.dart';
import 'package:aurix_flutter/features/navigator/presentation/navigator_controller.dart';
import 'package:aurix_flutter/features/navigator/presentation/widgets/navigator_library_filters.dart';
import 'package:aurix_flutter/features/navigator/presentation/widgets/navigator_material_card.dart';

class NavigatorLibraryScreen extends ConsumerStatefulWidget {
  const NavigatorLibraryScreen({super.key});

  @override
  ConsumerState<NavigatorLibraryScreen> createState() =>
      _NavigatorLibraryScreenState();
}

class _NavigatorLibraryScreenState extends ConsumerState<NavigatorLibraryScreen> {
  NavigatorLibrarySort _sortMode = NavigatorLibrarySort.important;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(navigatorControllerProvider);
    final ctrl = ref.read(navigatorControllerProvider.notifier);
    final pad = horizontalPadding(context);

    if (state.loading) {
      return PremiumPageContainer(
        padding: EdgeInsets.fromLTRB(pad, 18, pad, 28),
        child: const Column(
          children: [
            _SkeletonCard(),
            SizedBox(height: 10),
            _SkeletonCard(),
            SizedBox(height: 10),
            _SkeletonCard(),
          ],
        ),
      );
    }

    final categories = state.materials.map((e) => e.category).toSet().toList()..sort();
    final stages = state.materials.expand((e) => e.stages).toSet().toList()..sort();
    final goals = state.materials.expand((e) => e.goals).toSet().toList()..sort();
    final platforms = state.materials.expand((e) => e.platforms).toSet().toList()..sort();
    final materials = ctrl.visibleMaterials();

    materials.sort(_sort);

    return PremiumPageContainer(
      maxWidth: 1080,
      padding: EdgeInsets.fromLTRB(pad, 16, pad, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        const PremiumHeroBlock(
          title: 'Библиотека Навигатора',
          subtitle:
              'Каталог глубоких long-read материалов. Фильтруй по этапу, целям и платформам, чтобы учиться по персональному маршруту.',
          pills: [
            PremiumChip(label: 'Curated knowledge', icon: Icons.tune_rounded, selected: true),
            PremiumChip(label: 'Long-read', icon: Icons.article_rounded),
          ],
        ),
        const SizedBox(height: 10),
        NavigatorLibraryFilters(
          state: state,
          sort: _sortMode,
          onSortChanged: (v) => setState(() => _sortMode = v),
          onQueryChanged: ctrl.setQuery,
          onReset: ctrl.resetFilters,
          onToggleCategory: ctrl.toggleCategoryFilter,
          onToggleStage: ctrl.toggleStageFilter,
          onToggleGoal: ctrl.toggleGoalFilter,
          onTogglePlatform: ctrl.togglePlatformFilter,
          onToggleDuration: ctrl.toggleDurationFilter,
          onToggleType: ctrl.toggleTypeFilter,
          onToggleDifficulty: ctrl.toggleDifficultyFilter,
          onToggleStatus: ctrl.toggleStatusFilter,
          categories: categories,
          stages: stages,
          goals: goals,
          platforms: platforms,
        ),
        const SizedBox(height: 12),
        if (materials.isEmpty)
          Column(
            children: [
              const PremiumEmptyState(
                title: 'Материалы не найдены',
                description: 'Попробуй ослабить фильтры или обновить запрос.',
                icon: Icons.auto_awesome_outlined,
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: ctrl.resetFilters,
                child: const Text('Очистить фильтры'),
              ),
            ],
          )
        else
          ...materials.asMap().entries.map((entry) {
            final m = entry.value;
            final card = NavigatorRecommendationCard(
              material: m,
              whyNow: m.excerpt,
              score: m.priorityScore,
              recommendationBadge: 'Материал',
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: NavigatorMaterialCard(
                card: card,
                revealDelay: Duration(milliseconds: 35 * entry.key),
                statusLabel: ctrl.materialStatus(m.id),
                onOpen: () {
                  ctrl.markOpened(m.id);
                  context.push('/navigator/article/${m.slug}');
                },
                onSave: () => ctrl.toggleSaved(m.id),
                onComplete: () => ctrl.toggleCompleted(m.id),
              ),
            );
          }),
      ],
      ),
    );
  }

  int _sort(NavigatorMaterial a, NavigatorMaterial b) {
    switch (_sortMode) {
      case NavigatorLibrarySort.important:
        return b.priorityScore.compareTo(a.priorityScore);
      case NavigatorLibrarySort.quick:
        return a.readingTimeMinutes.compareTo(b.readingTimeMinutes);
      case NavigatorLibrarySort.deep:
        return b.readingTimeMinutes.compareTo(a.readingTimeMinutes);
      case NavigatorLibrarySort.newest:
        return b.updatedAt.compareTo(a.updatedAt);
    }
  }

}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            height: 10,
            decoration: BoxDecoration(
              color: AurixTokens.glass(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 220,
            height: 14,
            decoration: BoxDecoration(
              color: AurixTokens.glass(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 10,
            decoration: BoxDecoration(
              color: AurixTokens.glass(0.14),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}
