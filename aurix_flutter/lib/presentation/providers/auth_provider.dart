import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/api/auth_api.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/data/models/profile_model.dart';
import 'package:aurix_flutter/presentation/providers/subscription_provider.dart';
import 'package:aurix_flutter/app/auth/auth_store_provider.dart';

final currentUserProvider = Provider<ApiUser?>((ref) {
  final auth = ref.watch(authStoreProvider);
  if (!auth.ready) return null;
  return auth.user;
});

final currentProfileProvider = FutureProvider<ProfileModel?>((ref) async {
  final auth = ref.watch(authStoreProvider);
  final uid = auth.ready ? auth.userId : null;
  if (uid == null) return null;

  try {
    final res = await ApiClient.get('/profiles/me');
    final body = res.data as Map<String, dynamic>;
    if (body['success'] == true && body['profile'] != null) {
      return ProfileModel.fromJson(body['profile'] as Map<String, dynamic>);
    }
    return null;
  } catch (_) {
    return null;
  }
});

final isAdminProvider = FutureProvider<bool>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  return profile?.isAdmin ?? false;
});

final hasStudioAccessProvider = FutureProvider<bool>((ref) async {
  return ref.watch(hasPlanAccessProvider('breakthrough'));
});
