import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'ai_message.dart';

const _cfBaseUrl = String.fromEnvironment(
  'CF_BASE_URL',
  defaultValue: 'https://wandering-snow-3f00.armtelan1.workers.dev',
);

/// Убирает trailing slash, чтобы не было двойных слэшей.
String _normalizeBaseUrl(String url) {
  final s = url.trim();
  if (s.endsWith('/')) {
    return s.substring(0, s.length - 1);
  }
  return s;
}

Uri get _chatUri {
  final base = _normalizeBaseUrl(_cfBaseUrl);
  return Uri.parse('$base/api/ai/chat');
}

/// AI chat service — POST to Cloudflare Worker.
class AiService {
  static const _timeout = Duration(seconds: 20);

  /// Send message and get AI reply.
  /// Returns reply string or throws AiServiceException on error.
  /// [mode] — "panel" (helper by app UI) or "studio" (creative tools).
  static Future<String> send({
    required String message,
    required List<AiMessage> history,
    String mode = 'panel',
    String? page,
    Map<String, dynamic>? context,
    String locale = 'ru',
  }) async {
    final uri = _chatUri;
    final body = <String, dynamic>{
      'message': message,
      'locale': locale,
      'mode': mode,
      'history': history
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .map((m) => {'role': m.role, 'content': m.content})
          .toList(),
    };
    if (page != null) body['page'] = page;
    if (context != null && context.isNotEmpty) body['context'] = context;

    final bodyJson = jsonEncode(body);
    final headers = {
      'Content-Type': 'application/json; charset=utf-8',
    };

    if (kDebugMode) {
      debugPrint('[AiService] POST $uri');
      debugPrint('[AiService] body: $bodyJson');
    }

    try {
      final response = await http
          .post(
            uri,
            headers: headers,
            body: bodyJson,
            encoding: utf8,
          )
          .timeout(_timeout);

      if (kDebugMode) {
        debugPrint('[AiService] status: ${response.statusCode}');
        debugPrint('[AiService] response: ${response.body}');
      }

      if (response.statusCode == 429) {
        throw AiServiceException('Слишком много запросов. Подождите минуту.');
      }

      if (response.statusCode != 200) {
        String err = 'Сервис недоступен (status ${response.statusCode})';
        try {
          final j = jsonDecode(response.body) as Map<String, dynamic>?;
          if (j != null && j['error'] != null) {
            err = j['error'] as String;
          }
        } catch (_) {}
        throw AiServiceException(err);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      final reply = data?['reply'] as String?;
      if (reply == null || reply.isEmpty) {
        throw AiServiceException('Пустой ответ');
      }
      return reply;
    } on TimeoutException {
      if (kDebugMode) debugPrint('[AiService] TimeoutException');
      throw AiServiceException('Таймаут, попробуйте ещё раз');
    } on http.ClientException catch (e) {
      if (kDebugMode) debugPrint('[AiService] ClientException: $e');
      final msg = e.message.toLowerCase();
      if (msg.contains('failed to fetch') ||
          msg.contains('cors') ||
          msg.contains('xmlhttprequest') ||
          msg.contains('network')) {
        throw AiServiceException(
            'Сеть/браузер блокирует запрос (CORS/Failed to fetch)');
      }
      throw AiServiceException('Ошибка сети: ${e.message}');
    } on AiServiceException {
      rethrow;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[AiService] Exception: $e');
        debugPrint('[AiService] stack: $st');
      }
      throw AiServiceException('Ошибка: $e');
    }
  }
}

class AiServiceException implements Exception {
  final String message;
  AiServiceException(this.message);
  @override
  String toString() => message;
}
