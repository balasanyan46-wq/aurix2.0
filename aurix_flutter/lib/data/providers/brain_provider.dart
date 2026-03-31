import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/api/api_client.dart';

final brainProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final res = await ApiClient.get('/brain/profile');
  return res.data is Map ? Map<String, dynamic>.from(res.data as Map) : {};
});

final brainStrategyProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final res = await ApiClient.get('/brain/strategy');
  return res.data is Map ? Map<String, dynamic>.from(res.data as Map) : {};
});
