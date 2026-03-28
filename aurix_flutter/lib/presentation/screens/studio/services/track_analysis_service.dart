import 'package:aurix_flutter/ai/ai_service.dart';
import 'package:aurix_flutter/presentation/screens/studio/models/track_analysis.dart';
import 'package:aurix_flutter/presentation/screens/studio/models/artist_profile.dart';
import 'package:aurix_flutter/presentation/screens/studio/models/ai_memory.dart';

const _systemPrompt = '''Ты музыкальный продюсер-аналитик. Твоя задача — объективно оценить потенциал трека.

Оцени по трём критериям (0–10):
— hookScore: насколько цепляет хук/припев
— vibeScore: атмосфера, настроение, продакшн
— originalityScore: уникальность, свежесть подхода

score — это общая оценка (взвешенное среднее, можешь скорректировать).

Верни строго в формате JSON (без markdown, без текста вне JSON):

{
"score": 0-10,
"hookScore": 0-10,
"vibeScore": 0-10,
"originalityScore": 0-10,
"strengths": ["сильная сторона 1", "сильная сторона 2"],
"weaknesses": ["слабое место 1", "слабое место 2"],
"recommendations": ["что улучшить 1", "что улучшить 2"],
"verdict": "краткий вывод в 1-2 предложениях"
}

Будь честен. Не завышай. Если трек слабый — скажи. Если сильный — объясни почему.''';

/// Analyzes track potential via AI, returns structured result.
class TrackAnalysisService {
  /// [inputText] — concept, lyrics, or full pipeline context.
  static Future<TrackAnalysis> analyze({
    required String inputText,
    ArtistProfile? profile,
    AiMemory? memory,
  }) async {
    final parts = <String>[_systemPrompt];

    if (profile != null && !profile.isEmpty) {
      parts.add('---\n\nАртист:\n${profile.toAiContext()}');
    }

    if (memory != null) {
      final ctx = memory.toAiContext(limit: 3);
      if (ctx.isNotEmpty) parts.add('---\n\n$ctx');
    }

    parts.add('---\n\nМатериал для анализа:\n\n$inputText');

    final reply = await AiService.send(
      message: parts.join('\n\n'),
      history: const [],
      mode: 'chat',
      locale: 'ru',
    );

    final result = TrackAnalysis.tryParse(reply);
    if (result != null) return result;

    // Fallback — AI didn't return valid JSON
    return TrackAnalysis(
      score: 5.0,
      hookScore: 5.0,
      vibeScore: 5.0,
      originalityScore: 5.0,
      strengths: ['AI не смог распарсить результат'],
      weaknesses: [],
      recommendations: ['Попробуйте ещё раз'],
      verdict: reply.length > 200 ? '${reply.substring(0, 200)}...' : reply,
    );
  }
}
