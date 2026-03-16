import 'dart:convert';

import 'package:flutter/foundation.dart';

class ApiException implements Exception {
  final String message;
  final String code;
  final String? requestId;
  final int? httpStatus;

  const ApiException(
    this.message, {
    required this.code,
    this.requestId,
    this.httpStatus,
  });

  @override
  String toString() =>
      'ApiException(code: $code, message: $message, requestId: $requestId, httpStatus: $httpStatus)';
}

class ChatApiContract {
  static bool _smokeTestDone = false;

  static void runDevSmokeTestOnce() {
    if (!kDebugMode || _smokeTestDone) return;
    _smokeTestDone = true;

    final legacy = parseMessageFromBody('{"reply":"legacy ok"}');
    final envelope = parseMessageFromBody(
      '{"status":"ok","version":"2","data":{"message":"envelope ok"},"meta":{"request_id":"dev-smoke"}}',
    );

    assert(legacy == 'legacy ok');
    assert(envelope == 'envelope ok');
  }

  static String parseMessageFromBody(
    String rawBody, {
    void Function(String line)? logger,
    int? httpStatus,
  }) {
    final dynamic decodedDynamic = jsonDecode(rawBody);
    if (decodedDynamic is! Map) {
      throw ApiException(
        'Unexpected response format',
        code: 'UNEXPECTED_RESPONSE',
        httpStatus: httpStatus,
      );
    }

    final decoded = Map<String, dynamic>.from(decodedDynamic);
    final requestId = _extractRequestId(decoded);
    if (requestId != null && requestId.isNotEmpty) {
      logger?.call('[ChatAPI] request_id=$requestId');
    }

    final legacyReply = decoded['reply'];
    if (legacyReply is String && legacyReply.trim().isNotEmpty) {
      return legacyReply;
    }

    final status = decoded['status']?.toString();
    if (status == 'ok') {
      final data = decoded['data'];
      if (data is Map) {
        final message = data['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
      }
      throw ApiException(
        'Unexpected response format',
        code: 'UNEXPECTED_RESPONSE',
        requestId: requestId,
        httpStatus: httpStatus,
      );
    }

    if (status == 'error') {
      final message = decoded['message']?.toString().trim();
      final code = decoded['code']?.toString().trim();
      throw ApiException(
        (message != null && message.isNotEmpty) ? message : 'AI request failed',
        code: (code != null && code.isNotEmpty) ? code : 'API_ERROR',
        requestId: requestId,
        httpStatus: httpStatus,
      );
    }

    throw ApiException(
      'Unexpected response format',
      code: 'UNEXPECTED_RESPONSE',
      requestId: requestId,
      httpStatus: httpStatus,
    );
  }

  static String? _extractRequestId(Map<String, dynamic> decoded) {
    final meta = decoded['meta'];
    if (meta is Map) {
      final requestId = meta['request_id']?.toString();
      if (requestId != null && requestId.isNotEmpty) return requestId;
    }
    return null;
  }
}

