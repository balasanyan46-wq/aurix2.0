import 'package:aurix_flutter/data/supabase_client.dart';
import 'package:aurix_flutter/data/models/profile_model.dart';

class ProfileRepository {
  /// PK column: 'user_id' per schema. Use 'id' if your table uses id.
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
      'name': profile.name,
      'city': profile.city,
      'phone': profile.phone,
      'gender': profile.gender,
      'bio': profile.bio,
      'avatar_url': profile.avatarUrl,
      'updated_at': now,
    };
    final res = await supabase.from('profiles').upsert(data, onConflict: _pkCol).select().single();
    return ProfileModel.fromJson(res as Map<String, dynamic>);
  }

  Future<ProfileModel?> getProfile(String id) async {
    final res = await supabase.from('profiles').select().eq(_pkCol, id).maybeSingle();
    if (res == null) return null;
    return ProfileModel.fromJson(res as Map<String, dynamic>);
  }

  /// Minimal upsert for auth (signup/signin). Inserts user_id, created_at, updated_at.
  Future<void> upsertProfile({
    required String id,
    required String email,
    String? displayName,
    String? phone,
    String plan = 'base',
  }) async {
    final now = DateTime.now().toIso8601String();
    await supabase.from('profiles').upsert({
      _pkCol: id,
      'created_at': now,
      'updated_at': now,
    }, onConflict: _pkCol);
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

  Future<void> updatePlan(String id, String plan) async {
    await supabase.from('profiles').update({
      'plan': plan,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq(_pkCol, id);
  }

  bool hasStudioAccess(ProfileModel? profile) => profile?.hasStudioAccess ?? false;

  Future<List<ProfileModel>> getAllProfiles() async {
    final res = await supabase.from('profiles').select().order('created_at', ascending: false);
    return (res as List).map((e) => ProfileModel.fromJson(e as Map<String, dynamic>)).toList();
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
