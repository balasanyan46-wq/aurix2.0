import 'package:flutter/foundation.dart';

import 'package:aurix_flutter/core/supabase_diagnostics.dart';
import 'package:aurix_flutter/data/supabase_client.dart';
import 'package:aurix_flutter/data/models/track_model.dart';

class TrackRepository {
  Future<List<TrackModel>> getTracksByRelease(String releaseId) async {
    logSupabaseRequest(table: 'tracks', operation: 'select', payload: {'release_id': releaseId});
    final res = await supabase
        .from('tracks')
        .select()
        .eq('release_id', releaseId)
        .order('track_number', ascending: true);
    return (res as List).map((e) => TrackModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TrackModel> addTrack({
    String? id,
    required String releaseId,
    required String audioPath,
    required String audioUrl,
    String? title,
    int trackNumber = 0,
    String version = 'original',
    bool explicit = false,
  }) async {
    final data = <String, dynamic>{
      'release_id': releaseId,
      'path': audioPath,
      'file_url': audioUrl,
      'audio_path': audioPath,
      'audio_url': audioUrl,
      'title': title,
      'track_number': trackNumber,
      'version': version,
      'explicit': explicit,
    };
    if (id != null) data['id'] = id;
    logSupabaseRequest(table: 'tracks', operation: 'insert', payload: data, userId: supabase.auth.currentUser?.id);
    try {
      final res = await supabase.from('tracks').insert(data).select().single();
      return TrackModel.fromJson(res as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[TrackRepository] addTrack error: ${formatSupabaseError(e)}');
      rethrow;
    }
  }

  Future<void> deleteTrack(String id) async {
    await supabase.from('tracks').delete().eq('id', id);
  }

  Future<TrackModel?> getTrack(String id) async {
    final res = await supabase.from('tracks').select().eq('id', id).maybeSingle();
    if (res == null) return null;
    return TrackModel.fromJson(res as Map<String, dynamic>);
  }
}
