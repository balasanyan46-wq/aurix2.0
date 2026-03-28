import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'dnk_models.dart';

class DnkService {
  /// Collected answers during the interview (stored locally, no session needed).
  final List<DnkAnswerPayload> _answers = [];

  /// Add an answer to the local collection.
  void addAnswer({
    required String questionId,
    required String answerType,
    required Map<String, dynamic> answerJson,
  }) {
    // Replace if already answered (e.g. going back)
    _answers.removeWhere((a) => a.questionId == questionId);
    _answers.add(DnkAnswerPayload(
      questionId: questionId,
      answerType: answerType,
      answerJson: answerJson,
    ));
    if (kDebugMode) {
      debugPrint('[DNK] answer added: $questionId (${_answers.length} total)');
    }
  }

  int get answerCount => _answers.length;

  /// Send all collected answers to NestJS backend and get the full DNK result.
  /// POST /api/ai/dnk
  Future<DnkResult> finish({String styleLevel = 'normal'}) async {
    if (_answers.length < 10) {
      throw Exception('DNK: слишком мало ответов (${_answers.length})');
    }

    if (kDebugMode) {
      debugPrint('[DNK] finishing with ${_answers.length} answers, style=$styleLevel');
    }

    final answersList = _answers.map((a) => <String, dynamic>{
      'question_id': a.questionId,
      'answer_type': a.answerType,
      'answer_json': a.answerJson,
    }).toList();

    final payload = <String, dynamic>{
      'answers': answersList,
      'style_level': styleLevel,
    };

    final res = await ApiClient.post('/api/ai/dnk', data: payload);

    if (res.statusCode != null && res.statusCode! >= 400) {
      final msg = res.data is Map ? (res.data['message'] ?? 'Ошибка сервера') : 'Ошибка сервера';
      throw Exception('DNK: $msg');
    }

    final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};

    if (body['status'] == 'ready') {
      return DnkResult.fromJson(body);
    }

    throw Exception(body['error']?.toString() ?? 'DNK: генерация не удалась');
  }

  /// Clear collected answers (for starting over).
  void reset() {
    _answers.clear();
  }
}

class DnkAnswerPayload {
  final String questionId;
  final String answerType;
  final Map<String, dynamic> answerJson;

  const DnkAnswerPayload({
    required this.questionId,
    required this.answerType,
    required this.answerJson,
  });
}
