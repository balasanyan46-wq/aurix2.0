import 'package:aurix_flutter/core/api/api_client.dart';

class EventTracker {
  static Future<void> track(
    String event, {
    String? targetType,
    String? targetId,
    Map<String, dynamic>? meta,
  }) async {
    try {
      await ApiClient.post('/user-events', data: {
        'event': event,
        if (targetType != null) 'target_type': targetType,
        if (targetId != null) 'target_id': targetId,
        if (meta != null) 'meta': meta,
      });
    } catch (_) {
      // Fire and forget
    }
  }
}
