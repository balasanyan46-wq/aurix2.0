import 'package:flutter/foundation.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/data/models/track_model.dart';

class TrackRepository {
  Future<List<TrackModel>> getTracksByRelease(String releaseId) async {
    final res = await ApiClient.get('/tracks/release/$releaseId');
    final body = res.data as Map<String, dynamic>;
    final list = body['tracks'] as List? ?? [];
    return list.map((e) => TrackModel.fromJson(e as Map<String, dynamic>)).toList();
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
    if (version != 'original') data['version'] = version;
    if (explicit) data['explicit'] = explicit;
    if (id != null) data['id'] = id;

    final res = await ApiClient.post('/tracks', data: data);
    final body = res.data as Map<String, dynamic>;
    return TrackModel.fromJson(body['track'] as Map<String, dynamic>);
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
      final body = res.data as Map<String, dynamic>;
      if (body['track'] != null) {
        return TrackModel.fromJson(body['track'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('[TrackRepository] getTrack($id) failed: $e');
      return null;
    }
  }
}
