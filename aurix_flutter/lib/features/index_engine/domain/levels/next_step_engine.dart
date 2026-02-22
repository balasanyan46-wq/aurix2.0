import 'dart:math' as math;
import 'package:aurix_flutter/features/index_engine/data/models/index_score.dart';
import 'package:aurix_flutter/features/index_engine/data/models/metrics_snapshot.dart';
import 'package:aurix_flutter/features/index_engine/domain/levels/next_step.dart';

/// Generates 3 actionable next steps from breakdown + metrics.
class NextStepEngine {
  NextStepPlan buildNextSteps(
    IndexScore score,
    MetricsSnapshot snapshot, {
    MetricsSnapshot? prev,
    int? top10Score,
  }) {
    final steps = <NextStep>[];
    final breakdown = score.breakdown;

    final components = ['growth', 'engagement', 'consistency', 'momentum', 'community'];
    final sorted = components
        .map((k) => (k, breakdown[k] ?? 0.0))
        .toList()
      ..sort((a, b) => a.$2.compareTo(b.$2));

    final weakest = sorted.first.$1;
    final secondWeak = sorted.length > 1 ? sorted[1].$1 : weakest;

    if (score.penaltyApplied > 0) {
      steps.add(NextStep(
        title: 'Снизь аномалии',
        description: 'Избегай резких всплесков без вовлечения. Стабильный рост важнее скачков.',
        metricKey: 'penalty',
        targetDelta: 0,
        actionType: 'metadata',
        priority: 10,
      ));
    }

    if (weakest == 'engagement') {
      final streams = math.max(snapshot.streams, 1);
      final targetSaves = math.max(50, (streams * 0.01).round());
      steps.add(NextStep(
        title: 'Подними saves rate',
        description: 'Добавь +$targetSaves сохранений в этом месяце. Качество трека и обложка влияют на saves.',
        metricKey: 'savesRate',
        targetDelta: targetSaves,
        actionType: 'metadata',
        priority: 1,
      ));
    } else if (weakest == 'consistency') {
      steps.add(NextStep(
        title: 'Выпусти релиз',
        description: '1 релиз в этом месяце = +X к consistency. Регулярность важнее объёма.',
        metricKey: 'releaseCount',
        targetDelta: 1,
        actionType: 'release',
        priority: 1,
      ));
    } else if (weakest == 'community') {
      steps.add(NextStep(
        title: 'Сделай коллаборацию',
        description: '1 коллаб = +X к community. Совместные треки расширяют аудиторию.',
        metricKey: 'collabCount',
        targetDelta: 1,
        actionType: 'collab',
        priority: 1,
      ));
    } else if (weakest == 'growth') {
      steps.add(NextStep(
        title: 'Ускорь рост',
        description: 'Работай над pre-save и анонсами. Рост listeners и streams повышает Growth.',
        metricKey: 'listeners',
        targetDelta: 100,
        actionType: 'promo',
        priority: 1,
      ));
    } else if (weakest == 'momentum') {
      steps.add(NextStep(
        title: 'Поддержи момент',
        description: 'Продолжай активность: релизы, посты, коллабы. Momentum = ускорение роста.',
        metricKey: 'momentum',
        targetDelta: 0,
        actionType: 'promo',
        priority: 1,
      ));
    }

    if (secondWeak == 'engagement' && weakest != 'engagement' && steps.length < 3) {
      steps.add(NextStep(
        title: 'Сделай 3 коротких клипа',
        description: 'Клипы под припев повышают удержание и completion rate.',
        metricKey: 'completionRate',
        targetDelta: 0.1,
        actionType: 'promo',
        priority: 2,
      ));
    }
    if (secondWeak == 'consistency' && weakest != 'consistency' && steps.length < 3) {
      steps.add(NextStep(
        title: 'Запланируй следующий релиз',
        description: 'Регулярность = ключ к Consistency. Цель: 1 релиз в 1–2 месяца.',
        metricKey: 'releaseCount',
        targetDelta: 1,
        actionType: 'release',
        priority: 2,
      ));
    }

    if (steps.length < 3 && weakest != 'community') {
      steps.add(NextStep(
        title: 'Быстрый win: коллаб или лайв',
        description: 'Коллаборация или концерт добавляют очки в Community.',
        metricKey: 'community',
        targetDelta: 1,
        actionType: 'collab',
        priority: 3,
      ));
    }

    steps.sort((a, b) => a.priority.compareTo(b.priority));
    final top3 = steps.take(3).toList();

    int? toTop10Delta;
    if (top10Score != null && score.rankOverall > 10) {
      toTop10Delta = top10Score - score.score;
    }

    return NextStepPlan(
      steps: top3,
      toTop10Delta: toTop10Delta,
      forecast: toTop10Delta != null && toTop10Delta > 0
          ? 'До Top 10: +$toTop10Delta баллов'
          : null,
    );
  }
}
