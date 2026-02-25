import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AiChatService {
  static final Uri _endpoint = Uri.parse(
    'https://wandering-snow-3f00.armte1an1.workers.dev/api/ai/chat',
  );

  Future<String> send({
    required String message,
    List<Map<String, String>> history = const [],
  }) async {
    http.Response res;
    try {
      res = await http
          .post(
            _endpoint,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'message': message, 'history': history}),
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw Exception('AI временно недоступен');
    } catch (_) {
      throw Exception('AI временно недоступен');
    }

    if (res.statusCode != 200) {
      throw Exception('AI временно недоступен');
    }

    try {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final reply = decoded['reply'] as String?;
      if (reply == null) throw const FormatException('Missing reply');
      return reply;
    } catch (_) {
      throw Exception('AI временно недоступен');
    }
  }
}

