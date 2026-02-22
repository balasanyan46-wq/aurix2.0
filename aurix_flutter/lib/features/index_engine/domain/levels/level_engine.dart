import 'package:aurix_flutter/features/index_engine/domain/levels/artist_level.dart';

/// Levels by score (0..1000). Rookie → Rising → Pro → Top → Elite.
class LevelEngine {
  static const List<ArtistLevel> _levels = [
    ArtistLevel(
      id: 'rookie',
      title: 'Rookie',
      minScore: 0,
      maxScore: 249,
      perks: ['Базовый индекс', 'Базовый профиль'],
      colorKey: 'gray',
      iconKey: 'seedling',
    ),
    ArtistLevel(
      id: 'rising',
      title: 'Rising',
      minScore: 250,
      maxScore: 449,
      perks: ['Участие в недельных витринах', 'Бейдж Rising'],
      colorKey: 'green',
      iconKey: 'trending_up',
    ),
    ArtistLevel(
      id: 'pro',
      title: 'Pro',
      minScore: 450,
      maxScore: 649,
      perks: ['Доступ к Collab Board', 'Расширенная аналитика'],
      colorKey: 'blue',
      iconKey: 'verified',
    ),
    ArtistLevel(
      id: 'top',
      title: 'Top',
      minScore: 650,
      maxScore: 799,
      perks: ['Авто-номинация в Awards', 'Featured placement'],
      colorKey: 'purple',
      iconKey: 'emoji_events',
    ),
    ArtistLevel(
      id: 'elite',
      title: 'Elite',
      minScore: 800,
      maxScore: 1000,
      perks: ['Elite badge', 'Приоритетные витрины'],
      colorKey: 'orange',
      iconKey: 'diamond',
    ),
  ];

  ArtistLevel getLevel(int score) {
    for (final l in _levels) {
      if (score >= l.minScore && score <= l.maxScore) return l;
    }
    if (score < 0) return _levels.first;
    return _levels.last;
  }

  int pointsToNextLevel(int score) {
    final current = getLevel(score);
    if (current.id == 'elite') return 0;
    final nextIdx = _levels.indexWhere((l) => l.id == current.id) + 1;
    if (nextIdx >= _levels.length) return 0;
    final next = _levels[nextIdx];
    return next.minScore - score;
  }

  double progressToNextLevel(int score) {
    final current = getLevel(score);
    if (current.id == 'elite') return 1.0;
    final nextIdx = _levels.indexWhere((l) => l.id == current.id) + 1;
    if (nextIdx >= _levels.length) return 1.0;
    final next = _levels[nextIdx];
    final span = next.minScore - current.minScore;
    if (span <= 0) return 1.0;
    final progress = (score - current.minScore) / span;
    return progress.clamp(0.0, 1.0);
  }
}
