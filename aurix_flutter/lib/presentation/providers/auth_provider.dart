import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aurix_flutter/core/supabase_client.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/data/models/profile_model.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authRepositoryProvider).currentUser;
});

final currentProfileProvider = StreamProvider<ProfileModel?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);

  return supabase
      .from('profiles')
      .stream(primaryKey: ['user_id'])
      .eq('user_id', user.id)
      .map((rows) {
        if (rows.isEmpty) return null;
        return ProfileModel.fromJson(rows.first);
      });
});

final isAdminProvider = FutureProvider<bool>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  return profile?.isAdmin ?? false;
});

final hasStudioAccessProvider = FutureProvider<bool>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  return profile?.hasStudioAccess ?? false;
});
