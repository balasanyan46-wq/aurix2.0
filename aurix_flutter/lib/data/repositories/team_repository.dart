import 'package:aurix_flutter/data/supabase_client.dart';
import 'package:aurix_flutter/data/models/team_member_model.dart';

class TeamRepository {
  Future<List<TeamMemberModel>> getMyTeam(String ownerId) async {
    final res = await supabase
        .from('team_members')
        .select()
        .eq('owner_id', ownerId)
        .neq('status', 'removed')
        .order('created_at');
    return (res as List).map((e) => TeamMemberModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TeamMemberModel> addMember({
    required String ownerId,
    required String name,
    String? email,
    required String role,
    required double splitPercent,
  }) async {
    final res = await supabase.from('team_members').insert({
      'owner_id': ownerId,
      'member_name': name,
      'member_email': email,
      'role': role,
      'split_percent': splitPercent,
    }).select().single();
    return TeamMemberModel.fromJson(res);
  }

  Future<void> updateMember(String id, {String? name, String? email, String? role, double? splitPercent}) async {
    final data = <String, dynamic>{};
    if (name != null) data['member_name'] = name;
    if (email != null) data['member_email'] = email;
    if (role != null) data['role'] = role;
    if (splitPercent != null) data['split_percent'] = splitPercent;
    if (data.isEmpty) return;
    await supabase.from('team_members').update(data).eq('id', id);
  }

  Future<void> removeMember(String id) async {
    await supabase.from('team_members').update({'status': 'removed'}).eq('id', id);
  }
}
