import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/features/navigator/data/navigator_models.dart';

void main() {
  group('NavigatorClusters', () {
    test('should return known label for yandex_music', () {
      expect(NavigatorClusters.label(NavigatorClusters.yandexMusic), 'Яндекс Музыка');
    });

    test('should return known label for vk_music', () {
      expect(NavigatorClusters.label(NavigatorClusters.vkMusic), 'VK Музыка');
    });

    test('should return value itself for unknown cluster', () {
      expect(NavigatorClusters.label('unknown_cluster'), 'unknown_cluster');
    });

    test('ruCisPriority should contain all RU/CIS clusters', () {
      expect(NavigatorClusters.ruCisPriority, contains(NavigatorClusters.yandexMusic));
      expect(NavigatorClusters.ruCisPriority, contains(NavigatorClusters.vkMusic));
      expect(NavigatorClusters.ruCisPriority, contains(NavigatorClusters.legalSafety));
      expect(NavigatorClusters.ruCisPriority, contains(NavigatorClusters.contractsRights));
      expect(NavigatorClusters.ruCisPriority, contains(NavigatorClusters.artistBrand));
    });
  });

  group('NavigatorSourceRef', () {
    test('should parse from JSON with all fields', () {
      final ref = NavigatorSourceRef.fromJson({
        'title': 'Source 1',
        'url': 'https://example.com',
        'source_type': 'official',
        'note': 'A note',
      });
      expect(ref.title, 'Source 1');
      expect(ref.url, 'https://example.com');
      expect(ref.sourceType, 'official');
      expect(ref.note, 'A note');
    });

    test('should default missing fields to empty strings', () {
      final ref = NavigatorSourceRef.fromJson({});
      expect(ref.title, '');
      expect(ref.url, '');
      expect(ref.sourceType, 'official');
      expect(ref.note, '');
    });

    test('should round-trip through toJson', () {
      final original = NavigatorSourceRef.fromJson({
        'title': 'T',
        'url': 'U',
        'source_type': 'community',
        'note': 'N',
      });
      final restored = NavigatorSourceRef.fromJson(original.toJson());
      expect(restored.title, original.title);
      expect(restored.url, original.url);
      expect(restored.sourceType, original.sourceType);
      expect(restored.note, original.note);
    });
  });

  group('NavigatorActionLink', () {
    test('should parse from JSON', () {
      final link = NavigatorActionLink.fromJson({
        'action_type': 'open_article',
        'label': 'Read',
        'route': '/article/1',
        'payload': {'key': 'value'},
      });
      expect(link.actionType, 'open_article');
      expect(link.label, 'Read');
      expect(link.route, '/article/1');
      expect(link.payload, {'key': 'value'});
    });

    test('should default route to /home when missing', () {
      final link = NavigatorActionLink.fromJson({});
      expect(link.route, '/home');
    });

    test('should handle null payload', () {
      final link = NavigatorActionLink.fromJson({
        'action_type': 'test',
        'label': 'test',
        'route': '/test',
      });
      expect(link.payload, isNull);
    });

    test('should round-trip through toJson', () {
      final original = NavigatorActionLink.fromJson({
        'action_type': 'open',
        'label': 'Go',
        'route': '/go',
      });
      final restored = NavigatorActionLink.fromJson(original.toJson());
      expect(restored.actionType, original.actionType);
      expect(restored.route, original.route);
    });
  });

  group('NavigatorBodyBlock', () {
    test('should parse from JSON with items', () {
      final block = NavigatorBodyBlock.fromJson({
        'kind': 'checklist',
        'title': 'Steps',
        'text': 'Follow these',
        'items': ['Step 1', 'Step 2'],
      });
      expect(block.kind, 'checklist');
      expect(block.items, ['Step 1', 'Step 2']);
    });

    test('should default kind to text when missing', () {
      final block = NavigatorBodyBlock.fromJson({});
      expect(block.kind, 'text');
      expect(block.items, isEmpty);
    });
  });

  group('NavigatorMaterial', () {
    Map<String, dynamic> _minimalJson() => {
          'id': 'mat-1',
          'slug': 'test-material',
          'title': 'Test',
          'created_at': '2024-01-01T00:00:00.000',
          'updated_at': '2024-06-01T00:00:00.000',
        };

    test('should parse minimal JSON with defaults', () {
      final m = NavigatorMaterial.fromJson(_minimalJson());
      expect(m.id, 'mat-1');
      expect(m.slug, 'test-material');
      expect(m.title, 'Test');
      expect(m.subtitle, '');
      expect(m.difficulty, 'средний');
      expect(m.readingTimeMinutes, 6);
      expect(m.formatType, 'guide');
      expect(m.isFeatured, isFalse);
      expect(m.isPublished, isTrue);
      expect(m.priorityScore, 0.5);
    });

    test('should parse legacy field names (cluster, short_description, stage_tags)', () {
      final json = {
        ..._minimalJson(),
        'cluster': 'yandex_music',
        'short_description': 'short desc',
        'stage_tags': ['beginner'],
        'goal_tags': ['release'],
        'platform_tags': ['spotify'],
      };
      final m = NavigatorMaterial.fromJson(json);
      expect(m.category, 'yandex_music');
      expect(m.excerpt, 'short desc');
      expect(m.stages, ['beginner']);
      expect(m.goals, ['release']);
      expect(m.platforms, ['spotify']);
    });

    test('should prefer new field names over legacy', () {
      final json = {
        ..._minimalJson(),
        'category': 'new_cat',
        'cluster': 'old_cluster',
        'excerpt': 'new excerpt',
        'short_description': 'old desc',
        'stages': ['new_stage'],
        'stage_tags': ['old_stage'],
      };
      final m = NavigatorMaterial.fromJson(json);
      expect(m.category, 'new_cat');
      expect(m.excerpt, 'new excerpt');
      expect(m.stages, ['new_stage']);
    });

    test('durationBucket should categorize reading time', () {
      final base = _minimalJson();

      final short = NavigatorMaterial.fromJson({...base, 'reading_time_minutes': 5});
      expect(short.durationBucket, 'до 10 минут');

      final medium = NavigatorMaterial.fromJson({...base, 'reading_time_minutes': 20});
      expect(medium.durationBucket, '10-30 минут');

      final long = NavigatorMaterial.fromJson({...base, 'reading_time_minutes': 45});
      expect(long.durationBucket, '30+ минут');
    });

    test('durationBucket boundary: 10 min should be "до 10 минут"', () {
      final m = NavigatorMaterial.fromJson({..._minimalJson(), 'reading_time_minutes': 10});
      expect(m.durationBucket, 'до 10 минут');
    });

    test('durationBucket boundary: 30 min should be "10-30 минут"', () {
      final m = NavigatorMaterial.fromJson({..._minimalJson(), 'reading_time_minutes': 30});
      expect(m.durationBucket, '10-30 минут');
    });

    test('aliases should match primary fields', () {
      final m = NavigatorMaterial.fromJson({
        ..._minimalJson(),
        'category': 'cat1',
        'excerpt': 'exc',
        'stages': ['s1'],
        'goals': ['g1'],
        'platforms': ['p1'],
      });
      expect(m.cluster, m.category);
      expect(m.shortDescription, m.excerpt);
      expect(m.stageTags, m.stages);
      expect(m.goalTags, m.goals);
      expect(m.platformTags, m.platforms);
      expect(m.actionPack, m.actionLinks);
      expect(m.relatedArticles, m.relatedContentIds);
    });

    test('should round-trip through toJson / fromJson', () {
      final original = NavigatorMaterial.fromJson({
        ..._minimalJson(),
        'tags': ['tag1', 'tag2'],
        'platforms': ['spotify'],
        'is_featured': true,
        'priority_score': 0.8,
        'reading_time_minutes': 15,
      });
      final restored = NavigatorMaterial.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.slug, original.slug);
      expect(restored.tags, original.tags);
      expect(restored.isFeatured, original.isFeatured);
      expect(restored.priorityScore, original.priorityScore);
      expect(restored.readingTimeMinutes, original.readingTimeMinutes);
    });

    test('should parse body_blocks', () {
      final json = {
        ..._minimalJson(),
        'body_blocks': [
          {'kind': 'text', 'title': 'Intro', 'text': 'Hello'},
          {'kind': 'checklist', 'title': 'Steps', 'text': '', 'items': ['A', 'B']},
        ],
      };
      final m = NavigatorMaterial.fromJson(json);
      expect(m.bodyBlocks.length, 2);
      expect(m.bodyBlocks[0].kind, 'text');
      expect(m.bodyBlocks[1].items, ['A', 'B']);
    });

    test('should parse action_links and source_pack', () {
      final json = {
        ..._minimalJson(),
        'action_links': [
          {'action_type': 'open', 'label': 'Go', 'route': '/go'},
        ],
        'source_pack': [
          {'title': 'Ref', 'url': 'http://ref.com', 'source_type': 'official', 'note': ''},
        ],
      };
      final m = NavigatorMaterial.fromJson(json);
      expect(m.actionLinks.length, 1);
      expect(m.actionLinks[0].actionType, 'open');
      expect(m.sourcePack.length, 1);
      expect(m.sourcePack[0].title, 'Ref');
    });
  });

  group('NavigatorOnboardingAnswers', () {
    test('should parse from JSON with defaults', () {
      final a = NavigatorOnboardingAnswers.fromJson({});
      expect(a.stage, '');
      expect(a.goal, '');
      expect(a.depth, 'средний');
      expect(a.marketRegion, 'ru_cis');
      expect(a.platforms, isEmpty);
    });

    test('should round-trip through toJson / fromJson', () {
      final original = NavigatorOnboardingAnswers(
        stage: 'только начинаю',
        goal: 'подготовить релиз',
        releaseStage: 'через 14 дней',
        platforms: ['spotify', 'яндекс'],
        blocker: 'нет системы',
        depth: 'глубоко и подробно',
        marketRegion: 'ru_cis',
      );
      final restored = NavigatorOnboardingAnswers.fromJson(original.toJson());
      expect(restored.stage, original.stage);
      expect(restored.goal, original.goal);
      expect(restored.platforms, original.platforms);
      expect(restored.blocker, original.blocker);
      expect(restored.marketRegion, original.marketRegion);
    });
  });
}
