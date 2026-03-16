import 'package:aurix_flutter/app/auth/auth_store_provider.dart';
import 'package:aurix_flutter/data/models/team_member_model.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final myTeamProvider = FutureProvider<List<TeamMemberModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.read(teamRepositoryProvider).getMyTeam(user.id);
});

final trackCountByReleaseProvider = FutureProvider.family<int, String>((ref, releaseId) async {
  if (releaseId.isEmpty) return 0;
  final tracks = await ref.read(trackRepositoryProvider).getTracksByRelease(releaseId);
  return tracks.length;
});

final promoDoneTasksProvider = FutureProvider<int>((ref) async {
  final uid = ref.watch(authStoreProvider).userId;
  if (uid == null || uid.isEmpty) return 0;
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getStringList('promo_done_tasks:$uid') ?? const <String>[];
  return saved.length;
});

