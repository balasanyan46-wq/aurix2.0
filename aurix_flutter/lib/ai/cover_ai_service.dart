import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const _cfBaseUrl = String.fromEnvironment(
  'CF_BASE_URL',
  defaultValue: 'https://wandering-snow-3f00.armtelan1.workers.dev',
);

String _normalizeBaseUrl(String url) {
  final s = url.trim();
  return s.endsWith('/') ? s.substring(0, s.length - 1) : s;
}

Uri get _coverUri {
  final base = _normalizeBaseUrl(_cfBaseUrl);
  return Uri.parse('$base/api/ai/cover');
}

class CoverAiServiceException implements Exception {
  final String message;
  CoverAiServiceException(this.message);
  @override
  String toString() => message;
}

class CoverAiService {
  static const _timeout = Duration(seconds: 35);

  static Future<({Uint8List bytes, Map<String, dynamic> meta})> generate({
    required String prompt,
    String size = '1024x1024',
    String quality = 'high',
    String outputFormat = 'png',
    String background = 'opaque',
    String? releaseId,
    String? userId,
  }) async {
    final uri = _coverUri;
    final body = <String, dynamic>{
      'prompt': prompt,
      'size': size,
      'quality': quality,
      'output_format': outputFormat,
      'background': background,
      'releaseId': releaseId,
      'userId': userId,
    };

    try {
      final res = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(body),
            encoding: utf8,
          )
          .timeout(_timeout);

      final status = res.statusCode;
      final decoded = jsonDecode(res.body) as Map<String, dynamic>? ?? const {};

      if (status != 200) {
        final err = (decoded['error'] as String?) ?? 'Сервис недоступен (status $status)';
        throw CoverAiServiceException(err);
      }

      final ok = decoded['ok'] == true;
      if (!ok) {
        throw CoverAiServiceException((decoded['error'] as String?) ?? 'Ошибка генерации');
      }

      final b64 = decoded['b64_png'] as String?;
      if (b64 == null || b64.isEmpty) {
        throw CoverAiServiceException('Пустой результат');
      }
      final bytes = base64Decode(b64);
      final meta = (decoded['meta'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      return (bytes: bytes, meta: meta);
    } on TimeoutException {
      throw CoverAiServiceException('Таймаут, попробуйте ещё раз');
    } on FormatException {
      throw CoverAiServiceException('Некорректный ответ сервера');
    } catch (e) {
      if (e is CoverAiServiceException) rethrow;
      if (kDebugMode) debugPrint('[CoverAiService] error: $e');
      throw CoverAiServiceException('Ошибка: $e');
    }
  }
}

