import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:aurix_flutter/config/app_config.dart';

String _normalizeBaseUrl(String url) {
  final s = url.trim();
  return s.endsWith('/') ? s.substring(0, s.length - 1) : s;
}

Uri get _coverUri {
  final base = _normalizeBaseUrl(AppConfig.cfBaseUrl);
  return Uri.parse('$base/api/ai/cover');
}

class CoverAiServiceException implements Exception {
  final String message;
  CoverAiServiceException(this.message);
  @override
  String toString() => message;
}

class CoverAiService {
  static const _timeout = Duration(seconds: 180);

  static bool _shouldRetry(CoverAiServiceException e) {
    final m = e.message.toLowerCase();
    return m.contains('таймаут') ||
        m.contains('timeout') ||
        m.contains('service unavailable') ||
        m.contains('temporarily');
  }

  static Future<http.Response> _send(Uri uri, Map<String, dynamic> body) {
    return http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(body),
          encoding: utf8,
        )
        .timeout(_timeout);
  }

  static ({Uint8List bytes, Map<String, dynamic> meta}) _parseResponse(
    http.Response res,
  ) {
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
  }

  static Future<({Uint8List bytes, Map<String, dynamic> meta})> generate({
    required String prompt,
    bool strictPrompt = true,
    String? negativePrompt,
    double followPromptStrength = 0.9,
    bool safeZoneGuide = true,
    String? stylePreset,
    String? colorProfile,
    String size = '1024x1024',
    String quality = 'high',
    String outputFormat = 'png',
    String background = 'opaque',
    bool allowText = true,
    String? releaseId,
    String? userId,
  }) async {
    final uri = _coverUri;
    final body = <String, dynamic>{
      'prompt': prompt,
      'strict_prompt': strictPrompt,
      'negative_prompt': negativePrompt,
      'follow_prompt_strength': followPromptStrength,
      'safe_zone_guide': safeZoneGuide,
      'style_preset': stylePreset,
      'color_profile': colorProfile,
      'size': size,
      'quality': quality,
      'output_format': outputFormat,
      'background': background,
      'allow_text': allowText,
      'releaseId': releaseId,
      'userId': userId,
    };

    try {
      try {
        final res = await _send(uri, body);
        return _parseResponse(res);
      } on CoverAiServiceException catch (e) {
        if (!_shouldRetry(e)) rethrow;
        final retryRes = await _send(uri, body);
        return _parseResponse(retryRes);
      }
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

