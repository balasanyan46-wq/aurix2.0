import '../data/navigator_models.dart';
import 'navigator_badge_resolver.dart';

class NavigatorRecommendationService {
  final NavigatorBadgeResolver _badgeResolver;

  NavigatorRecommendationService({NavigatorBadgeResolver? badgeResolver})
      : _badgeResolver = badgeResolver ?? const NavigatorBadgeResolver();

  NavigatorRecommendationResult recommend({
    required List<NavigatorMaterial> materials,
    required NavigatorOnboardingAnswers answers,
    NavigatorDnkSignal? dnk,
    NavigatorProgressSignal? progress,
    NavigatorReleaseSignal? release,
    Set<String> savedIds = const {},
    Set<String> completedIds = const {},
    Set<String> openedIds = const {},
  }) {
    final scored = <NavigatorRecommendationCard>[];
    for (final item in materials.where((m) => m.isPublished)) {
      final stageFit = _binaryFit(item.stages, answers.stage);
      final goalFit = _binaryFit(item.goals, answers.goal);
      final blockerFit = _binaryFit(item.blockers, answers.blocker);
      final platformFit = _platformFit(item.platforms, answers.platforms);
      final releaseUrgencyFit = _releaseUrgencyFit(item, answers, release);
      final progressFit = _progressFit(item, answers, progress);
      final dnkFit = _dnkFit(item, dnk);
      final freshness = _freshness(item.updatedAt);
      final depthFit = _depthFit(item, answers.depth);
      final historyFit = _historyFit(item.id, savedIds, completedIds, openedIds);
      final marketRegionFit = _marketRegionFit(item, answers);
      final goalIntentFit = _goalIntentFit(item, answers.goal);
      final platformPriorityFit = _platformPriorityFit(item, answers.platforms);
      final starterFit = _starterPriorityFit(item, answers);

      final score = stageFit * 1.6 +
          goalFit * 2.0 +
          blockerFit * 2.1 +
          releaseUrgencyFit * 2.2 +
          platformFit * 1.2 +
          platformPriorityFit * 1.4 +
          depthFit * 0.9 +
          historyFit * 0.8 +
          marketRegionFit * 1.5 +
          goalIntentFit * 1.2 +
          starterFit * 1.1 +
          progressFit * 1.6 +
          dnkFit * 1.1 +
          item.priorityScore * 0.9 +
          freshness * 0.7;
      scored.add(
        NavigatorRecommendationCard(
          material: item,
          score: score,
          recommendationBadge: _badgeFor(item, score, blockerFit, releaseUrgencyFit),
          whyNow: _buildWhyNow(
            item: item,
            answers: answers,
            release: release,
            progress: progress,
            completedIds: completedIds,
          ),
        ),
      );
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    if (scored.isEmpty) {
      const fallbackAction = NavigatorActionLink(
        actionType: 'open_studio_ai',
        label: 'Открыть Studio AI',
        route: '/ai',
      );
      final fallbackMaterial = NavigatorMaterial(
        id: 'fallback',
        slug: 'fallback',
        title: 'База маршрута скоро появится',
        subtitle: '',
        excerpt: 'Пока материалов нет, но система маршрутизации уже готова.',
        bodyBlocks: [],
        category: 'Старт и позиционирование',
        tags: [],
        platforms: [],
        stages: [],
        goals: [],
        blockers: [],
        difficulty: 'базовый',
        readingTimeMinutes: 5,
        formatType: 'статья',
        actionLinks: [fallbackAction],
        sourcePack: [],
        lastReviewedAt: null,
        isFeatured: false,
        isPublished: true,
        priorityScore: 0,
        relatedContentIds: [],
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      final fallbackCard = NavigatorRecommendationCard(
        material: fallbackMaterial,
        whyNow: 'Сначала наполним библиотеку, затем персонализируем маршрут.',
        score: 0,
        recommendationBadge: 'Рекомендуем сейчас',
      );
      return NavigatorRecommendationResult(
        nextBestStep: fallbackCard,
        recommendedMaterials: <NavigatorRecommendationCard>[fallbackCard],
        criticalMaterials: [],
        quickWins: <NavigatorRecommendationCard>[fallbackCard],
        routeSteps: <NavigatorRouteStep>[
          const NavigatorRouteStep(
            index: 1,
            title: 'Открыть Studio AI',
            description: 'Сформируй первый рабочий план действий.',
            status: NavigatorRouteStepStatus.inProgress,
            etaMinutes: 10,
            action: fallbackAction,
            whyRecommended: 'Это самый быстрый способ начать движение.',
          ),
        ],
        topRequired: <NavigatorRecommendationCard>[fallbackCard],
        topAdditional: [],
        quickAction: const NavigatorQuickAction(
          title: 'Сделай первый шаг',
          description: 'Открой Studio AI и зафиксируй план на неделю.',
          actionLink: fallbackAction,
        ),
        explanation: 'Рекомендации пока ограничены отсутствием материалов.',
        estimatedMinutes: 10,
      );
    }
    final baseRequired = scored.take(3).toList();
    final topRequiredIds = baseRequired.map((e) => e.material.id).toSet();
    final nextStepId = baseRequired.isEmpty ? scored.first.material.id : baseRequired.first.material.id;
    final decorated = scored
        .map(
          (card) {
            final resolved = _badgeResolver.resolve(
              material: card.material,
              answers: answers,
              topRequiredIds: topRequiredIds,
              nextStepMaterialId: nextStepId,
              savedIds: savedIds,
              completedIds: completedIds,
              openedIds: openedIds,
              release: release,
              score: card.score,
            );
            return NavigatorRecommendationCard(
              material: card.material,
              whyNow: card.whyNow,
              score: card.score,
              recommendationBadge: resolved.primaryBadge,
              suggestedBadges: resolved.mainBadges,
              statusBadge: resolved.statusBadge,
              personalReason: resolved.personalReason,
              importanceLevel: resolved.importanceLevel,
            );
          },
        )
        .toList();
    final recommended = decorated.take(8).toList();
    final required = decorated.take(3).toList();
    final additional = decorated.skip(3).take(2).toList();
    final critical = decorated
        .where((s) => s.recommendationBadge == 'Критично')
        .take(3)
        .toList();
    final quickWins = decorated
        .where((s) => s.material.readingTimeMinutes <= 10)
        .take(3)
        .toList();
    final quickAction = _quickAction(required, answers, release, progress);
    final routeSteps = _buildRoute(required, additional, answers, completedIds);
    final nextBest = required.isEmpty ? decorated.first : required.first;
    final estimatedMinutes =
        routeSteps.fold<int>(0, (acc, e) => acc + e.etaMinutes);

    return NavigatorRecommendationResult(
      nextBestStep: nextBest,
      recommendedMaterials: recommended,
      criticalMaterials: critical,
      quickWins: quickWins,
      routeSteps: routeSteps,
      topRequired: required,
      topAdditional: additional,
      quickAction: quickAction,
      explanation: _buildExplanation(answers, release, progress),
      estimatedMinutes: estimatedMinutes,
    );
  }
  double _depthFit(NavigatorMaterial item, String depth) {
    if (depth.isEmpty) return 0.4;
    if (depth == 'баланс' && item.difficulty == 'средний') return 1;
    if (depth == item.difficulty) return 1;
    if (depth == 'быстро и по делу' && item.readingTimeMinutes <= 10) return 0.85;
    if (depth == 'глубоко и подробно' && item.readingTimeMinutes >= 15) return 0.8;
    return 0.35;
  }

  double _historyFit(
    String materialId,
    Set<String> savedIds,
    Set<String> completedIds,
    Set<String> openedIds,
  ) {
    if (completedIds.contains(materialId)) return -0.4;
    if (openedIds.contains(materialId)) return 0.2;
    if (savedIds.contains(materialId)) return 0.3;
    return 0;
  }

  double _marketRegionFit(
    NavigatorMaterial item,
    NavigatorOnboardingAnswers answers,
  ) {
    if (answers.marketRegion != 'ru_cis') return 0.2;
    if (NavigatorClusters.ruCisPriority.contains(item.category)) return 1;
    return 0.15;
  }

  double _goalIntentFit(NavigatorMaterial item, String goal) {
    final g = goal.toLowerCase();
    final category = item.category;
    if (g.contains('релиз')) {
      if (category == NavigatorClusters.yandexMusic ||
          category == NavigatorClusters.vkMusic ||
          item.tags.any((e) => e.toLowerCase().contains('release'))) {
        return 1;
      }
      return 0.3;
    }
    if (g.contains('прав')) {
      if (category == NavigatorClusters.legalSafety ||
          category == NavigatorClusters.contractsRights ||
          category == NavigatorClusters.artistBrand) {
        return 1;
      }
      return 0.2;
    }
    return 0.35;
  }

  double _platformPriorityFit(NavigatorMaterial item, List<String> selectedPlatforms) {
    final p = selectedPlatforms.map((e) => e.toLowerCase()).toSet();
    if (p.contains('яндекс') && item.category == NavigatorClusters.yandexMusic) return 1;
    if (p.contains('vk') && item.category == NavigatorClusters.vkMusic) return 1;
    return 0.2;
  }

  double _starterPriorityFit(
    NavigatorMaterial item,
    NavigatorOnboardingAnswers answers,
  ) {
    if (answers.stage != 'только начинаю') return 0.15;
    final isStarterLegal = item.category == NavigatorClusters.legalSafety ||
        item.category == NavigatorClusters.contractsRights;
    final isStarterCard = item.tags.any(
      (e) =>
          e.toLowerCase().contains('карточк') ||
          e.toLowerCase().contains('профиль') ||
          e.toLowerCase().contains('оформление'),
    );
    final isPlatformBase = item.category == NavigatorClusters.yandexMusic ||
        item.category == NavigatorClusters.vkMusic;
    if (isStarterLegal || isStarterCard || isPlatformBase) return 1;
    return 0.25;
  }


  String _badgeFor(
    NavigatorMaterial item,
    double score,
    double blockerFit,
    double releaseUrgencyFit,
  ) {
    if (releaseUrgencyFit >= 0.95 || blockerFit >= 0.95) return 'Критично';
    if (item.readingTimeMinutes <= 10) return 'Быстрая победа';
    if (score >= 4.3) return 'Следующий шаг';
    return 'Рекомендуем сейчас';
  }

  double _binaryFit(List<String> values, String selected) {
    if (selected.isEmpty) return 0;
    final s = selected.toLowerCase();
    for (final value in values) {
      final v = value.toLowerCase();
      if (v == s) return 1;
      if (v.contains(s) || s.contains(v)) return 0.82;
      if ((v.contains('позиц') && s.contains('позиц')) ||
          (v.contains('дисцип') && s.contains('дисцип')) ||
          (v.contains('систем') && s.contains('систем')) ||
          (v.contains('контент') && s.contains('контент')) ||
          (v.contains('продвиж') && s.contains('продвиж')) ||
          (v.contains('прав') && s.contains('прав')) ||
          (v.contains('бренд') && s.contains('бренд')) ||
          (v.contains('платформ') && s.contains('платформ')) ||
          (v.contains('деньг') && s.contains('деньг')) ||
          (v.contains('аналит') && s.contains('аналит')) ||
          (v.contains('понима') && s.contains('понима'))) {
        return 0.74;
      }
    }
    return 0;
  }

  double _platformFit(List<String> materialPlatforms, List<String> selected) {
    if (selected.isEmpty || selected.contains('пока не понимаю')) return 0.2;
    final mat = materialPlatforms.map((e) => e.toLowerCase()).toSet();
    final sel = selected.map((e) => e.toLowerCase()).toSet();
    final overlap = mat.intersection(sel).length;
    if (overlap == 0) return 0;
    return (overlap / sel.length).clamp(0, 1).toDouble();
  }

  double _releaseUrgencyFit(
    NavigatorMaterial material,
    NavigatorOnboardingAnswers answers,
    NavigatorReleaseSignal? release,
  ) {
    final tags = material.tags.map((e) => e.toLowerCase()).toSet();
    final releaseStage = answers.releaseStage.toLowerCase();
    final days = release?.daysToRelease;

    final isPreReleaseTag =
        tags.contains('pre-release') || tags.contains('pitching') || tags.contains('countdown');
    final isPostReleaseTag = tags.contains('post-release') || tags.contains('дожим');

    if (release?.alreadyReleased == true || releaseStage == 'релиз уже вышел') {
      return isPostReleaseTag ? 1 : 0.15;
    }
    if (days != null && days <= 14) {
      return isPreReleaseTag ? 1 : 0.25;
    }
    if (releaseStage.contains('через 14') || releaseStage.contains('через 7')) {
      return isPreReleaseTag ? 0.95 : 0.2;
    }
    if (releaseStage.contains('релиза пока нет')) {
      return tags.contains('цикл') || tags.contains('система') ? 0.8 : 0.3;
    }
    return 0.4;
  }

  double _progressFit(
    NavigatorMaterial material,
    NavigatorOnboardingAnswers answers,
    NavigatorProgressSignal? progress,
  ) {
    final tags = material.tags.map((e) => e.toLowerCase()).toSet();
    final blocker = answers.blocker.toLowerCase();
    final disciplineTag = tags.contains('дисциплина') ||
        tags.contains('ритм') ||
        tags.contains('система') ||
        tags.contains('микрошаги');
    if (blocker.contains('дисциплины') || blocker.contains('нет системы')) {
      return disciplineTag ? 1 : 0.2;
    }
    if (progress?.disciplineDrop == true) {
      return disciplineTag ? 0.95 : 0.25;
    }
    return 0.45;
  }

  double _dnkFit(NavigatorMaterial material, NavigatorDnkSignal? dnk) {
    if (dnk == null || dnk.focusTags.isEmpty) return 0.2;
    final tags = material.tags.map((e) => e.toLowerCase()).toSet();
    final dnkTags = dnk.focusTags.map((e) => e.toLowerCase()).toSet();
    final overlap = tags.intersection(dnkTags).length;
    if (overlap == 0) return 0.1;
    return (overlap / dnkTags.length).clamp(0, 1).toDouble();
  }

  double _freshness(DateTime updatedAt) {
    final days = DateTime.now().difference(updatedAt).inDays;
    if (days <= 7) return 1;
    if (days <= 30) return 0.7;
    if (days <= 60) return 0.4;
    return 0.2;
  }

  String _buildWhyNow({
    required NavigatorMaterial item,
    required NavigatorOnboardingAnswers answers,
    NavigatorReleaseSignal? release,
    NavigatorProgressSignal? progress,
    Set<String> completedIds = const {},
  }) {
    if (completedIds.contains(item.id)) {
      return 'Этот материал уже пройден — можно использовать как быстрый референс.';
    }
    if (release?.daysToRelease != null && release!.daysToRelease! <= 14) {
      return 'Сейчас критично закрыть pre-release задачи перед релизом.';
    }
    if (release?.alreadyReleased == true) {
      return 'Релиз уже вышел, фокус смещен на пост-релиз и аналитику.';
    }
    if (progress?.disciplineDrop == true) {
      return 'Виден провал по ритму: этот материал даст простую систему действий.';
    }
    if (item.goals.contains(answers.goal)) {
      return 'Материал напрямую соответствует твоей цели на 30-90 дней.';
    }
    return 'Рекомендация собрана под твой этап и текущий фокус в AURIX.';
  }

  NavigatorQuickAction _quickAction(
    List<NavigatorRecommendationCard> required,
    NavigatorOnboardingAnswers answers,
    NavigatorReleaseSignal? release,
    NavigatorProgressSignal? progress,
  ) {
    if (release?.daysToRelease != null && release!.daysToRelease! <= 14) {
      return const NavigatorQuickAction(
        title: 'Сегодня: закрыть pre-release чекпоинт',
        description:
            'Открой Release Planner и зафиксируй 3 задачи на ближайшие 48 часов: pitching, контент и дедлайны.',
        actionLink: NavigatorActionLink(
          actionType: 'open_release_planner',
          label: 'Открыть Release Planner',
          route: '/releases/create',
        ),
      );
    }
    if (progress?.disciplineDrop == true ||
        answers.blocker.toLowerCase().contains('дисцип') ||
        answers.blocker.toLowerCase().contains('систем')) {
      return const NavigatorQuickAction(
        title: 'Сегодня: один микро-шаг в Progress',
        description:
            'Добавь 1 привычку на неделю и отметь выполнение сегодня. Важна стабильность, не масштаб.',
        actionLink: NavigatorActionLink(
          actionType: 'add_progress_task',
          label: 'Добавить шаг в Progress',
          route: '/progress/manage?new=1',
        ),
      );
    }
    if (answers.goal == 'выстроить контент') {
      return const NavigatorQuickAction(
        title: 'Сегодня: собрать 7-дневный контент-скелет',
        description:
            'Открой Studio AI, сгенерируй каркас контента и привяжи 2 публикации к текущему релизу.',
        actionLink: NavigatorActionLink(
          actionType: 'open_studio_ai',
          label: 'Открыть Studio AI',
          route: '/ai',
        ),
      );
    }
    if (answers.goal.toLowerCase().contains('прав')) {
      return const NavigatorQuickAction(
        title: 'Сегодня: зафиксировать правовой минимум',
        description:
            'Открой материал по правам, выпиши владельцев мастер/паблишинг и сверить риски по текущим договоренностям.',
        actionLink: NavigatorActionLink(
          actionType: 'open_finances',
          label: 'Открыть Финансы',
          route: '/finance',
        ),
      );
    }
    final best = required.isNotEmpty ? required.first.material : null;
    final fallback = best?.actionLinks.firstWhere(
          (a) => a.actionType != 'save_to_route',
          orElse: () => const NavigatorActionLink(
            actionType: 'open_studio_ai',
            label: 'Открыть Studio AI',
            route: '/ai',
          ),
        ) ??
        const NavigatorActionLink(
          actionType: 'open_studio_ai',
          label: 'Открыть Studio AI',
          route: '/ai',
        );
    return NavigatorQuickAction(
      title: 'Сегодня: запустить следующий лучший шаг',
      description:
          'Сфокусируйся на одном действии из маршрута и закрепи его в продукте сразу после чтения.',
      actionLink: fallback,
    );
  }

  List<NavigatorRouteStep> _buildRoute(
    List<NavigatorRecommendationCard> required,
    List<NavigatorRecommendationCard> additional,
    NavigatorOnboardingAnswers answers,
    Set<String> completedIds,
  ) {
    final picked = <NavigatorRecommendationCard>[
      ...required,
      ...additional,
    ].take(6).toList();
    final out = <NavigatorRouteStep>[];
    for (var i = 0; i < picked.length; i++) {
      final card = picked[i];
      final action = NavigatorActionLink(
        actionType: 'open_article',
        label: 'Открыть материал',
        route: '/navigator/article/${card.material.slug}',
      );
      final status = i == 0
          ? (completedIds.contains(card.material.id)
              ? NavigatorRouteStepStatus.done
              : NavigatorRouteStepStatus.inProgress)
          : (completedIds.contains(card.material.id)
              ? NavigatorRouteStepStatus.done
              : NavigatorRouteStepStatus.notStarted);
      out.add(
        NavigatorRouteStep(
          index: i + 1,
          title: card.material.title,
          description: card.material.excerpt,
          status: status,
          etaMinutes: card.material.readingTimeMinutes,
          action: action,
          whyRecommended: card.whyNow,
        ),
      );
    }
    if (out.isEmpty) {
      out.add(
        const NavigatorRouteStep(
          index: 1,
          title: 'Позиционирование артиста',
          description: 'Сформируй ядро образа и вектор контента.',
          status: NavigatorRouteStepStatus.inProgress,
          etaMinutes: 20,
          action: NavigatorActionLink(
            actionType: 'open_dnk',
            label: 'Открыть DNK',
            route: '/dnk',
          ),
          whyRecommended: 'Без этого контент и релизы будут хаотичными.',
        ),
      );
    }
    if (answers.goal == 'подготовить релиз' && out.length < 6) {
      out.add(
        NavigatorRouteStep(
          index: out.length + 1,
          title: 'Подготовка релиза',
          description: 'Собери чеклист pre-release и дедлайны.',
          status: NavigatorRouteStepStatus.notStarted,
          etaMinutes: 25,
          action: const NavigatorActionLink(
            actionType: 'open_release_planner',
            label: 'Открыть Release Planner',
            route: '/releases/create',
          ),
          whyRecommended: 'Свяжет обучение с действием внутри AURIX.',
        ),
      );
    }
    return out;
  }

  String _buildExplanation(
    NavigatorOnboardingAnswers answers,
    NavigatorReleaseSignal? release,
    NavigatorProgressSignal? progress,
  ) {
    final parts = <String>[
      'Сейчас ты на этапе: ${answers.stage.toLowerCase()}',
      'текущая цель: ${answers.goal.toLowerCase()}',
      'ключевой блокер: ${answers.blocker.toLowerCase()}',
    ];
    parts.add('рынок: ${answers.marketRegion == 'ru_cis' ? 'RU/CIS' : 'global'}');
    if (answers.releaseExperience.isNotEmpty) {
      parts.add('релизный опыт: ${answers.releaseExperience.toLowerCase()}');
    }
    if (answers.teamSetup.isNotEmpty) {
      parts.add('команда: ${answers.teamSetup.toLowerCase()}');
    }
    if (release?.daysToRelease != null) {
      parts.add('дней до релиза: ${release!.daysToRelease}');
    } else if (release?.alreadyReleased == true) {
      parts.add('фокус: post-release стратегия');
    }
    if (progress != null) {
      parts.add('ритм Progress: ${(progress.consistencyScore * 100).round()}%');
    }
    return '${parts.join(' · ')}. Поэтому маршрут начинается с шага, который убирает главный тормоз роста и сразу переводит тебя к действию в AURIX.';
  }
}
