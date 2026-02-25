import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

typedef AiHistoryMessage = ({String role, String content});

class AiChatService {
  static final Uri _endpoint = Uri.parse(
    'https://wandering-snow-3f00.armte1an1.workers.dev/api/ai/chat',
  );

  Future<String> sendAiChat({
    required String message,
    List<AiHistoryMessage> history = const [],
  }) async {
    final payload = <String, dynamic>{
      'message': message,
      'history': history
          .map((m) => {'role': m.role, 'content': m.content})
          .toList(growable: false),
    };

    http.Response res;
    try {
      res = await http
          .post(
            _endpoint,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw Exception('AI не ответил за 30 секунд. Попробуйте ещё раз.');
    } catch (e) {
      throw Exception('Ошибка сети при запросе к AI: $e');
    }

    if (res.statusCode != 200) {
      final body = res.body.trim();
      final suffix = body.isEmpty ? '' : ' — $body';
      throw Exception('AI endpoint вернул ${res.statusCode}$suffix');
    }

    try {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final reply = decoded['reply'] as String?;
      if (reply == null || reply.trim().isEmpty) {
        throw Exception('Пустой ответ AI');
      }
      return reply.trim();
    } catch (e) {
      throw Exception('Некорректный ответ AI: $e');
    }
  }
}

