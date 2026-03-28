import 'package:aurix_flutter/core/api/api_client.dart' show ApiClient, asList;
import 'navigator_models.dart';
import 'navigator_seed.dart';

class NavigatorRepository {
  Future<List<NavigatorMaterial>> getPublishedMaterials() async {
    try {
      final seedBySlug = _seedBySlug();
      final res = await ApiClient.get('/artist-navigator-materials', query: {
        'is_published': true,
      });
      final rows = asList(res.data);
      final list = rows
          .whereType<Map>()
          .map((e) => NavigatorMaterial.fromJson(e.cast<String, dynamic>()))
          .map((db) => _enrichFromSeed(db, seedBySlug[db.slug]))
          .toList();
      if (list.isEmpty) return NavigatorSeed.materials();
      return list;
    } catch (e) {
      if (_isMissingTable(e)) return NavigatorSeed.materials();
      rethrow;
    }
  }

  Future<NavigatorMaterial?> getBySlug(String slug) async {
    try {
      final seedBySlug = _seedBySlug();
      final res = await ApiClient.get('/artist-navigator-materials/by-slug/$slug');
      final row = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : null;
      if (row == null) {
        final seed = NavigatorSeed.materials();
        for (final m in seed) {
          if (m.slug == slug) return m;
        }
        return null;
      }
      final db = NavigatorMaterial.fromJson(row);
      return _enrichFromSeed(db, seedBySlug[db.slug]);
    } catch (e) {
      if (_isMissingTable(e)) {
        final seed = NavigatorSeed.materials();
        for (final m in seed) {
          if (m.slug == slug) return m;
        }
        return null;
      }
      rethrow;
    }
  }

  Future<Set<String>> getSavedMaterialIds(String userId) async {
    try {
      final res = await ApiClient.get('/artist-navigator-user-materials', query: {
        'user_id': userId,
        'is_saved': true,
      });
      final rows = asList(res.data);
      return rows
          .whereType<Map>()
          .map((e) => (e['material_id'] ?? '').toString())
          .where((e) => e.isNotEmpty)
          .toSet();
    } catch (e) {
      if (_isMissingTable(e)) return <String>{};
      rethrow;
    }
  }

  Future<Set<String>> getCompletedMaterialIds(String userId) async {
    try {
      final res = await ApiClient.get('/artist-navigator-user-materials', query: {
        'user_id': userId,
        'is_completed': true,
      });
      final rows = asList(res.data);
      return rows
          .whereType<Map>()
          .map((e) => (e['material_id'] ?? '').toString())
          .where((e) => e.isNotEmpty)
          .toSet();
    } catch (e) {
      if (_isMissingTable(e)) return <String>{};
      rethrow;
    }
  }

  Future<void> setSaved({
    required String userId,
    required String materialId,
    required bool isSaved,
  }) async {
    try {
      await _upsertUserMaterial(
        userId: userId,
        materialId: materialId,
        patch: {'is_saved': isSaved},
      );
    } catch (e) {
      if (_isMissingTable(e)) return;
      rethrow;
    }
  }

  Future<void> setCompleted({
    required String userId,
    required String materialId,
    required bool isCompleted,
  }) async {
    try {
      await _upsertUserMaterial(
        userId: userId,
        materialId: materialId,
        patch: {'is_completed': isCompleted},
      );
    } catch (e) {
      if (_isMissingTable(e)) return;
      rethrow;
    }
  }

  Future<void> saveOnboardingAnswers({
    required String userId,
    required NavigatorOnboardingAnswers answers,
  }) async {
    try {
      await ApiClient.post('/artist-navigator-profiles', data: {
        'user_id': userId,
        'onboarding_answers': answers.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (_isMissingTable(e)) return;
      rethrow;
    }
  }

  Future<NavigatorOnboardingAnswers?> getOnboardingAnswers(String userId) async {
    try {
      final res = await ApiClient.get('/artist-navigator-profiles/$userId');
      final row = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : null;
      final raw = row?['onboarding_answers'];
      if (raw is Map<String, dynamic>) {
        return NavigatorOnboardingAnswers.fromJson(raw);
      }
      return null;
    } catch (e) {
      if (_isMissingTable(e)) return null;
      rethrow;
    }
  }

  Future<void> _upsertUserMaterial({
    required String userId,
    required String materialId,
    required Map<String, dynamic> patch,
  }) async {
    final existingRes = await ApiClient.get('/artist-navigator-user-materials/item', query: {
      'user_id': userId,
      'material_id': materialId,
    });
    final existing = existingRes.data is Map ? Map<String, dynamic>.from(existingRes.data as Map) : null;
    if (existing == null) {
      await ApiClient.post('/artist-navigator-user-materials', data: {
        'user_id': userId,
        'material_id': materialId,
        'is_saved': patch['is_saved'] ?? false,
        'is_completed': patch['is_completed'] ?? false,
        'progress_percent': 0,
      });
      return;
    }
    await ApiClient.put('/artist-navigator-user-materials/${existing['id']}', data: {
      ...patch,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  bool _isMissingTable(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('404') || msg.contains('not found') || msg.contains('missing');
  }

  Map<String, NavigatorMaterial> _seedBySlug() {
    final out = <String, NavigatorMaterial>{};
    for (final material in NavigatorSeed.materials()) {
      out[material.slug] = material;
    }
    return out;
  }

  NavigatorMaterial _enrichFromSeed(
    NavigatorMaterial db,
    NavigatorMaterial? seed,
  ) {
    if (seed == null) return db;
    return NavigatorMaterial(
      id: db.id,
      slug: db.slug,
      title: seed.title,
      subtitle: seed.subtitle,
      excerpt: seed.excerpt,
      bodyBlocks: seed.bodyBlocks,
      category: db.category,
      tags: db.tags,
      platforms: db.platforms,
      stages: db.stages,
      goals: db.goals,
      blockers: db.blockers,
      difficulty: db.difficulty,
      readingTimeMinutes: seed.readingTimeMinutes,
      formatType: db.formatType,
      actionLinks: db.actionLinks.isNotEmpty ? db.actionLinks : seed.actionLinks,
      sourcePack: db.sourcePack.isNotEmpty ? db.sourcePack : seed.sourcePack,
      lastReviewedAt: db.lastReviewedAt,
      isFeatured: db.isFeatured,
      isPublished: db.isPublished,
      priorityScore: db.priorityScore,
      relatedContentIds: db.relatedContentIds.isNotEmpty
          ? db.relatedContentIds
          : seed.relatedContentIds,
      relatedTools: db.relatedTools.isNotEmpty ? db.relatedTools : seed.relatedTools,
      createdAt: db.createdAt,
      updatedAt: db.updatedAt,
    );
  }
}
