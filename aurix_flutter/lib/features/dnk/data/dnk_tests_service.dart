import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:aurix_flutter/core/api/api_client.dart' show ApiClient, asList;
import 'dnk_tests_models.dart';

class DnkTestsService {
  static const Duration _shortTimeout = Duration(seconds: 15);
  static const Duration _finishTimeout = Duration(seconds: 120);

  Future<List<DnkTestCatalogItem>> getCatalog() async {
    final res = await ApiClient.get('/api/ai/dnk-tests/catalog');
    final data = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    final list = (data['tests'] is List) ? data['tests'] as List : const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(DnkTestCatalogItem.fromJson)
        .toList();
  }

  Future<DnkTestStartResponse> startSession({
    required String userId,
    required String testSlug,
  }) async {
    final res = await ApiClient.post('/api/ai/dnk-tests/start', data: {
      'test_slug': testSlug,
    });
    final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    return DnkTestStartResponse.fromJson(body);
  }

  Future<DnkTestFollowupResponse> submitAnswer({
    required String sessionId,
    required String questionId,
    required String answerType,
    required Map<String, dynamic> answerJson,
  }) async {
    final res = await ApiClient.post('/api/ai/dnk-tests/answer', data: {
      'session_id': sessionId,
      'question_id': questionId,
      'answer_type': answerType,
      'answer_json': answerJson,
    });
    final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    return DnkTestFollowupResponse.fromJson(body);
  }

  Future<DnkTestResult> finishAndWait(String sessionId) async {
    final res = await ApiClient.post('/api/ai/dnk-tests/finish', data: {
      'session_id': sessionId,
    });
    final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    if (body['status'] == 'ready') {
      return DnkTestResult.fromJson(body);
    }
    throw Exception(body['error']?.toString() ?? 'DNK tests: ошибка генерации');
  }

  Future<DnkTestResult?> getLatestResultBySession(String sessionId) async {
    try {
      final res = await ApiClient.get('/api/ai/dnk-tests/result', query: {
        'session_id': sessionId,
      });
      final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      if (body['status'] != 'ready') return null;
      return DnkTestResult.fromJson(body);
    } catch (_) {
      return null;
    }
  }

  Future<DnkTestResult?> getResultById(String resultId) async {
    try {
      final res = await ApiClient.get('/api/ai/dnk-tests/result', query: {
        'result_id': resultId,
      });
      final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      if (body['status'] != 'ready') return null;
      return DnkTestResult.fromJson(body);
    } catch (_) {
      return null;
    }
  }

  Future<List<DnkTestProgressItem>> getProgress(String userId) async {
    try {
      final res = await ApiClient.get('/api/ai/dnk-tests/progress');
      final data = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      final list = (data['progress'] is List) ? data['progress'] as List : const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(DnkTestProgressItem.fromJson)
          .where((x) => x.testSlug.isNotEmpty && x.completed)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
