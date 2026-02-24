import 'package:flutter/foundation.dart';

import 'package:aurix_flutter/core/supabase_diagnostics.dart';
import 'package:aurix_flutter/data/supabase_client.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/models/admin_note_model.dart';

class ReleaseRepository {
  Future<List<ReleaseModel>> getReleasesByOwner(String ownerId) async {
    logSupabaseRequest(table: 'releases', operation: 'select', userId: ownerId);
    final res = await supabase.from('releases').select().eq('owner_id', ownerId).order('created_at', ascending: false);
    return (res as List).map((e) => ReleaseModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ReleaseModel>> getAllReleases() async {
    logSupabaseRequest(table: 'releases', operation: 'select');
    final res = await supabase.from('releases').select().order('created_at', ascending: false);
    return (res as List).map((e) => ReleaseModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ReleaseModel?> getRelease(String id) async {
    logSupabaseRequest(table: 'releases', operation: 'select', payload: {'id': id});
    final res = await supabase.from('releases').select().eq('id', id).maybeSingle();
    if (res == null) return null;
    return ReleaseModel.fromJson(res as Map<String, dynamic>);
  }

  Future<ReleaseModel> createRelease({
    required String ownerId,
    required String title,
    required String artist,
    required String releaseType,
    DateTime? releaseDate,
    String? genre,
    String? language,
    bool explicit = false,
    String? coverUrl,
    String? coverPath,
  }) async {
    final payload = <String, dynamic>{
      'owner_id': ownerId,
      'title': title,
      'artist': artist.isEmpty ? 'Unknown Artist' : artist,
      'release_type': releaseType,
      'status': 'draft',
      'explicit': explicit,
    };
    if (releaseDate != null) payload['release_date'] = releaseDate.toIso8601String().split('T').first;
    if (genre != null) payload['genre'] = genre;
    if (language != null) payload['language'] = language;
    if (coverUrl != null) payload['cover_url'] = coverUrl;
    if (coverPath != null) payload['cover_path'] = coverPath;

    logSupabaseRequest(table: 'releases', operation: 'insert', payload: payload, userId: ownerId);
    try {
      final res = await supabase.from('releases').insert(payload).select().single();
      return ReleaseModel.fromJson(res as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[ReleaseRepository] createRelease error: ${formatSupabaseError(e)}');
      rethrow;
    }
  }

  Future<void> updateRelease(
    String id, {
    String? title,
    String? artist,
    String? releaseType,
    DateTime? releaseDate,
    String? genre,
    String? language,
    String? status,
    String? coverUrl,
    String? coverPath,
  }) async {
    final updates = <String, dynamic>{'updated_at': DateTime.now().toIso8601String()};
    if (title != null) updates['title'] = title;
    if (artist != null) updates['artist'] = artist;
    if (releaseType != null) updates['release_type'] = releaseType;
    if (releaseDate != null) updates['release_date'] = releaseDate.toIso8601String().split('T').first;
    if (genre != null) updates['genre'] = genre;
    if (language != null) updates['language'] = language;
    if (status != null) updates['status'] = status;
    if (coverUrl != null) updates['cover_url'] = coverUrl;
    if (coverPath != null) updates['cover_path'] = coverPath;
    logSupabaseRequest(table: 'releases', operation: 'update', payload: updates, userId: supabase.auth.currentUser?.id);
    try {
      await supabase.from('releases').update(updates).eq('id', id);
    } catch (e) {
      debugPrint('[ReleaseRepository] updateRelease error: ${formatSupabaseError(e)}');
      rethrow;
    }
  }

  Future<void> submitRelease(String id) async {
    await updateRelease(id, status: 'submitted');
  }

  Future<List<AdminNoteModel>> getNotesForRelease(String releaseId) async {
    final res = await supabase.from('admin_notes').select().eq('release_id', releaseId).order('created_at', ascending: false);
    return (res as List).map((e) => AdminNoteModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> addAdminNote({required String releaseId, required String adminId, required String note}) async {
    await supabase.from('admin_notes').insert({
      'release_id': releaseId,
      'admin_id': adminId,
      'note': note,
    });
  }

  /// Полное удаление релиза: Storage (обложка + треки) → tracks → admin_notes → releases
  Future<void> deleteReleaseFully(String releaseId) async {
    logSupabaseRequest(table: 'releases', operation: 'delete_full', payload: {'id': releaseId});

    final release = await getRelease(releaseId);
    if (release == null) return;

    // 1. Получить все треки
    final tracksRes = await supabase.from('tracks').select().eq('release_id', releaseId);
    final tracks = (tracksRes as List).cast<Map<String, dynamic>>();

    // 2. Удалить аудиофайлы из Storage
    final trackPaths = tracks
        .map((t) => t['audio_path'] as String?)
        .where((p) => p != null && p.isNotEmpty)
        .cast<String>()
        .toList();
    if (trackPaths.isNotEmpty) {
      try {
        await supabase.storage.from('tracks').remove(trackPaths);
      } catch (e) {
        debugPrint('[ReleaseRepository] delete track files error: $e');
      }
    }

    // 3. Удалить обложку из Storage
    if (release.coverPath != null && release.coverPath!.isNotEmpty) {
      try {
        await supabase.storage.from('covers').remove([release.coverPath!]);
      } catch (e) {
        debugPrint('[ReleaseRepository] delete cover error: $e');
      }
    }

    // 4. Удалить записи треков из БД
    try {
      await supabase.from('tracks').delete().eq('release_id', releaseId);
    } catch (e) {
      debugPrint('[ReleaseRepository] delete tracks rows error: $e');
    }

    // 5. Удалить заметки админа
    try {
      await supabase.from('admin_notes').delete().eq('release_id', releaseId);
    } catch (e) {
      debugPrint('[ReleaseRepository] delete admin_notes error: $e');
    }

    // 6. Удалить сам релиз
    await supabase.from('releases').delete().eq('id', releaseId);
  }
}
