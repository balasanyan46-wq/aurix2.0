import 'package:aurix_flutter/core/api/api_client.dart' show ApiClient, asList;
import 'package:aurix_flutter/data/models/release_aai_model.dart';

class ReleaseAaiRepository {
  bool _isMissingOrUnavailable(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('pgrst205') ||
        msg.contains('relation') ||
        msg.contains('not found') ||
        msg.contains('404') ||
        msg.contains('500') ||
        msg.contains('bad response');
  }

  Future<ReleaseAaiModel?> getReleaseAai(String releaseId) async {
    try {
      final res = await ApiClient.get('/release-attention-index', query: {
        'release_id': releaseId,
      });
      final list = res.data;
      Map<String, dynamic>? indexRes;
      if (list is List && list.isNotEmpty) {
        indexRes = list.first is Map ? Map<String, dynamic>.from(list.first as Map) : null;
      } else if (list is Map<String, dynamic>) {
        indexRes = list;
      }
      if (indexRes == null) return null;

      final trend = await _loadTrend(releaseId);
      final platforms = await _loadPlatformBuckets(releaseId);
      final countries = await _loadCountryBuckets(releaseId);

      return ReleaseAaiModel.fromIndexRow(
        indexRes,
        trend: trend,
        platforms: platforms,
        countries: countries,
      );
    } catch (e) {
      if (_isMissingOrUnavailable(e)) return null;
      rethrow;
    }
  }

  Future<List<DnkAaiHint>> getDnkAaiHints(String releaseId) async {
    try {
      final res = await ApiClient.get('/dnk-test-aai-links', query: {
        'release_id': releaseId,
        'select': 'test_slug,expected_growth_channel,notes,created_at',
        'order': 'created_at.desc',
        'limit': '3',
      });
      final list = asList(res.data);
      return list
          .cast<Map<String, dynamic>>()
          .map(
            (row) => DnkAaiHint(
              testSlug: (row['test_slug'] ?? '').toString(),
              expectedGrowthChannel: (row['expected_growth_channel'] ?? '').toString(),
              notes: (row['notes'] ?? '').toString(),
            ),
          )
          .toList();
    } catch (e) {
      if (_isMissingOrUnavailable(e)) return const [];
      rethrow;
    }
  }

  Future<List<ReleaseAaiPoint>> _loadTrend(String releaseId) async {
    final since = DateTime.now().subtract(const Duration(days: 6)).toIso8601String();
    final res = await ApiClient.get('/release-clicks', query: {
      'release_id': releaseId,
      'created_at_gte': since,
      'select': 'created_at,is_filtered',
      'order': 'created_at.asc',
    });
    final clicksRes = asList(res.data);
    final points = <DateTime, int>{};
    for (final row in clicksRes.cast<Map<String, dynamic>>()) {
      if (row['is_filtered'] == true) continue;
      final dt = DateTime.tryParse(row['created_at'] as String);
      if (dt == null) continue;
      final day = DateTime(dt.year, dt.month, dt.day);
      points[day] = (points[day] ?? 0) + 1;
    }
    final now = DateTime.now();
    return List.generate(7, (i) {
      final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i));
      return ReleaseAaiPoint(day: d, value: points[d] ?? 0);
    });
  }

  Future<List<ReleaseAaiBucket>> _loadPlatformBuckets(String releaseId) async {
    final since = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    final res = await ApiClient.get('/release-clicks', query: {
      'release_id': releaseId,
      'created_at_gte': since,
      'select': 'platform,is_filtered',
    });
    final list = asList(res.data);
    final map = <String, int>{};
    for (final row in list.cast<Map<String, dynamic>>()) {
      if (row['is_filtered'] == true) continue;
      final key = (row['platform'] as String?)?.trim();
      if (key == null || key.isEmpty) continue;
      map[key] = (map[key] ?? 0) + 1;
    }
    return map.entries
        .map((e) => ReleaseAaiBucket(key: e.key, count: e.value))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
  }

  Future<List<ReleaseAaiBucket>> _loadCountryBuckets(String releaseId) async {
    final since = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    final res = await ApiClient.get('/release-page-views', query: {
      'release_id': releaseId,
      'created_at_gte': since,
      'select': 'country,is_filtered',
    });
    final list = asList(res.data);
    final map = <String, int>{};
    for (final row in list.cast<Map<String, dynamic>>()) {
      if (row['is_filtered'] == true) continue;
      final key = ((row['country'] as String?) ?? '').trim();
      if (key.isEmpty) continue;
      map[key] = (map[key] ?? 0) + 1;
    }
    return map.entries
        .map((e) => ReleaseAaiBucket(key: e.key, count: e.value))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
  }
}
