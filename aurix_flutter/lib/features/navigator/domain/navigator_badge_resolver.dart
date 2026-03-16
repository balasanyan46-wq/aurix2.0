import 'package:aurix_flutter/features/navigator/data/navigator_models.dart';

class NavigatorBadgeResult {
  final String primaryBadge;
  final List<String> mainBadges;
  final String? statusBadge;
  final String personalReason;
  final int importanceLevel;

  const NavigatorBadgeResult({
    required this.primaryBadge,
    required this.mainBadges,
    required this.statusBadge,
    required this.personalReason,
    required this.importanceLevel,
  });
}

class NavigatorBadgeResolver {
  const NavigatorBadgeResolver();

  NavigatorBadgeResult resolve({
    required NavigatorMaterial material,
    required NavigatorOnboardingAnswers answers,
    required Set<String> topRequiredIds,
    required String? nextStepMaterialId,
    required Set<String> savedIds,
    required Set<String> completedIds,
    required Set<String> openedIds,
    required NavigatorReleaseSignal? release,
    required double score,
  }) {
    final badges = <String>[];

    if (material.id == nextStepMaterialId) {
      badges.add('Следующий шаг');
    } else if (topRequiredIds.contains(material.id)) {
      badges.add('Рекомендуем сейчас');
    }

    if (_isLegal(material.category)) badges.add('Юр. база');
    if (_isRuCisLocal(material.category) && answers.marketRegion == 'ru_cis') {
      badges.add('Для твоего рынка');
    } else if (_isRuCisLocal(material.category)) {
      badges.add('Локально важно');
    }
    if (_isReleaseRelevant(material, answers, release)) badges.add('Для релиза');
    if (_isPlatformMustRead(material, answers.platforms)) {
      badges.add('Платформенный must-read');
    }
    if (answers.stage == 'только начинаю') badges.add('Для старта');
    if (material.tags.any((t) => t.toLowerCase().contains('система'))) {
      badges.add('Система артиста');
    }
    if (score >= 5.6 && !badges.contains('Следующий шаг')) badges.add('Критично');
    if (material.readingTimeMinutes <= 8) badges.add('Быстрая победа');

    final status = _statusBadge(material.id, savedIds, completedIds, openedIds);
    final filtered = <String>[];
    for (final b in badges) {
      if (!filtered.contains(b)) filtered.add(b);
    }
    final main = filtered.take(2).toList();
    final primary = main.isNotEmpty ? main.first : 'Рекомендуем сейчас';
    return NavigatorBadgeResult(
      primaryBadge: primary,
      mainBadges: main,
      statusBadge: status,
      personalReason: _reason(material, answers, release, status),
      importanceLevel: _importance(main, status),
    );
  }

  bool _isLegal(String category) {
    return category == NavigatorClusters.legalSafety ||
        category == NavigatorClusters.contractsRights ||
        category == NavigatorClusters.artistBrand;
  }

  bool _isRuCisLocal(String category) {
    return category == NavigatorClusters.yandexMusic ||
        category == NavigatorClusters.vkMusic ||
        _isLegal(category);
  }

  bool _isReleaseRelevant(
    NavigatorMaterial material,
    NavigatorOnboardingAnswers answers,
    NavigatorReleaseSignal? release,
  ) {
    final releaseSoon = (release?.daysToRelease ?? 999) <= 14;
    final goalRelease = answers.goal.toLowerCase().contains('релиз');
    final tags = material.tags.map((e) => e.toLowerCase()).toList();
    return releaseSoon ||
        goalRelease ||
        tags.any((t) =>
            t.contains('release') || t.contains('релиз') || t.contains('countdown'));
  }

  bool _isPlatformMustRead(NavigatorMaterial material, List<String> selected) {
    final mat = material.platforms.map((e) => e.toLowerCase()).toSet();
    final sel = selected.map((e) => e.toLowerCase()).toSet();
    return mat.intersection(sel).isNotEmpty;
  }

  String? _statusBadge(
    String materialId,
    Set<String> savedIds,
    Set<String> completedIds,
    Set<String> openedIds,
  ) {
    if (completedIds.contains(materialId)) return 'Пройдено';
    if (openedIds.contains(materialId)) return 'В процессе';
    if (savedIds.contains(materialId)) return 'Сохранено';
    return null;
  }

  String _reason(
    NavigatorMaterial material,
    NavigatorOnboardingAnswers answers,
    NavigatorReleaseSignal? release,
    String? status,
  ) {
    if ((release?.daysToRelease ?? 999) <= 14 &&
        _isReleaseRelevant(material, answers, release)) {
      return 'У тебя скоро релиз — этот материал поможет не слить старт.';
    }
    if (answers.platforms.any((p) => p.toLowerCase() == 'vk') &&
        material.category == NavigatorClusters.vkMusic) {
      return 'Ты выбрал VK как фокус — здесь рабочая база под рост.';
    }
    if (answers.platforms.any((p) => p.toLowerCase() == 'яндекс') &&
        material.category == NavigatorClusters.yandexMusic) {
      return 'Фокус на Яндексе — этот материал закрывает платформенные риски.';
    }
    if (_isLegal(material.category)) {
      return 'Это база, без которой легко ошибиться в правах и договорах.';
    }
    if (answers.blocker.toLowerCase().contains('систем')) {
      return 'У тебя проседает система — начни с этого шага.';
    }
    if (status == 'Пройдено') {
      return 'Материал уже пройден, можно использовать как референс.';
    }
    return 'Этот материал соответствует твоему этапу и текущей цели.';
  }

  int _importance(List<String> main, String? status) {
    if (main.contains('Критично') || main.contains('Следующий шаг')) return 3;
    if (main.contains('Рекомендуем сейчас') || main.contains('Для релиза')) return 2;
    if (status == 'Пройдено') return 1;
    return 2;
  }
}
