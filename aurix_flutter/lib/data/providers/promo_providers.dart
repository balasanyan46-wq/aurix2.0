import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/data/models/promo_request_model.dart';
import 'package:aurix_flutter/data/models/release_aai_model.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

final myPromoRequestsProvider =
    FutureProvider.family<List<PromoRequestModel>, String?>((ref, releaseId) async {
  return ref.read(promoRepositoryProvider).getMyRequests(releaseId: releaseId);
});

final adminPromoRequestsProvider = FutureProvider<List<PromoRequestModel>>((ref) async {
  return ref.read(promoRepositoryProvider).getAllRequests();
});

final promoEventsProvider =
    FutureProvider.family<List<PromoEventModel>, String>((ref, requestId) async {
  if (requestId.isEmpty) return const [];
  return ref.read(promoRepositoryProvider).getEvents(requestId);
});

final selectedPromoReleaseIdProvider = StateProvider<String?>((ref) => null);

final selectedPromoReleaseAaiProvider = FutureProvider<ReleaseAaiModel?>((ref) async {
  final releaseId = ref.watch(selectedPromoReleaseIdProvider);
  if (releaseId == null || releaseId.isEmpty) return null;
  return ref.read(releaseAaiRepositoryProvider).getReleaseAai(releaseId);
});

final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider)?.id;
});
