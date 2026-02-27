import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dnk_models.dart';

class DnkService {
  static const String _workerBase =
      'https://wandering-snow-3f00.armtelan1.workers.dev';

  static const Duration _startTimeout = Duration(seconds: 15);
  static const Duration _answerTimeout = Duration(seconds: 10);
  static const Duration _finishTimeout = Duration(seconds: 120);

  /// POST /dnk/start
  Future<String> startSession(String userId) async {
    final body = await _post('/dnk/start', {'user_id': userId}, timeout: _startTimeout);
    final sessionId = body['session_id'] as String?;
    if (sessionId == null) throw Exception('Не удалось создать сессию DNK');
    return sessionId;
  }

  /// POST /dnk/answer
  Future<DnkFollowup?> submitAnswer({
    required String sessionId,
    required String questionId,
    required String answerType,
    required Map<String, dynamic> answerJson,
  }) async {
    final body = await _post('/dnk/answer', {
      'session_id': sessionId,
      'question_id': questionId,
      'answer_type': answerType,
      'answer_json': answerJson,
    }, timeout: _answerTimeout);

    final followup = body['followup'];
    if (followup != null && followup is Map<String, dynamic>) {
      return DnkFollowup.fromJson(followup);
    }
    return null;
  }

  /// POST /dnk/finish — synchronous: Worker generates and returns full result.
  /// Takes 20-60 seconds. Client waits with 120s timeout.
  Future<DnkResult> finishAndWait(String sessionId, {String styleLevel = 'normal'}) async {
    final body = await _post('/dnk/finish', {
      'session_id': sessionId,
      'style_level': styleLevel,
    }, timeout: _finishTimeout);

    if (body['status'] == 'ready') {
      return DnkResult.fromJson(body);
    }

    throw Exception(body['error']?.toString() ?? 'Генерация не удалась');
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> payload, {
    Duration? timeout,
  }) async {
    final uri = Uri.parse('$_workerBase$path');
    final effectiveTimeout = timeout ?? const Duration(seconds: 30);
    if (kDebugMode) debugPrint('[DNK] POST $path');

    http.Response res;
    try {
      res = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(effectiveTimeout);
    } on TimeoutException {
      throw Exception('DNK: сервер не ответил вовремя');
    } catch (_) {
      throw Exception('DNK: ошибка сети');
    }

    if (res.statusCode != 200) {
      String msg = 'DNK: ошибка сервера (${res.statusCode})';
      try {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        if (decoded['error'] != null) msg = decoded['error'].toString();
      } catch (_) {}
      throw Exception(msg);
    }

    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('DNK: некорректный ответ сервера');
    }
  }
}
