import 'package:flutter/foundation.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/services/chat_api_contract.dart';
import 'package:dio/dio.dart';

class AiChatService {
  Future<String> send({
    required String message,
    List<Map<String, String>> history = const [],
  }) async {
    try {
      final res = await ApiClient.post('/api/ai/chat', data: {
        'message': message,
        'history': history,
      });

      final data = res.data;
      if (data is Map<String, dynamic>) {
        final reply = data['reply'];
        if (reply is String && reply.trim().isNotEmpty) {
          return reply;
        }
      }

      // Fallback to ChatApiContract parsing for envelope format
      if (data is String) {
        return ChatApiContract.parseMessageFromBody(data);
      }

      throw const ApiException(
        'AI вернул пустой ответ',
        code: 'EMPTY_RESPONSE',
      );
    } on DioException catch (e) {
      debugPrint('[AiChatService] error: ${e.message}');
      if (e.response?.statusCode == 429) {
        throw const ApiException(
          'Слишком много запросов. Подождите минуту.',
          code: 'RATE_LIMIT',
        );
      }
      throw const ApiException(
        'AI временно недоступен',
        code: 'NETWORK_ERROR',
      );
    }
  }
}
