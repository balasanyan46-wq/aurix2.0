import 'package:flutter/foundation.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/data/models/track_model.dart';

class TrackRepository {
  /// Get all tracks for the current user with release metadata.
  Future<List<Map<String, dynamic>>> getMyTracks() async {
    final res = await ApiClient.get('/tracks/my');
    final body = _asMap(res.data);
    final list = (body['tracks'] as List?) ?? [];
    return list.map((e) => _asMap(e)).toList();
  }

  Future<List<TrackModel>> getTracksByRelease(String releaseId) async {
    final res = await ApiClient.get('/tracks/release/$releaseId');
    final body = _asMap(res.data);
    final list = (body['tracks'] as List?) ?? [];
    return list.map((e) => TrackModel.fromJson(_asMap(e))).toList();
  }

  Future<TrackModel> addTrack({
    String? id,
    required String releaseId,
    String? userId,
    required String audioPath,
    required String audioUrl,
    String? title,
    String? isrc,
    int trackNumber = 0,
    String version = 'original',
    bool explicit = false,
  }) async {
    final data = <String, dynamic>{
      'release_id': releaseId,
      'audio_path': audioPath,
      'audio_url': audioUrl,
    };
    if (title != null) data['title'] = title;
    if (isrc != null && isrc.trim().isNotEmpty) data['isrc'] = isrc.trim().toUpperCase();
    if (trackNumber > 0) data['track_number'] = trackNumber;
    if (version != 'original') data['version'] = version;
    if (explicit) data['explicit'] = explicit;
    if (id != null) data['id'] = id;

    final res = await ApiClient.post('/tracks/', data: data);
    final body = _asMap(res.data);
    final trackData = body['track'] ?? body;
    return TrackModel.fromJson(_asMap(trackData));
  }

  Future<void> updateTrackIsrc(String trackId, String? isrc) async {
    await ApiClient.put('/tracks/$trackId', data: {
      'isrc': isrc?.trim().toUpperCase(),
    });
  }

  Future<void> deleteTrack(String id) async {
    await ApiClient.delete('/tracks/$id');
  }

  Future<TrackModel?> getTrack(String id) async {
    try {
      final res = await ApiClient.get('/tracks/$id');
      final body = _asMap(res.data);
      final trackData = body['track'];
      if (trackData != null) {
        return TrackModel.fromJson(_asMap(trackData));
      }
      return null;
    } catch (e) {
      debugPrint('[TrackRepository] getTrack($id) failed: $e');
      return null;
    }
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }
}
