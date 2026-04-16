import 'package:flutter/foundation.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'creative_model.dart';

/// Generates creative text (hooks, lines, structure ideas) via backend AI.
class CreativeService {
  static int _idCounter = 0;

  static final _prompts = <CreativeType, String>{
    CreativeType.hook:
      'Придумай 4 варианта цепляющего хука для трека. '
      'Каждый хук — 1-2 строки, запоминающийся, ритмичный. '
      'Ответ: пронумерованный список, только текст хуков, без пояснений.',
    CreativeType.line:
      'Продолжи текст трека. Придумай 4 варианта следующих 2-4 строк. '
      'Сохрани стиль и ритм. '
      'Ответ: пронумерованный список вариантов, только текст.',
    CreativeType.structure:
      'Предложи 3 идеи что делать дальше с этим треком: '
      'структура, развитие, бридж, аутро. '
      'Короткие конкретные советы, по 1-2 предложения каждый. '
      'Ответ: пронумерованный список.',
  };

  /// Generate creative suggestions. Returns 3-5 items.
  static Future<List<CreativeSuggestion>> generate(CreativeContext ctx) async {
    final prompt = _prompts[ctx.requestType] ?? _prompts[CreativeType.hook]!;

    final contextParts = <String>[];
    contextParts.add('BPM: ${ctx.bpm.round()}');
    if (ctx.mood != null && ctx.mood!.isNotEmpty) {
      contextParts.add('Настроение: ${ctx.mood}');
    }
    if (ctx.currentLyrics != null && ctx.currentLyrics!.isNotEmpty) {
      contextParts.add('Текущий текст:\n${ctx.currentLyrics}');
    }
    contextParts.add('Дорожек вокала: ${ctx.vocalTrackCount}');

    final message = '$prompt\n\nКонтекст:\n${contextParts.join('\n')}';

    try {
      final res = await ApiClient.post(
        '/api/ai/chat',
        data: {
          'message': message,
          'mode': 'studio_creative',
          'locale': 'ru',
          'history': <Map<String, String>>[],
          'context_mode': 'clean',
        },
        receiveTimeout: const Duration(seconds: 15),
      );

      final data = res.data;
      String reply = '';
      if (data is Map<String, dynamic>) {
        reply = (data['reply'] as String?) ?? '';
      }

      if (reply.isEmpty) return _fallback(ctx.requestType);

      return _parseResponse(reply, ctx.requestType);
    } catch (e) {
      debugPrint('[CreativeService] Error: $e');
      return _fallback(ctx.requestType);
    }
  }

  /// Parse numbered list from AI response into suggestions.
  static List<CreativeSuggestion> _parseResponse(String text, CreativeType type) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final results = <CreativeSuggestion>[];

    for (final line in lines) {
      // Strip numbering: "1. text", "1) text", "- text"
      var clean = line.trim();
      clean = clean.replaceFirst(RegExp(r'^[\d]+[\.\)]\s*'), '');
      clean = clean.replaceFirst(RegExp(r'^[-–•]\s*'), '');
      clean = clean.trim();
      if (clean.isEmpty || clean.length < 3) continue;

      results.add(CreativeSuggestion(
        id: 'creative_${_idCounter++}',
        text: clean,
        type: type,
      ));
    }

    return results.take(5).toList();
  }

  /// Fallback suggestions when API fails.
  static List<CreativeSuggestion> _fallback(CreativeType type) {
    final items = switch (type) {
      CreativeType.hook => [
        'Я на волне, и волна не спадёт',
        'Каждый день — новый шанс, каждый бит — новый шаг',
        'Звук в наушниках громче, чем мир за окном',
      ],
      CreativeType.line => [
        'Поднимаюсь выше, вижу город внизу',
        'Не ищу дорогу — я её создаю',
        'Ритм ведёт меня, и я не сверну',
      ],
      CreativeType.structure => [
        'Добавь бридж после второго куплета — смени ритм подачи',
        'Повтори хук 2 раза в конце для запоминаемости',
        'Сделай паузу перед последним куплетом — тишина усиливает',
      ],
    };

    return items
        .map((t) => CreativeSuggestion(
              id: 'creative_${_idCounter++}',
              text: t,
              type: type,
            ))
        .toList();
  }
}
