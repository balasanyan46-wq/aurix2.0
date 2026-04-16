import 'package:flutter/foundation.dart';
import 'package:aurix_flutter/core/api/api_client.dart' show ApiClient, asList;
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/models/admin_note_model.dart';

class ReleaseRepository {
  Future<List<ReleaseModel>> getReleasesByOwner(String ownerId) async {
    final res = await ApiClient.get('/releases/my');
    final body = _asMap(res.data);
    final list = (body['releases'] as List?) ?? [];
    return list.map((e) => ReleaseModel.fromJson(_asMap(e))).toList();
  }

  Future<List<ReleaseModel>> getAllReleases() async {
    final res = await ApiClient.get('/releases/');
    final body = _asMap(res.data);
    final list = (body['releases'] as List?) ?? [];
    return list.map((e) => ReleaseModel.fromJson(_asMap(e))).toList();
  }

  Future<ReleaseModel?> getRelease(String id) async {
    try {
      final res = await ApiClient.get('/releases/$id');
      final body = _asMap(res.data);
      final release = body['release'];
      if (release != null) {
        return ReleaseModel.fromJson(_asMap(release));
      }
      return null;
    } catch (e) {
      debugPrint('[ReleaseRepository] getRelease($id) failed: $e');
      return null;
    }
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
    String? upc,
    String? label,
    int? copyrightYear,
    String? coverUrl,
    String? coverPath,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'artist': artist.isEmpty ? 'Unknown Artist' : artist,
      'release_type': releaseType,
      'status': 'draft',
      'explicit': explicit,
    };
    if (releaseDate != null) payload['release_date'] = releaseDate.toIso8601String().split('T').first;
    if (genre != null) payload['genre'] = genre;
    if (language != null) payload['language'] = language;
    if (upc != null && upc.isNotEmpty) payload['upc'] = upc;
    if (label != null && label.isNotEmpty) payload['label'] = label;
    if (copyrightYear != null) payload['copyright_year'] = copyrightYear;
    if (coverUrl != null) payload['cover_url'] = coverUrl;
    if (coverPath != null) payload['cover_path'] = coverPath;

    final res = await ApiClient.post('/releases/', data: payload);
    final body = _asMap(res.data);
    // Backend returns {success, release} — but handle both wrapped and unwrapped
    final releaseData = body['release'] ?? body;
    return ReleaseModel.fromJson(_asMap(releaseData));
  }

  /// Update release with any combination of fields.
  /// Pass a flat map of field_name → value for maximum flexibility.
  Future<void> updateRelease(String id, Map<String, dynamic> updates) async {
    if (updates.isNotEmpty) {
      await ApiClient.put('/releases/$id', data: updates);
    }
  }

  /// Legacy convenience wrapper for backward compatibility.
  Future<void> updateReleaseFields(
    String id, {
    String? title,
    String? artist,
    String? releaseType,
    DateTime? releaseDate,
    String? genre,
    String? language,
    bool? explicit,
    String? upc,
    String? label,
    int? copyrightYear,
    String? status,
    String? coverUrl,
    String? coverPath,
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (artist != null) updates['artist'] = artist;
    if (releaseType != null) updates['release_type'] = releaseType;
    if (releaseDate != null) updates['release_date'] = releaseDate.toIso8601String().split('T').first;
    if (genre != null) updates['genre'] = genre;
    if (language != null) updates['language'] = language;
    if (explicit != null) updates['explicit'] = explicit;
    if (upc != null) updates['upc'] = upc;
    if (label != null) updates['label'] = label;
    if (copyrightYear != null) updates['copyright_year'] = copyrightYear;
    if (status != null) updates['status'] = status;
    if (coverUrl != null) updates['cover_url'] = coverUrl;
    if (coverPath != null) updates['cover_path'] = coverPath;
    await updateRelease(id, updates);
  }

  Future<void> submitRelease(String id) async {
    await ApiClient.post('/releases/$id/submit');
  }

  Future<List<AdminNoteModel>> getNotesForRelease(String releaseId) async {
    try {
      final res = await ApiClient.get('/releases/$releaseId/notes');
      // Backend may return raw array or {notes: [...]}
      List list;
      if (res.data is List) {
        list = asList(res.data);
      } else {
        final body = _asMap(res.data);
        list = body['notes'] as List? ?? [];
      }
      return list.map((e) => AdminNoteModel.fromJson(_asMap(e))).toList();
    } catch (e) {
      debugPrint('[ReleaseRepository] getNotesForRelease failed: $e');
      return [];
    }
  }

  Future<void> addAdminNote({required String releaseId, required String adminId, required String note}) async {
    await ApiClient.post('/releases/$releaseId/notes', data: {
      'admin_id': adminId,
      'body': note,
    });
  }

  Future<void> deleteReleaseFully(String releaseId) async {
    await ApiClient.delete('/releases/$releaseId');
  }

  Future<int> bulkUpdateStatuses(
    List<String> releaseIds,
    String newStatus, {
    String? reason,
  }) async {
    final ids = releaseIds.where((e) => e.trim().isNotEmpty).toSet().toList();
    if (ids.isEmpty) return 0;
    try {
      final res = await ApiClient.post('/releases/bulk-status', data: {
        'release_ids': ids,
        'status': newStatus,
        if (reason != null) 'reason': reason,
      });
      final body = _asMap(res.data);
      final u = body['updated']; final c = body['count'];
      return u is num ? u.toInt() : c is num ? c.toInt() : int.tryParse(u?.toString() ?? '') ?? ids.length;
    } catch (e) {
      debugPrint('[ReleaseRepository] bulkUpdateStatuses failed: $e');
      return 0;
    }
  }

  /// Safely cast dynamic to Map<String, dynamic>.
  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }
}
