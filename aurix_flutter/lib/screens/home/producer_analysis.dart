import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/models/report_row_model.dart';
import 'package:aurix_flutter/data/models/team_member_model.dart';

class ArtistUserData {
  final List<ReleaseModel> releases;
  final int focusReleaseTrackCount;
  final List<TeamMemberModel> team;
  final List<ReportRowModel> reportRows;
  final int promoDoneTasks;
  final int? indexDelta;

  const ArtistUserData({
    required this.releases,
    required this.focusReleaseTrackCount,
    required this.team,
    required this.reportRows,
    required this.promoDoneTasks,
    required this.indexDelta,
  });

  ReleaseModel? get focusRelease {
    if (releases.isEmpty) return null;
    // Prefer a draft as "active work"; otherwise the latest release.
    final drafts = releases.where((r) => r.isDraft).toList();
    if (drafts.isNotEmpty) return drafts.first;
    return releases.first;
  }
}

enum ProducerHomeScenario { newUser, draftOnly, published }

enum ProducerArtistLevel { start, formation, stability, growth, scale }

extension ProducerArtistLevelX on ProducerArtistLevel {
  String get label => switch (this) {
        ProducerArtistLevel.start => 'Начало',
        ProducerArtistLevel.formation => 'Формирование',
        ProducerArtistLevel.stability => 'Стабильность',
        ProducerArtistLevel.growth => 'Рост',
        ProducerArtistLevel.scale => 'Масштаб',
      };
}

class ArtistStateAnalysis {
  final ProducerHomeScenario scenario;
  final int releasesCount;
  final int draftsCount;
  final int liveCount;
  final int publishedCount;
  final int inProgressCount;
  final bool hasCover;
  final bool hasTrack;
  final bool hasTeam;
  final bool hasPromotionSignals;
  final bool hasGrowthSignals;
  final bool hasStats;
  final int streamsLast30d;
  final int streamsPrev30d;
  final int? indexDelta;
  final ProducerArtistLevel level;

  const ArtistStateAnalysis({
    required this.scenario,
    required this.releasesCount,
    required this.draftsCount,
    required this.liveCount,
    required this.publishedCount,
    required this.inProgressCount,
    required this.hasCover,
    required this.hasTrack,
    required this.hasTeam,
    required this.hasPromotionSignals,
    required this.hasGrowthSignals,
    required this.hasStats,
    required this.streamsLast30d,
    required this.streamsPrev30d,
    required this.indexDelta,
    required this.level,
  });
}

class ProducerMessage {
  final String headline;
  final String pointNowTitle;
  final String pointNowBody;
  final String energyLeakTitle;
  final String energyLeakBody;
  final String mainFocusTitle;
  final String mainFocusBody;
  final String forecastTitle;
  final String forecastBody;
  final String breakthroughTitle;
  final String breakthroughBody;
  final String primaryActionLabel;

  const ProducerMessage({
    required this.headline,
    required this.pointNowTitle,
    required this.pointNowBody,
    required this.energyLeakTitle,
    required this.energyLeakBody,
    required this.mainFocusTitle,
    required this.mainFocusBody,
    required this.forecastTitle,
    required this.forecastBody,
    required this.breakthroughTitle,
    required this.breakthroughBody,
    required this.primaryActionLabel,
  });
}

ArtistStateAnalysis analyzeArtistState(ArtistUserData userData) {
  final releases = userData.releases;
  final focus = userData.focusRelease;
  final releasesCount = releases.length;
  final draftsCount = releases.where((r) => r.isDraft).length;
  final liveCount = releases.where((r) => r.isLive).length;
  final publishedCount = releases
      .where((r) => r.isLive || r.status == 'approved' || r.status == 'scheduled')
      .length;
  final inProgressCount = releases.where((r) => !r.isLive).length;

  final hasCover = (focus?.coverUrl?.isNotEmpty ?? false) || (focus?.coverPath?.isNotEmpty ?? false);
  final hasTrack = userData.focusReleaseTrackCount > 0;

  // Team/roles: keep internal logic, but never surface technical terms in UI.
  final team = userData.team;
  final splitSum = team.fold<double>(0, (s, m) => s + m.splitPercent);
  final hasTeam = team.isNotEmpty && (splitSum >= 70); // мягкий порог, не требуем идеально 100%

  // Promotion: если есть хоть какие-то выполненные задачи в промо-модуле.
  final hasPromotionSignals = userData.promoDoneTasks > 0;

  // Growth: индекс или стримы по отчётам (если есть даты).
  final now = DateTime.now();
  int streamsLast30d = 0;
  int streamsPrev30d = 0;
  for (final r in userData.reportRows) {
    final d = r.reportDate;
    if (d == null) continue;
    final diff = now.difference(DateTime(d.year, d.month, d.day)).inDays;
    if (diff >= 0 && diff < 30) streamsLast30d += r.streams;
    if (diff >= 30 && diff < 60) streamsPrev30d += r.streams;
  }
  final indexDelta = userData.indexDelta;
  final hasGrowthSignals = (indexDelta != null && indexDelta > 0) || (streamsLast30d > streamsPrev30d && streamsLast30d > 0);
  final hasStats = streamsLast30d > 0 || streamsPrev30d > 0;

  final scenario = releasesCount == 0
      ? ProducerHomeScenario.newUser
      : (draftsCount > 0 && publishedCount == 0)
          ? ProducerHomeScenario.draftOnly
          : ProducerHomeScenario.published;

  ProducerArtistLevel level;
  if (releasesCount == 0) {
    level = ProducerArtistLevel.start;
  } else if (releasesCount <= 1 && (hasCover || hasTrack)) {
    level = ProducerArtistLevel.formation;
  } else if (liveCount >= 1 && !hasGrowthSignals) {
    level = ProducerArtistLevel.stability;
  } else if (hasGrowthSignals && releasesCount <= 5) {
    level = ProducerArtistLevel.growth;
  } else if (hasGrowthSignals && releasesCount >= 6) {
    level = ProducerArtistLevel.scale;
  } else {
    level = ProducerArtistLevel.formation;
  }

  return ArtistStateAnalysis(
    scenario: scenario,
    releasesCount: releasesCount,
    draftsCount: draftsCount,
    liveCount: liveCount,
    publishedCount: publishedCount,
    inProgressCount: inProgressCount,
    hasCover: hasCover,
    hasTrack: hasTrack,
    hasTeam: hasTeam,
    hasPromotionSignals: hasPromotionSignals,
    hasGrowthSignals: hasGrowthSignals,
    hasStats: hasStats,
    streamsLast30d: streamsLast30d,
    streamsPrev30d: streamsPrev30d,
    indexDelta: indexDelta,
    level: level,
  );
}

ProducerMessage buildProducerMessage(ArtistStateAnalysis a) {
  final headline = 'Я посмотрел твой прогресс.';

  if (a.scenario == ProducerHomeScenario.newUser) {
    return const ProducerMessage(
      headline: 'Я посмотрел твой прогресс.',
      pointNowTitle: 'Твоя точка сейчас',
      pointNowBody: 'Ты ещё не выпустил ни одного релиза.',
      energyLeakTitle: '',
      energyLeakBody: '',
      mainFocusTitle: '',
      mainFocusBody: '',
      forecastTitle: '',
      forecastBody: '',
      breakthroughTitle: '',
      breakthroughBody: '',
      primaryActionLabel: 'Создать первый релиз',
    );
  }

  if (a.scenario == ProducerHomeScenario.draftOnly) {
    String oneStep;
    if (!a.hasTrack) {
      oneStep = 'Добавь материал в текущий релиз — это финальная опора перед запуском.';
    } else if (!a.hasCover) {
      oneStep = 'Собери визуал релиза — после этого запуск становится реальным, а не “в процессе”.';
    } else if (!a.hasTeam) {
      oneStep = 'Собери рабочую конфигурацию команды, чтобы закрыть релиз без откатов.';
    } else if (!a.hasPromotionSignals) {
      oneStep = 'Запусти первую волну анонсов, чтобы релиз не стартовал в тишине.';
    } else {
      oneStep = 'Закрой текущий релиз до статуса публикации — это главный шаг к первому подтверждённому результату.';
    }

    return ProducerMessage(
      headline: headline,
      pointNowTitle: 'Текущий релиз',
      pointNowBody: 'У тебя ${a.draftsCount} релиз(а) в работе и пока нет опубликованных.',
      energyLeakTitle: '',
      energyLeakBody: '',
      mainFocusTitle: 'Главный шаг',
      mainFocusBody: oneStep,
      forecastTitle: '',
      forecastBody: '',
      breakthroughTitle: '',
      breakthroughBody: '',
      primaryActionLabel: 'Завершить релиз',
    );
  }

  // Published scenario: only data-backed statements.
  final pointNowTitle = 'Твоя точка сейчас';
  final pointNowBody = a.hasStats
      ? 'Опубликованных релизов: ${a.publishedCount}. Поток за 30 дней: ${a.streamsLast30d}.'
      : 'Опубликованных релизов: ${a.publishedCount}. Статистика пока не загружена.';

  final energyLeakTitle = 'Где теряется энергия';
  final energyLeakBody = a.inProgressCount >= 3
      ? 'У тебя одновременно $a.inProgressCount релизов в работе. Это размывает фокус и замедляет завершение.'
      : (!a.hasPromotionSignals
          ? 'После публикации не видно регулярного продвижения. Рост ограничен не качеством, а частотой контакта.'
          : 'Основная потеря сейчас — в распылении внимания между несколькими задачами вместо одного рычага.');

  final mainFocusTitle = 'Твой главный фокус';
  final mainFocusBody = a.hasStats
      ? (a.streamsLast30d >= a.streamsPrev30d
          ? 'Удержать текущий рост и довести один релиз до следующего уровня охвата.'
          : 'Стабилизировать падение и вернуть рост на одном релизе, а не на нескольких сразу.')
      : 'Сконцентрироваться на одном релизе и одном канале продвижения до появления измеримой динамики.';

  final forecastTitle = 'Если продолжишь так';
  final forecastBody = a.hasStats
      ? (a.streamsLast30d >= a.streamsPrev30d
          ? 'При текущем темпе ты закрепишь рост в ближайшем цикле.'
          : 'При текущей динамике рост замедлится в следующем цикле.')
      : 'Без статистики прогноз ограничен: сначала нужно получить первый измеримый цикл.';

  final breakthroughTitle = 'Прорыв';
  final breakthroughBody = a.hasStats
      ? 'Один точный фокус даст не разовый всплеск, а устойчивую динамику по следующему релизу.'
      : 'Как только появятся первые измеримые данные, можно будет ускорить рост осознанно, а не на интуиции.';

  return ProducerMessage(
    headline: headline,
    pointNowTitle: pointNowTitle,
    pointNowBody: pointNowBody,
    energyLeakTitle: energyLeakTitle,
    energyLeakBody: energyLeakBody,
    mainFocusTitle: mainFocusTitle,
    mainFocusBody: mainFocusBody,
    forecastTitle: forecastTitle,
    forecastBody: forecastBody,
    breakthroughTitle: breakthroughTitle,
    breakthroughBody: breakthroughBody,
    primaryActionLabel: 'Взять фокус',
  );
}

