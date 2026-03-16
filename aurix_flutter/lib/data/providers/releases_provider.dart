import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/models/release_delete_request_model.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

/// Releases of the current user.
final releasesProvider = FutureProvider<List<ReleaseModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.read(releaseRepositoryProvider).getReleasesByOwner(user.stringId);
});

/// All releases (for admin).
final adminReleasesProvider = FutureProvider<List<ReleaseModel>>((ref) async {
  return ref.read(releaseRepositoryProvider).getAllReleases();
});

/// Releases for artist (poll-based replacement for realtime).
final releasesRealtimeProvider = FutureProvider<List<ReleaseModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.read(releaseRepositoryProvider).getReleasesByOwner(user.stringId);
});

/// All releases for admin (poll-based replacement for realtime).
final adminReleasesRealtimeProvider = FutureProvider<List<ReleaseModel>>((ref) async {
  return ref.read(releaseRepositoryProvider).getAllReleases();
});

final myReleaseDeleteRequestsProvider = FutureProvider<List<ReleaseDeleteRequestModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.read(releaseDeleteRequestRepositoryProvider).getMyRequests(user.stringId);
});
