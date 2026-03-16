import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:aurix_flutter/config/app_config.dart';
import 'package:aurix_flutter/services/chat_api_contract.dart';

class AiChatService {
  static Uri get _endpoint {
    final base = AppConfig.cfBaseUrl.trimRight().replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$base/api/ai/chat');
  }

  Future<String> send({
    required String message,
    List<Map<String, String>> history = const [],
  }) async {
    ChatApiContract.runDevSmokeTestOnce();

    Future<http.Response> postOnce() {
      return http
          .post(
            _endpoint,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'message': message, 'history': history}),
          )
          .timeout(const Duration(seconds: 30));
    }

    http.Response res;
    try {
      res = await postOnce();
      if (res.statusCode >= 500 && res.statusCode <= 599) {
        res = await postOnce();
      }
    } on TimeoutException {
      try {
        res = await postOnce();
      } on TimeoutException {
        throw const ApiException(
          'AI временно недоступен',
          code: 'NETWORK_TIMEOUT',
        );
      }
    } catch (e) {
      debugPrint('[AiChatService] network error: $e');
      throw const ApiException(
        'AI временно недоступен',
        code: 'NETWORK_ERROR',
      );
    }

    if (res.statusCode != 200) {
      if (res.statusCode >= 400 && res.statusCode <= 499) {
        try {
          ChatApiContract.parseMessageFromBody(
            res.body,
            httpStatus: res.statusCode,
          );
        } on ApiException catch (e) {
          throw e;
        } catch (e) {
          debugPrint('[AiChatService] 4xx parse error: $e');
        }
      }
      throw ApiException(
        'AI временно недоступен',
        code: 'HTTP_${res.statusCode}',
        httpStatus: res.statusCode,
      );
    }

    try {
      return ChatApiContract.parseMessageFromBody(
        res.body,
        httpStatus: res.statusCode,
        logger: kDebugMode ? debugPrint : null,
      );
    } on ApiException catch (e) {
      throw e;
    } catch (e) {
      debugPrint('[AiChatService] response parse error: $e');
      throw const ApiException(
        'AI временно недоступен',
        code: 'PARSE_ERROR',
      );
    }
  }
}

