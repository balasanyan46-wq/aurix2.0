import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:aurix_flutter/services/chat_api_contract.dart';

import 'package:aurix_flutter/config/app_config.dart';

import 'ai_message.dart';

/// Убирает trailing slash, чтобы не было двойных слэшей.
String _normalizeBaseUrl(String url) {
  final s = url.trim();
  if (s.endsWith('/')) {
    return s.substring(0, s.length - 1);
  }
  return s;
}

Uri get _chatUri {
  final base = _normalizeBaseUrl(AppConfig.cfBaseUrl);
  return Uri.parse('$base/api/ai/chat');
}

/// AI chat service — POST to Cloudflare Worker.
class AiService {
  static const _timeout = Duration(seconds: 20);

  static Future<http.Response> _postOnce(
    Uri uri, {
    required Map<String, String> headers,
    required String bodyJson,
  }) {
    return http
        .post(
          uri,
          headers: headers,
          body: bodyJson,
          encoding: utf8,
        )
        .timeout(_timeout);
  }

  static Future<http.Response> _postWithRetry(
    Uri uri, {
    required Map<String, String> headers,
    required String bodyJson,
  }) async {
    try {
      final first = await _postOnce(uri, headers: headers, bodyJson: bodyJson);
      if (first.statusCode >= 500 && first.statusCode <= 599) {
        if (kDebugMode) {
          debugPrint('[AiService] retry_on_5xx status=${first.statusCode}');
        }
        return await _postOnce(uri, headers: headers, bodyJson: bodyJson);
      }
      return first;
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('[AiService] retry_on_timeout');
      }
      return await _postOnce(uri, headers: headers, bodyJson: bodyJson);
    }
  }

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
    ChatApiContract.runDevSmokeTestOnce();
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
      final response = await _postWithRetry(
        uri,
        headers: headers,
        bodyJson: bodyJson,
      );

      if (kDebugMode) {
        debugPrint('[AiService] status: ${response.statusCode}');
        debugPrint('[AiService] response: ${response.body}');
      }

      if (response.statusCode == 429) {
        throw AiServiceException('Слишком много запросов. Подождите минуту.');
      }

      if (response.statusCode != 200) {
        try {
          ChatApiContract.parseMessageFromBody(
            response.body,
            httpStatus: response.statusCode,
            logger: kDebugMode ? debugPrint : null,
          );
        } on ApiException catch (e) {
          throw AiServiceException.fromApi(e);
        } catch (e) {
          debugPrint('[AiService] error parsing non-200 response: $e');
        }
        throw AiServiceException('Сервис недоступен (status ${response.statusCode})');
      }

      try {
        return ChatApiContract.parseMessageFromBody(
          response.body,
          httpStatus: response.statusCode,
          logger: kDebugMode ? debugPrint : null,
        );
      } on ApiException catch (e) {
        throw AiServiceException.fromApi(e);
      }
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
  final String code;
  final String? requestId;

  AiServiceException(
    this.message, {
    this.code = 'AI_ERROR',
    this.requestId,
  });

  factory AiServiceException.fromApi(ApiException e) {
    return AiServiceException(
      e.message,
      code: e.code,
      requestId: e.requestId,
    );
  }

  @override
  String toString() => message;
}
