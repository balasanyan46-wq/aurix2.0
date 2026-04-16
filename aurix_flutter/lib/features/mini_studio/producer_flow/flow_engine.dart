import '../domain/track_model.dart';
import 'flow_model.dart';

/// Analyzes project state and generates a producer flow — the steps
/// needed to go from raw recording to release-ready track.
///
/// Max 5 steps. Language is casual, like a real producer talking.
List<FlowStep> generateFlow(List<StudioTrack> tracks) {
  final steps = <FlowStep>[];
  final vocals = tracks.where((t) => !t.isBeat && t.hasAudio).toList();
  final beat = tracks.where((t) => t.isBeat).toList();
  final hasBeat = beat.any((t) => t.hasAudio);

  if (!hasBeat) return steps; // nothing to work with yet

  final totalClips = vocals.expand((t) => t.clips).length;
  final anyFxOn = vocals.any((t) => t.fx.enabled);
  final hasDouble = vocals.length >= 2 && vocals.any((t) => t.name.contains('Dbl'));
  final hasMultipleClips = totalClips >= 3;

  // 1. Sound quality
  if (!anyFxOn && vocals.isNotEmpty) {
    steps.add(FlowStep(
      id: 'improve',
      title: 'Улучшим звук',
      description: 'Сейчас вокал сыроват — добавим компрессию, EQ и реверб. Сразу зазвучит плотнее.',
      action: FlowActions.improveSound,
    ));
  }

  // 2. Timing
  if (vocals.isNotEmpty) {
    bool hasOffGrid = false;
    for (final t in vocals) {
      for (final c in t.clips) {
        // Check if any clip is noticeably off grid
        final beat = tracks.firstWhere((t) => t.isBeat);
        if (beat.hasAudio && c.startTime > 0.1) {
          hasOffGrid = true;
          break;
        }
      }
    }
    if (hasOffGrid && totalClips > 1) {
      steps.add(FlowStep(
        id: 'timing',
        title: 'Подровняем тайминг',
        description: 'Пара мест не в сетке — подвинем клипы чтобы всё попадало в бит.',
        action: FlowActions.fixTiming,
      ));
    }
  }

  // 3. Double
  if (!hasDouble && vocals.isNotEmpty) {
    steps.add(FlowStep(
      id: 'double',
      title: 'Добавим плотности',
      description: 'Дабл-трек сделает вокал объёмнее. Копия с лёгким сдвигом — классический приём.',
      action: FlowActions.addDouble,
    ));
  }

  // 4. Hook / structure
  if (!hasMultipleClips && vocals.isNotEmpty) {
    steps.add(FlowStep(
      id: 'hook',
      title: 'Усилим хук',
      description: 'Повтори хук или добавь адлибы — трек станет цепляющим.',
      action: FlowActions.enhanceHook,
    ));
  }

  // 5. Mix
  if (vocals.length >= 2) {
    steps.add(FlowStep(
      id: 'mix',
      title: 'Сведём баланс',
      description: 'Выровняем громкость дорожек чтобы всё звучало как единый трек.',
      action: FlowActions.autoMix,
    ));
  }

  // 6. Always end with release (if there's audio)
  if (vocals.isNotEmpty) {
    steps.add(FlowStep(
      id: 'release',
      title: 'Готов к релизу',
      description: 'Трек звучит! Экспортируй и выпускай на стриминги.',
      action: FlowActions.prepareRelease,
    ));
  }

  // Cap at 5 steps
  if (steps.length > 5) {
    // Keep first 4 + release
    final release = steps.removeLast();
    while (steps.length > 4) steps.removeLast();
    steps.add(release);
  }

  return steps;
}
