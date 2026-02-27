import 'package:flutter/foundation.dart';
import 'package:aurix_flutter/data/supabase_client.dart';
import 'package:aurix_flutter/data/models/profile_model.dart';

class ProfileRepository {
  static const String _pkCol = 'user_id';
  /// Профиль текущего пользователя. Требует auth.
  Future<ProfileModel?> getMyProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;
    return getProfile(userId);
  }

  /// Ensure profile exists. Creates minimal row if none. Returns profile or null.
  Future<ProfileModel?> ensureProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    final existing = await getMyProfile();
    if (existing != null) return existing;
    final now = DateTime.now().toIso8601String();
    try {
      await supabase.from('profiles').insert({
        _pkCol: user.id,
        'created_at': now,
        'updated_at': now,
      });
      return getMyProfile();
    } catch (_) {
      return null;
    }
  }

  /// Upsert профиля текущего пользователя. Uses schema: user_id, name, city, phone, gender, bio, avatar_url, updated_at.
  Future<ProfileModel> upsertMyProfile(ProfileModel profile) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');
    final now = DateTime.now().toIso8601String();
    final data = <String, dynamic>{
      _pkCol: user.id,
      'artist_name': profile.artistName,
      'display_name': profile.displayName,
      'name': profile.name,
      'city': profile.city,
      'phone': profile.phone,
      'gender': profile.gender,
      'bio': profile.bio,
      'avatar_url': profile.avatarUrl,
      'updated_at': now,
    };
    final res = await supabase.from('profiles').upsert(data, onConflict: _pkCol).select().single();
    return ProfileModel.fromJson(res);
  }

  Future<ProfileModel?> getProfile(String id) async {
    final res = await supabase.from('profiles').select().eq(_pkCol, id).maybeSingle();
    if (res == null) return null;
    return ProfileModel.fromJson(res);
  }

  /// Upsert for auth signup only. Creates profile with initial plan.
  Future<void> createProfile({
    required String id,
    required String email,
    String? displayName,
    String? name,
    String? phone,
    String plan = 'start',
  }) async {
    final now = DateTime.now().toIso8601String();
    final data = <String, dynamic>{
      _pkCol: id,
      'email': email,
      'plan': plan,
      'updated_at': now,
      'created_at': now,
    };
    if (displayName != null) data['display_name'] = displayName;
    if (name != null) data['name'] = name;
    if (phone != null && phone.isNotEmpty) data['phone'] = phone;
    await supabase.from('profiles').upsert(data, onConflict: _pkCol);
  }

  /// Update email on signin without overwriting plan, role, or other fields.
  Future<void> touchProfile(String id, String email) async {
    final existing = await getProfile(id);
    if (existing != null) {
      final updates = <String, dynamic>{'updated_at': DateTime.now().toIso8601String()};
      if (email.isNotEmpty) updates['email'] = email;
      await supabase.from('profiles').update(updates).eq(_pkCol, id);
    } else {
      await createProfile(id: id, email: email);
    }
  }

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
    final updates = <String, dynamic>{'updated_at': DateTime.now().toIso8601String()};
    if (displayName != null) updates['display_name'] = displayName;
    if (artistName != null) updates['artist_name'] = artistName;
    if (phone != null) updates['phone'] = phone;
    if (name != null) updates['name'] = name;
    if (city != null) updates['city'] = city;
    if (gender != null) updates['gender'] = gender;
    if (bio != null) updates['bio'] = bio;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    await supabase.from('profiles').update(updates).eq(_pkCol, id);
  }

  bool hasStudioAccess(ProfileModel? profile) => profile?.hasStudioAccess ?? false;

  Future<List<ProfileModel>> getAllProfiles() async {
    final res = await supabase.from('profiles').select().order('created_at', ascending: false);
    final list = (res as List).map((e) => ProfileModel.fromJson(e as Map<String, dynamic>)).toList();
    debugPrint('[ProfileRepository] getAllProfiles: ${list.length} profiles loaded');
    return list;
  }

  Future<void> updateRole(String userId, String role) async {
    await supabase.from('profiles').update({
      'role': role,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq(_pkCol, userId);
  }

  Future<void> updateAccountStatus(String userId, String status) async {
    await supabase.from('profiles').update({
      'account_status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq(_pkCol, userId);
  }
}
