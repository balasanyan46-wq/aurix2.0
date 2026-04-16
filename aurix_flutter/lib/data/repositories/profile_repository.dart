import 'package:flutter/foundation.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/data/models/profile_model.dart';

class ProfileRepository {
  /// Профиль текущего пользователя. Requires auth token.
  Future<ProfileModel?> getMyProfile() async {
    try {
      final res = await ApiClient.get('/profiles/me');
      final body = _asMap(res.data);
      if (body['success'] == true && body['profile'] != null) {
        return ProfileModel.fromJson(_asMap(body['profile']));
      }
      return null;
    } catch (e) {
      debugPrint('[ProfileRepository] getMyProfile failed: $e');
      return null;
    }
  }

  /// Ensure profile exists. GET /profiles/me auto-creates if missing.
  Future<ProfileModel?> ensureProfile() async {
    return getMyProfile();
  }

  /// Upsert profile via PUT /profiles/me.
  /// Only sends non-null fields to avoid overwriting existing data with NULL.
  Future<ProfileModel> upsertMyProfile(ProfileModel profile) async {
    final data = <String, dynamic>{};
    if (profile.artistName != null) data['artist_name'] = profile.artistName;
    if (profile.displayName != null) data['display_name'] = profile.displayName;
    if (profile.name != null) data['name'] = profile.name;
    if (profile.city != null) data['city'] = profile.city;
    if (profile.phone != null) data['phone'] = profile.phone;
    if (profile.gender != null) data['gender'] = profile.gender;
    if (profile.bio != null) data['bio'] = profile.bio;
    if (profile.avatarUrl != null) data['avatar_url'] = profile.avatarUrl;

    final res = await ApiClient.put('/profiles/me', data: data);
    final body = _asMap(res.data);
    return ProfileModel.fromJson(_asMap(body['profile'] ?? body));
  }

  Future<ProfileModel?> getProfile(String id) async {
    try {
      final res = await ApiClient.get('/profiles/$id');
      final body = _asMap(res.data);
      if (body['success'] == true && body['profile'] != null) {
        return ProfileModel.fromJson(_asMap(body['profile']));
      }
      return null;
    } catch (e) {
      debugPrint('[ProfileRepository] getProfile($id) failed: $e');
      return null;
    }
  }

  /// Create profile during signup — now a no-op (backend auto-creates).
  Future<void> createProfile({
    required String id,
    required String email,
    String? displayName,
    String? artistName,
    String? name,
    String? phone,
    String plan = 'start',
  }) async {}

  /// Touch profile on login — now a no-op.
  Future<void> touchProfile(
    String id,
    String email, {
    Map<String, dynamic>? userMeta,
  }) async {}

  Future<void> updateProfile(
    String id, {
    String? displayName,
    String? artistName,
    String? phone,
    String? name,
    String? city,
    String? gender,
    String? bio,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates['display_name'] = displayName;
    if (artistName != null) updates['artist_name'] = artistName;
    if (phone != null) updates['phone'] = phone;
    if (name != null) updates['name'] = name;
    if (city != null) updates['city'] = city;
    if (gender != null) updates['gender'] = gender;
    if (bio != null) updates['bio'] = bio;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (updates.isNotEmpty) {
      await ApiClient.put('/profiles/me', data: updates);
    }
  }

  bool hasStudioAccess(ProfileModel? profile) =>
      profile?.hasStudioAccess ?? false;

  Future<List<ProfileModel>> getAllProfiles() async {
    final res = await ApiClient.get('/profiles/');
    final body = _asMap(res.data);
    final list = (body['profiles'] as List?) ?? [];
    return list.map((e) => ProfileModel.fromJson(_asMap(e))).toList();
  }

  Future<void> updateRole(String userId, String role) async {
    await ApiClient.put('/profiles/$userId/role', data: {'role': role});
  }

  Future<void> updateAccountStatus(String userId, String status) async {
    await ApiClient.put('/profiles/$userId/status', data: {'account_status': status});
  }

  Future<int> bulkUpdateAccountStatus(
    List<String> userIds,
    String status, {
    String? reason,
  }) async {
    final ids = userIds.where((e) => e.trim().isNotEmpty).toSet().toList();
    if (ids.isEmpty) return 0;
    try {
      final res = await ApiClient.post('/profiles/bulk-status', data: {
        'user_ids': ids,
        'status': status,
        if (reason != null) 'reason': reason,
      });
      final body = _asMap(res.data);
      final c = body['count'];
      return c is num ? c.toInt() : int.tryParse(c?.toString() ?? '') ?? ids.length;
    } catch (e) {
      debugPrint('[ProfileRepository] bulkUpdateAccountStatus failed: $e');
      return 0;
    }
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }
}
