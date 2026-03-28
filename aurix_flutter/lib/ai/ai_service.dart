import 'package:flutter/foundation.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/services/chat_api_contract.dart';
import 'package:dio/dio.dart';

import 'ai_message.dart';

/// Context modes for AI personalization.
enum AiContextMode { full, noDnk, clean }

/// AI chat service — sends requests to NestJS backend with JWT auth.
class AiService {
  static Future<String> send({
    required String message,
    required List<AiMessage> history,
    String mode = 'panel',
    String? page,
    Map<String, dynamic>? context,
    String locale = 'ru',
    AiContextMode contextMode = AiContextMode.full,
    String? trackId,
  }) async {
    final body = <String, dynamic>{
      'message': message,
      'locale': locale,
      'mode': mode,
      'context_mode': _contextModeToString(contextMode),
      'history': history
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .map((m) => {'role': m.role, 'content': m.content})
          .toList(),
    };
    if (page != null) body['page'] = page;
    if (context != null && context.isNotEmpty) body['context'] = context;
    if (trackId != null) body['track_id'] = trackId;

    if (kDebugMode) {
      debugPrint('[AiService] POST /api/ai/chat (mode=$mode, ctx=${body['context_mode']})');
    }

    try {
      final res = await ApiClient.post('/api/ai/chat', data: body);

      final data = res.data;
      if (data is Map<String, dynamic>) {
        final reply = data['reply'];
        if (reply is String && reply.trim().isNotEmpty) {
          return reply;
        }
      }

      if (data is String) {
        return ChatApiContract.parseMessageFromBody(data);
      }

      throw AiServiceException('AI вернул пустой ответ');
    } on DioException catch (e) {
      debugPrint('[AiService] error: ${e.message}');
      if (e.response?.statusCode == 402) {
        final data = e.response?.data;
        final balance = data is Map ? data['balance'] ?? 0 : 0;
        final cost = data is Map ? data['cost'] ?? 0 : 0;
        throw AiServiceException(
          'Недостаточно кредитов. Баланс: $balance, нужно: $cost',
          code: 'NO_CREDITS',
        );
      }
      if (e.response?.statusCode == 429) {
        throw AiServiceException('Слишком много запросов. Подождите минуту.');
      }
      throw AiServiceException('AI временно недоступен');
    }
  }

  static String _contextModeToString(AiContextMode mode) {
    switch (mode) {
      case AiContextMode.full:
        return 'full';
      case AiContextMode.noDnk:
        return 'no_dnk';
      case AiContextMode.clean:
        return 'clean';
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
