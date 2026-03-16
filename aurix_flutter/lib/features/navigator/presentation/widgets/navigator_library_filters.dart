import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/features/navigator/data/navigator_models.dart';
import 'package:aurix_flutter/features/navigator/presentation/navigator_controller.dart'
    as nav;

enum NavigatorLibrarySort {
  important,
  quick,
  deep,
  newest,
}

class NavigatorLibraryFilters extends StatelessWidget {
  const NavigatorLibraryFilters({
    super.key,
    required this.state,
    required this.sort,
    required this.onSortChanged,
    required this.onQueryChanged,
    required this.onReset,
    required this.onToggleCategory,
    required this.onToggleStage,
    required this.onToggleGoal,
    required this.onTogglePlatform,
    required this.onToggleDuration,
    required this.onToggleType,
    required this.onToggleDifficulty,
    required this.onToggleStatus,
    required this.categories,
    required this.stages,
    required this.goals,
    required this.platforms,
  });

  final nav.NavigatorState state;
  final NavigatorLibrarySort sort;
  final ValueChanged<NavigatorLibrarySort> onSortChanged;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onReset;
  final ValueChanged<String> onToggleCategory;
  final ValueChanged<String> onToggleStage;
  final ValueChanged<String> onToggleGoal;
  final ValueChanged<String> onTogglePlatform;
  final ValueChanged<String> onToggleDuration;
  final ValueChanged<String> onToggleType;
  final ValueChanged<String> onToggleDifficulty;
  final ValueChanged<String> onToggleStatus;
  final List<String> categories;
  final List<String> stages;
  final List<String> goals;
  final List<String> platforms;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: onQueryChanged,
          decoration: const InputDecoration(
            hintText: 'Поиск по материалам и тегам',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _choice('Сначала важное', sort == NavigatorLibrarySort.important,
                () => onSortChanged(NavigatorLibrarySort.important)),
            _choice('Сначала быстрое', sort == NavigatorLibrarySort.quick,
                () => onSortChanged(NavigatorLibrarySort.quick)),
            _choice('Сначала глубокие', sort == NavigatorLibrarySort.deep,
                () => onSortChanged(NavigatorLibrarySort.deep)),
            _choice('Сначала новое', sort == NavigatorLibrarySort.newest,
                () => onSortChanged(NavigatorLibrarySort.newest)),
            TextButton(onPressed: onReset, child: const Text('Сброс фильтров')),
          ],
        ),
        const SizedBox(height: 10),
        _filterWrap(
          'Локальные кластеры',
          const [
            'Яндекс Музыка',
            'VK Музыка',
            'Право и безопасность',
            'Договоры и права',
            'Бренд артиста',
          ],
          {
            if (state.categoryFilter.contains(NavigatorClusters.yandexMusic))
              'Яндекс Музыка',
            if (state.categoryFilter.contains(NavigatorClusters.vkMusic))
              'VK Музыка',
            if (state.categoryFilter.contains(NavigatorClusters.legalSafety))
              'Право и безопасность',
            if (state.categoryFilter.contains(NavigatorClusters.contractsRights))
              'Договоры и права',
            if (state.categoryFilter.contains(NavigatorClusters.artistBrand))
              'Бренд артиста',
          },
          (label) => onToggleCategory(_clusterByLabel(label)),
        ),
        _filterWrap('Категории', categories, state.categoryFilter, onToggleCategory),
        _filterWrap('Этап', stages, state.stageFilter, onToggleStage),
        _filterWrap('Цель', goals, state.goalFilter, onToggleGoal),
        _filterWrap('Платформа', platforms, state.platformFilter, onTogglePlatform),
        _filterWrap('Длительность', const ['до 10 минут', '10-30 минут', '30+ минут'],
            state.durationFilter, onToggleDuration),
        _filterWrap('Тип', const ['статья', 'кейс', 'разбор', 'видео', 'шаблон'],
            state.typeFilter, onToggleType),
        _filterWrap('Сложность', const ['базовый', 'средний', 'продвинутый'],
            state.difficultyFilter, onToggleDifficulty),
        _filterWrap('Статус', const ['новое', 'не открывал', 'в процессе', 'завершено', 'сохранено'],
            state.statusFilter, onToggleStatus),
      ],
    );
  }

  String _clusterByLabel(String label) {
    switch (label) {
      case 'Яндекс Музыка':
        return NavigatorClusters.yandexMusic;
      case 'VK Музыка':
        return NavigatorClusters.vkMusic;
      case 'Право и безопасность':
        return NavigatorClusters.legalSafety;
      case 'Договоры и права':
        return NavigatorClusters.contractsRights;
      case 'Бренд артиста':
        return NavigatorClusters.artistBrand;
      default:
        return label;
    }
  }

  Widget _choice(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AurixTokens.orange.withValues(alpha: 0.18),
      backgroundColor: AurixTokens.glass(0.06),
      side: BorderSide(color: AurixTokens.stroke(0.24)),
      labelStyle: TextStyle(
        color: selected ? AurixTokens.orange : AurixTokens.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _filterWrap(
    String title,
    List<String> items,
    Set<String> selected,
    ValueChanged<String> onToggle,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in items)
                FilterChip(
                  label: Text(NavigatorClusters.label(item)),
                  selected: selected.contains(item),
                  onSelected: (_) => onToggle(item),
                  selectedColor: AurixTokens.orange.withValues(alpha: 0.18),
                  backgroundColor: AurixTokens.glass(0.06),
                  side: BorderSide(color: AurixTokens.stroke(0.24)),
                  labelStyle: TextStyle(
                    color: selected.contains(item)
                        ? AurixTokens.orange
                        : AurixTokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
