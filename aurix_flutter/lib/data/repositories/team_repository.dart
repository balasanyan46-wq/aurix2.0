import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/data/models/team_member_model.dart';

class TeamRepository {
  Future<List<TeamMemberModel>> getMyTeam(String ownerId) async {
    final res = await ApiClient.get('/team-members', query: {
      'owner_id': ownerId,
      'status_neq': 'removed',
      'order': 'created_at.asc',
    });
    final list = res.data as List;
    return list.map((e) => TeamMemberModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TeamMemberModel> addMember({
    required String ownerId,
    required String name,
    String? email,
    required String role,
    required double splitPercent,
  }) async {
    final res = await ApiClient.post('/team-members', data: {
      'owner_id': ownerId,
      'member_name': name,
      'member_email': email,
      'role': role,
      'split_percent': splitPercent,
    });
    final body = res.data as Map<String, dynamic>;
    return TeamMemberModel.fromJson(body);
  }

  Future<void> updateMember(String id, {String? name, String? email, String? role, double? splitPercent}) async {
    final data = <String, dynamic>{};
    if (name != null) data['member_name'] = name;
    if (email != null) data['member_email'] = email;
    if (role != null) data['role'] = role;
    if (splitPercent != null) data['split_percent'] = splitPercent;
    if (data.isEmpty) return;
    await ApiClient.put('/team-members/$id', data: data);
  }

  Future<void> removeMember(String id) async {
    await ApiClient.put('/team-members/$id', data: {'status': 'removed'});
  }
}
