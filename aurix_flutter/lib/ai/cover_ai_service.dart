import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:aurix_flutter/core/api/api_client.dart';

class CoverAiServiceException implements Exception {
  final String message;
  CoverAiServiceException(this.message);
  @override
  String toString() => message;
}

class CoverAiService {
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
      final resp = await ApiClient.post(
        '/api/ai/cover',
        data: body,
        receiveTimeout: const Duration(minutes: 3),
      );

      final data = resp.data is Map ? Map<String, dynamic>.from(resp.data as Map) : <String, dynamic>{};

      final ok = data['ok'] == true;
      if (!ok) {
        throw CoverAiServiceException(
          (data['error'] as String?) ?? 'Ошибка генерации',
        );
      }

      final b64 = data['b64_png'] as String?;
      if (b64 == null || b64.isEmpty) {
        throw CoverAiServiceException('Пустой результат');
      }

      final bytes = base64Decode(b64);
      final meta = (data['meta'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      return (bytes: bytes, meta: meta);
    } on CoverAiServiceException {
      rethrow;
    } on TimeoutException {
      throw CoverAiServiceException('Таймаут, попробуйте ещё раз');
    } catch (e) {
      if (kDebugMode) debugPrint('[CoverAiService] error: $e');
      // Handle 402 NO_CREDITS
      final msg = e.toString();
      if (msg.contains('402') || msg.contains('NO_CREDITS')) {
        throw CoverAiServiceException('Недостаточно кредитов для генерации обложки. Пополните баланс.');
      }
      throw CoverAiServiceException('Ошибка: $e');
    }
  }
}
