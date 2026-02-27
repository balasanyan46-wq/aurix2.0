import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aurix_flutter/core/supabase_client.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/data/models/profile_model.dart';
import 'package:aurix_flutter/presentation/providers/subscription_provider.dart';
import 'package:aurix_flutter/app/auth/auth_store_provider.dart';

final currentUserProvider = Provider<User?>((ref) {
  final auth = ref.watch(authStoreProvider);
  if (!auth.ready) return null;
  return auth.session?.user;
});

final currentProfileProvider = StreamProvider<ProfileModel?>((ref) {
  final auth = ref.watch(authStoreProvider);
  final uid = auth.ready ? auth.userId : null;
  if (uid == null) return Stream.value(null);

  return supabase
      .from('profiles')
      .stream(primaryKey: ['user_id'])
      .eq('user_id', uid)
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
  final plan = ref.watch(effectivePlanProvider);
  return plan == 'breakthrough' || plan == 'empire';
});
