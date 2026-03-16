class NavigatorClusters {
  static const String yandexMusic = 'yandex_music';
  static const String vkMusic = 'vk_music';
  static const String legalSafety = 'legal_safety';
  static const String contractsRights = 'contracts_rights';
  static const String artistBrand = 'artist_brand';

  static const Set<String> ruCisPriority = {
    yandexMusic,
    vkMusic,
    legalSafety,
    contractsRights,
    artistBrand,
  };

  static String label(String value) {
    switch (value) {
      case yandexMusic:
        return 'Яндекс Музыка';
      case vkMusic:
        return 'VK Музыка';
      case legalSafety:
        return 'Право и безопасность';
      case contractsRights:
        return 'Договоры и права';
      case artistBrand:
        return 'Бренд артиста';
      default:
        return value;
    }
  }
}

class NavigatorSourceRef {
  final String title;
  final String url;
  final String sourceType;
  final String note;

  const NavigatorSourceRef({
    required this.title,
    required this.url,
    required this.sourceType,
    required this.note,
  });

  factory NavigatorSourceRef.fromJson(Map<String, dynamic> json) {
    return NavigatorSourceRef(
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      sourceType: json['source_type'] as String? ?? 'official',
      note: json['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'url': url,
        'source_type': sourceType,
        'note': note,
      };
}

class NavigatorActionLink {
  final String actionType;
  final String label;
  final String route;
  final Map<String, dynamic>? payload;

  const NavigatorActionLink({
    required this.actionType,
    required this.label,
    required this.route,
    this.payload,
  });

  factory NavigatorActionLink.fromJson(Map<String, dynamic> json) {
    return NavigatorActionLink(
      actionType: json['action_type'] as String? ?? '',
      label: json['label'] as String? ?? '',
      route: json['route'] as String? ?? '/home',
      payload: (json['payload'] as Map?)?.cast<String, dynamic>(),
    );
  }

  Map<String, dynamic> toJson() => {
        'action_type': actionType,
        'label': label,
        'route': route,
        if (payload != null) 'payload': payload,
      };
}

class NavigatorBodyBlock {
  final String kind;
  final String title;
  final String text;
  final List<String> items;

  const NavigatorBodyBlock({
    required this.kind,
    required this.title,
    required this.text,
    this.items = const [],
  });

  factory NavigatorBodyBlock.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    return NavigatorBodyBlock(
      kind: json['kind'] as String? ?? 'text',
      title: json['title'] as String? ?? '',
      text: json['text'] as String? ?? '',
      items: rawItems.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'title': title,
        'text': text,
        'items': items,
      };
}

class NavigatorMaterial {
  final String id;
  final String slug;
  final String title;
  final String subtitle;
  final String excerpt;
  final List<NavigatorBodyBlock> bodyBlocks;
  final String category;
  final List<String> tags;
  final List<String> platforms;
  final List<String> stages;
  final List<String> goals;
  final List<String> blockers;
  final String difficulty;
  final int readingTimeMinutes;
  final String formatType;
  final List<NavigatorActionLink> actionLinks;
  final List<NavigatorSourceRef> sourcePack;
  final DateTime? lastReviewedAt;
  final bool isFeatured;
  final bool isPublished;
  final double priorityScore;
  final List<String> relatedContentIds;
  final List<String> relatedTools;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NavigatorMaterial({
    required this.id,
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.excerpt,
    required this.bodyBlocks,
    required this.category,
    required this.tags,
    required this.platforms,
    required this.stages,
    required this.goals,
    required this.blockers,
    required this.difficulty,
    required this.readingTimeMinutes,
    required this.formatType,
    required this.actionLinks,
    required this.sourcePack,
    required this.lastReviewedAt,
    required this.isFeatured,
    required this.isPublished,
    required this.priorityScore,
    required this.relatedContentIds,
    this.relatedTools = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory NavigatorMaterial.fromJson(Map<String, dynamic> json) {
    final rawBody = (json['body_blocks'] as List?) ?? const [];
    final rawTags = (json['tags'] as List?) ?? const [];
    final rawPlatforms =
        (json['platforms'] as List?) ?? (json['platform_tags'] as List?) ?? const [];
    final rawStages =
        (json['stages'] as List?) ?? (json['stage_tags'] as List?) ?? const [];
    final rawGoals =
        (json['goals'] as List?) ?? (json['goal_tags'] as List?) ?? const [];
    final rawBlockers = (json['blockers'] as List?) ?? const [];
    final rawActions =
        (json['action_links'] as List?) ?? (json['action_pack'] as List?) ?? const [];
    final rawSources = (json['source_pack'] as List?) ?? const [];
    final rawRelated =
        (json['related_content_ids'] as List?) ?? (json['related_articles'] as List?) ?? const [];
    final now = DateTime.now();
    return NavigatorMaterial(
      id: json['id'] as String,
      slug: json['slug'] as String,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      excerpt: json['excerpt'] as String? ?? json['short_description'] as String? ?? '',
      bodyBlocks: rawBody
          .whereType<Map>()
          .map((e) => NavigatorBodyBlock.fromJson(e.cast<String, dynamic>()))
          .toList(),
      category:
          json['category'] as String? ?? json['cluster'] as String? ?? 'Старт и позиционирование',
      tags: rawTags.map((e) => e.toString()).toList(),
      platforms: rawPlatforms.map((e) => e.toString()).toList(),
      stages: rawStages.map((e) => e.toString()).toList(),
      goals: rawGoals.map((e) => e.toString()).toList(),
      blockers: rawBlockers.map((e) => e.toString()).toList(),
      difficulty: json['difficulty'] as String? ?? 'средний',
      readingTimeMinutes: (json['reading_time_minutes'] as num?)?.toInt() ?? 6,
      formatType: json['format_type'] as String? ?? 'guide',
      actionLinks: rawActions
          .whereType<Map>()
          .map((e) => NavigatorActionLink.fromJson(e.cast<String, dynamic>()))
          .toList(),
      sourcePack: rawSources
          .whereType<Map>()
          .map((e) => NavigatorSourceRef.fromJson(e.cast<String, dynamic>()))
          .toList(),
      lastReviewedAt: json['last_reviewed_at'] == null
          ? null
          : DateTime.tryParse(json['last_reviewed_at'] as String),
      isFeatured: json['is_featured'] as bool? ?? false,
      isPublished: json['is_published'] as bool? ?? true,
      priorityScore: (json['priority_score'] as num?)?.toDouble() ?? 0.5,
      relatedContentIds: rawRelated.map((e) => e.toString()).toList(),
      relatedTools:
          ((json['related_tools'] as List?) ?? const []).map((e) => e.toString()).toList(),
      createdAt: json['created_at'] == null
          ? now
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? now
          : DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'title': title,
        'subtitle': subtitle,
        'excerpt': excerpt,
        'body_blocks': bodyBlocks.map((e) => e.toJson()).toList(),
        'category': category,
        'tags': tags,
        'platforms': platforms,
        'stages': stages,
        'goals': goals,
        'blockers': blockers,
        'difficulty': difficulty,
        'reading_time_minutes': readingTimeMinutes,
        'format_type': formatType,
        'action_links': actionLinks.map((e) => e.toJson()).toList(),
        'source_pack': sourcePack.map((e) => e.toJson()).toList(),
        'last_reviewed_at': lastReviewedAt?.toIso8601String(),
        'is_featured': isFeatured,
        'is_published': isPublished,
        'priority_score': priorityScore,
        'related_content_ids': relatedContentIds,
        'related_tools': relatedTools,
        'cluster': category,
        'short_description': excerpt,
        'stage_tags': stages,
        'goal_tags': goals,
        'platform_tags': platforms,
        'action_pack': actionLinks.map((e) => e.toJson()).toList(),
        'related_articles': relatedContentIds,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  String get durationBucket {
    if (readingTimeMinutes <= 10) return 'до 10 минут';
    if (readingTimeMinutes <= 30) return '10-30 минут';
    return '30+ минут';
  }

  // Aliases for content-system compatibility with old/new naming.
  String get cluster => category;
  String get shortDescription => excerpt;
  List<String> get stageTags => stages;
  List<String> get goalTags => goals;
  List<String> get platformTags => platforms;
  List<NavigatorActionLink> get actionPack => actionLinks;
  List<String> get relatedArticles => relatedContentIds;
}

class NavigatorOnboardingAnswers {
  final String stage;
  final String goal;
  final String releaseStage;
  final List<String> platforms;
  final String blocker;
  final String depth;
  final String marketRegion;
  final String releaseExperience;
  final String teamSetup;
  final String confusionArea;
  final String learningHoursPerWeek;
  final String desiredOutcome;

  const NavigatorOnboardingAnswers({
    required this.stage,
    required this.goal,
    required this.releaseStage,
    required this.platforms,
    required this.blocker,
    required this.depth,
    this.marketRegion = 'ru_cis',
    this.releaseExperience = '',
    this.teamSetup = '',
    this.confusionArea = '',
    this.learningHoursPerWeek = '',
    this.desiredOutcome = '',
  });

  Map<String, dynamic> toJson() => {
        'stage': stage,
        'goal': goal,
        'release_stage': releaseStage,
        'platforms': platforms,
        'blocker': blocker,
        'depth': depth,
        'market_region': marketRegion,
        'release_experience': releaseExperience,
        'team_setup': teamSetup,
        'confusion_area': confusionArea,
        'learning_hours_per_week': learningHoursPerWeek,
        'desired_outcome': desiredOutcome,
      };

  factory NavigatorOnboardingAnswers.fromJson(Map<String, dynamic> json) {
    return NavigatorOnboardingAnswers(
      stage: json['stage'] as String? ?? '',
      goal: json['goal'] as String? ?? '',
      releaseStage: json['release_stage'] as String? ?? '',
      platforms:
          ((json['platforms'] as List?) ?? const []).map((e) => e.toString()).toList(),
      blocker: json['blocker'] as String? ?? '',
      depth: json['depth'] as String? ?? 'средний',
      marketRegion: json['market_region'] as String? ?? 'ru_cis',
      releaseExperience: json['release_experience'] as String? ?? '',
      teamSetup: json['team_setup'] as String? ?? '',
      confusionArea: json['confusion_area'] as String? ?? '',
      learningHoursPerWeek: json['learning_hours_per_week'] as String? ?? '',
      desiredOutcome: json['desired_outcome'] as String? ?? '',
    );
  }
}

class NavigatorDnkSignal {
  final List<String> focusTags;
  const NavigatorDnkSignal({required this.focusTags});
}

class NavigatorProgressSignal {
  final double consistencyScore;
  final bool disciplineDrop;
  const NavigatorProgressSignal({
    required this.consistencyScore,
    required this.disciplineDrop,
  });
}

class NavigatorReleaseSignal {
  final int? daysToRelease;
  final bool alreadyReleased;
  const NavigatorReleaseSignal({
    required this.daysToRelease,
    required this.alreadyReleased,
  });
}

class NavigatorRecommendationCard {
  final NavigatorMaterial material;
  final String whyNow;
  final double score;
  final String recommendationBadge;
  final List<String> suggestedBadges;
  final String? statusBadge;
  final String personalReason;
  final int importanceLevel;

  const NavigatorRecommendationCard({
    required this.material,
    required this.whyNow,
    required this.score,
    required this.recommendationBadge,
    this.suggestedBadges = const [],
    this.statusBadge,
    this.personalReason = '',
    this.importanceLevel = 1,
  });
}

class NavigatorQuickAction {
  final String title;
  final String description;
  final NavigatorActionLink actionLink;

  const NavigatorQuickAction({
    required this.title,
    required this.description,
    required this.actionLink,
  });
}

class NavigatorRecommendationResult {
  final NavigatorRecommendationCard nextBestStep;
  final List<NavigatorRecommendationCard> recommendedMaterials;
  final List<NavigatorRecommendationCard> criticalMaterials;
  final List<NavigatorRecommendationCard> quickWins;
  final List<NavigatorRouteStep> routeSteps;
  final List<NavigatorRecommendationCard> topRequired;
  final List<NavigatorRecommendationCard> topAdditional;
  final NavigatorQuickAction quickAction;
  final String explanation;
  final int estimatedMinutes;

  const NavigatorRecommendationResult({
    required this.nextBestStep,
    required this.recommendedMaterials,
    required this.criticalMaterials,
    required this.quickWins,
    required this.routeSteps,
    required this.topRequired,
    required this.topAdditional,
    required this.quickAction,
    required this.explanation,
    required this.estimatedMinutes,
  });
}

enum NavigatorRouteStepStatus { notStarted, inProgress, done }

class NavigatorRouteStep {
  final int index;
  final String title;
  final String description;
  final NavigatorRouteStepStatus status;
  final int etaMinutes;
  final NavigatorActionLink action;
  final String whyRecommended;

  const NavigatorRouteStep({
    required this.index,
    required this.title,
    required this.description,
    required this.status,
    required this.etaMinutes,
    required this.action,
    required this.whyRecommended,
  });
}
