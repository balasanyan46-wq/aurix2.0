import 'package:flutter/foundation.dart';
import 'package:aurix_flutter/core/api/api_client.dart' show ApiClient;
import 'package:aurix_flutter/data/models/beat_model.dart';

Map<String, dynamic> _asMap(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  return <String, dynamic>{};
}

class BeatRepository {
  /// Fetch beats catalog with optional filters.
  Future<List<BeatModel>> getBeats({
    String? genre,
    String? mood,
    int? bpmMin,
    int? bpmMax,
    String? search,
    int limit = 20,
    int offset = 0,
  }) async {
    final query = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (genre != null && genre.isNotEmpty) query['genre'] = genre;
    if (mood != null && mood.isNotEmpty) query['mood'] = mood;
    if (bpmMin != null) query['bpm_min'] = bpmMin;
    if (bpmMax != null) query['bpm_max'] = bpmMax;
    if (search != null && search.isNotEmpty) query['search'] = search;

    final res = await ApiClient.get('/beats', query: query);
    final body = _asMap(res.data);
    final list = (body['beats'] as List?) ?? [];
    return list.map((e) => BeatModel.fromJson(_asMap(e))).toList();
  }

  /// Fetch single beat by ID.
  Future<BeatModel?> getBeat(int id) async {
    try {
      final res = await ApiClient.get('/beats/$id');
      final body = _asMap(res.data);
      final beat = body['beat'];
      if (beat != null) return BeatModel.fromJson(_asMap(beat));
      return null;
    } catch (e) {
      debugPrint('[BeatRepository] getBeat($id) failed: $e');
      return null;
    }
  }

  /// Get current user's beats.
  Future<List<BeatModel>> getMyBeats() async {
    final res = await ApiClient.get('/beats/my/list');
    final body = _asMap(res.data);
    final list = (body['beats'] as List?) ?? [];
    return list.map((e) => BeatModel.fromJson(_asMap(e))).toList();
  }

  /// Create a new beat.
  Future<BeatModel> createBeat(Map<String, dynamic> data) async {
    final res = await ApiClient.post('/beats', data: data);
    final body = _asMap(res.data);
    return BeatModel.fromJson(_asMap(body['beat'] ?? body));
  }

  /// Update a beat.
  Future<void> updateBeat(int id, Map<String, dynamic> data) async {
    await ApiClient.put('/beats/$id', data: data);
  }

  /// Delete a beat.
  Future<void> deleteBeat(int id) async {
    await ApiClient.delete('/beats/$id');
  }

  /// Toggle like on a beat.
  Future<bool> toggleLike(int beatId) async {
    final res = await ApiClient.post('/beats/$beatId/like');
    final body = _asMap(res.data);
    return body['liked'] == true;
  }

  /// Record a play.
  Future<void> recordPlay(int beatId) async {
    await ApiClient.post('/beats/$beatId/play');
  }

  /// Purchase a beat with a specific license.
  Future<Map<String, dynamic>> purchaseBeat(int beatId, String licenseType) async {
    final res = await ApiClient.post('/beats/$beatId/purchase', data: {
      'license_type': licenseType,
    });
    return _asMap(res.data);
  }
}
