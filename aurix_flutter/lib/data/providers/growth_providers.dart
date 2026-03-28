import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/api/api_client.dart';

/// Full growth state: xp, streak, goals, achievements.
final growthStateProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final res = await ApiClient.get('/growth/me');
    return res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
  } catch (_) {
    return {};
  }
});

/// XP state only.
final xpStateProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final res = await ApiClient.get('/growth/xp');
    return res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
  } catch (_) {
    return {};
  }
});

/// User's streak.
final streakProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final res = await ApiClient.get('/growth/streak');
    return res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
  } catch (_) {
    return {};
  }
});

/// User's goals.
final goalsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiClient.get('/growth/goals');
    return (res.data as List?)?.cast<Map<String, dynamic>>() ?? [];
  } catch (_) {
    return [];
  }
});

/// All achievements with user unlock status.
final achievementsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiClient.get('/growth/achievements');
    return (res.data as List?)?.cast<Map<String, dynamic>>() ?? [];
  } catch (_) {
    return [];
  }
});

/// Level configs.
final levelConfigsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiClient.get('/growth/levels');
    return (res.data as List?)?.cast<Map<String, dynamic>>() ?? [];
  } catch (_) {
    return [];
  }
});

/// XP log / history.
final xpLogProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiClient.get('/growth/xp-log');
    return (res.data as List?)?.cast<Map<String, dynamic>>() ?? [];
  } catch (_) {
    return [];
  }
});

/// User's public profile.
final myPublicProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final res = await ApiClient.get('/growth/public-profile');
    if (res.data == null || res.data == '') return null;
    return res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
  } catch (_) {
    return null;
  }
});
