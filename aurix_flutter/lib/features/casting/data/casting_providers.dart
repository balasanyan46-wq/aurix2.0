import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/features/casting/data/casting_repository.dart';
import 'package:aurix_flutter/features/casting/domain/casting_application.dart';

final castingRepositoryProvider = Provider((_) => CastingRepository.instance);

final adminCastingApplicationsProvider =
    FutureProvider<List<CastingApplication>>((ref) async {
  return ref.read(castingRepositoryProvider).adminGetAll();
});

final adminCastingStatsProvider = FutureProvider<CastingStats>((ref) async {
  return ref.read(castingRepositoryProvider).adminGetStats();
});
