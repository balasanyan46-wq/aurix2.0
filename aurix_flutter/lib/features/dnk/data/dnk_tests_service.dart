import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:aurix_flutter/config/app_config.dart';
import 'dnk_tests_models.dart';

class DnkTestsService {
  static String get _workerBase => AppConfig.cfBaseUrl;

  static const Duration _shortTimeout = Duration(seconds: 15);
  static const Duration _finishTimeout = Duration(seconds: 120);

  Future<List<DnkTestCatalogItem>> getCatalog() async {
    final body = await _get('/dnk-tests/catalog', timeout: _shortTimeout);
    final list = (body['tests'] is List) ? body['tests'] as List : const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(DnkTestCatalogItem.fromJson)
        .toList();
  }

  Future<DnkTestStartResponse> startSession({
    required String userId,
    required String testSlug,
  }) async {
    final body = await _post('/dnk-tests/start', {
      'user_id': userId,
      'test_slug': testSlug,
    }, timeout: _shortTimeout);
    return DnkTestStartResponse.fromJson(body);
  }

  Future<DnkTestFollowupResponse> submitAnswer({
    required String sessionId,
    required String questionId,
    required String answerType,
    required Map<String, dynamic> answerJson,
  }) async {
    final body = await _post('/dnk-tests/answer', {
      'session_id': sessionId,
      'question_id': questionId,
      'answer_type': answerType,
      'answer_json': answerJson,
    }, timeout: _shortTimeout);
    return DnkTestFollowupResponse.fromJson(body);
  }

  Future<DnkTestResult> finishAndWait(String sessionId) async {
    final body = await _post('/dnk-tests/finish', {
      'session_id': sessionId,
    }, timeout: _finishTimeout);
    if (body['status'] == 'ready') {
      return DnkTestResult.fromJson(body);
    }
    throw Exception(body['error']?.toString() ?? 'DNK tests: ошибка генерации');
  }

  Future<DnkTestResult?> getLatestResultBySession(String sessionId) async {
    final body = await _get('/dnk-tests/result?session_id=$sessionId', timeout: _shortTimeout);
    if (body['status'] != 'ready') return null;
    return DnkTestResult.fromJson(body);
  }

  Future<DnkTestResult?> getResultById(String resultId) async {
    final body = await _get('/dnk-tests/result?result_id=$resultId', timeout: _shortTimeout);
    if (body['status'] != 'ready') return null;
    return DnkTestResult.fromJson(body);
  }

  Future<List<DnkTestProgressItem>> getProgress(String userId) async {
    try {
      final body = await _get('/dnk-tests/progress?user_id=$userId', timeout: _shortTimeout);
      final list = (body['progress'] is List) ? body['progress'] as List : const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(DnkTestProgressItem.fromJson)
          .where((x) => x.testSlug.isNotEmpty && x.completed)
          .toList();
    } catch (_) {
      // Backward compatibility for worker versions without /dnk-tests/progress.
      return const [];
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> payload, {
    Duration? timeout,
  }) async {
    final uri = Uri.parse('$_workerBase$path');
    final effectiveTimeout = timeout ?? const Duration(seconds: 30);
    if (kDebugMode) debugPrint('[DNK-TESTS] POST $path');

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
      throw Exception('DNK tests: сервер не ответил вовремя');
    } catch (_) {
      throw Exception('DNK tests: ошибка сети');
    }

    if (res.statusCode != 200) {
      throw Exception(_humanizeError(res.statusCode, res.body));
    }

    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('DNK tests: некорректный ответ сервера');
    }
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Duration? timeout,
  }) async {
    final uri = Uri.parse('$_workerBase$path');
    final effectiveTimeout = timeout ?? const Duration(seconds: 20);
    if (kDebugMode) debugPrint('[DNK-TESTS] GET $path');
    http.Response res;
    try {
      res = await http.get(uri).timeout(effectiveTimeout);
    } on TimeoutException {
      throw Exception('DNK tests: сервер не ответил вовремя');
    } catch (_) {
      throw Exception('DNK tests: ошибка сети');
    }
    if (res.statusCode != 200) {
      throw Exception(_humanizeError(res.statusCode, res.body));
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  String _humanizeError(int statusCode, String body) {
    final fallback = 'DNK tests: ошибка сервера ($statusCode)';
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final raw = decoded['error']?.toString() ?? fallback;
      final lower = raw.toLowerCase();
      if (lower.contains('pgrst205') || lower.contains('dnk_test_sessions')) {
        return 'DNK tests: нужно применить миграцию БД (таблицы тестов пока не созданы)';
      }
      return raw;
    } catch (_) {
      final lower = body.toLowerCase();
      if (lower.contains('pgrst205') || lower.contains('dnk_test_sessions')) {
        return 'DNK tests: нужно применить миграцию БД (таблицы тестов пока не созданы)';
      }
      return fallback;
    }
  }
}
