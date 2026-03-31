import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/api/api_client.dart';

class AppNotification {
  final int id;
  final String title;
  final String message;
  final String type; // system, promo, warning, success, ai
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic> meta;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.meta = const {},
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
    title: json['title']?.toString() ?? '',
    message: json['message']?.toString() ?? '',
    type: json['type']?.toString() ?? 'system',
    isRead: json['is_read'] == true,
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    meta: json['meta'] is Map ? Map<String, dynamic>.from(json['meta'] as Map) : {},
  );
}

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  try {
    final res = await ApiClient.get('/notifications/my', query: {'limit': '20'});
    final list = res.data is List ? (res.data as List) : [];
    return list
        .map((e) => AppNotification.fromJson(e is Map ? Map<String, dynamic>.from(e as Map) : {}))
        .toList();
  } catch (_) {
    return [];
  }
});

final unreadCountProvider = FutureProvider<int>((ref) async {
  try {
    final res = await ApiClient.get('/notifications/unread-count');
    final data = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : {};
    return data['count'] as int? ?? 0;
  } catch (_) {
    return 0;
  }
});

Future<void> markNotificationsRead({int? notificationId}) async {
  try {
    await ApiClient.post('/notifications/mark-read', data: {
      if (notificationId != null) 'notification_id': notificationId,
    });
  } catch (_) {}
}
