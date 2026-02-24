import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

/// Releases of the current user from Supabase.
/// Kept without autoDispose so data is cached when navigating between tabs.
final releasesProvider = FutureProvider<List<ReleaseModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.read(releaseRepositoryProvider).getReleasesByOwner(user.id);
});

/// All releases (for admin).
final adminReleasesProvider = FutureProvider<List<ReleaseModel>>((ref) async {
  return ref.read(releaseRepositoryProvider).getAllReleases();
});
