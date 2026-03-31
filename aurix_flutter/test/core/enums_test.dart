import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/core/enums.dart';

void main() {
  group('ArtistLevel', () {
    group('label', () {
      test('should return Rising for rising', () {
        expect(ArtistLevel.rising.label, 'Rising');
      });

      test('should return Pro for pro', () {
        expect(ArtistLevel.pro.label, 'Pro');
      });

      test('should return Top 100 for top100', () {
        expect(ArtistLevel.top100.label, 'Top 100');
      });

      test('should return Elite for elite', () {
        expect(ArtistLevel.elite.label, 'Elite');
      });
    });
  });

  group('artistLevelFromScore', () {
    test('should return elite when rank <= 10', () {
      expect(artistLevelFromScore(100, 1), ArtistLevel.elite);
      expect(artistLevelFromScore(100, 10), ArtistLevel.elite);
    });

    test('should return top100 when rank 11..100', () {
      expect(artistLevelFromScore(100, 11), ArtistLevel.top100);
      expect(artistLevelFromScore(100, 100), ArtistLevel.top100);
    });

    test('should return pro when score >= 400 and rank > 100', () {
      expect(artistLevelFromScore(400, 101), ArtistLevel.pro);
      expect(artistLevelFromScore(600, 200), ArtistLevel.pro);
      expect(artistLevelFromScore(999, 200), ArtistLevel.pro);
    });

    test('should return rising when score < 400 and rank > 100', () {
      expect(artistLevelFromScore(399, 101), ArtistLevel.rising);
      expect(artistLevelFromScore(0, 500), ArtistLevel.rising);
    });

    test('should prioritize rank over score', () {
      // Even low score gets elite if rank is top 10
      expect(artistLevelFromScore(0, 5), ArtistLevel.elite);
    });
  });

  group('SubscriptionPlan', () {
    group('slug', () {
      test('should return enum name as slug', () {
        expect(SubscriptionPlan.start.slug, 'start');
        expect(SubscriptionPlan.breakthrough.slug, 'breakthrough');
        expect(SubscriptionPlan.empire.slug, 'empire');
      });
    });

    group('label', () {
      test('should return Russian labels', () {
        expect(SubscriptionPlan.start.label, 'Старт');
        expect(SubscriptionPlan.breakthrough.label, 'Прорыв');
        expect(SubscriptionPlan.empire.label, 'Империя');
      });
    });

    group('fromSlug', () {
      test('should parse canonical slugs', () {
        expect(SubscriptionPlan.fromSlug('start'), SubscriptionPlan.start);
        expect(SubscriptionPlan.fromSlug('breakthrough'), SubscriptionPlan.breakthrough);
        expect(SubscriptionPlan.fromSlug('empire'), SubscriptionPlan.empire);
      });

      test('should handle legacy base/basic/BASE fallback to start', () {
        expect(SubscriptionPlan.fromSlug('base'), SubscriptionPlan.start);
        expect(SubscriptionPlan.fromSlug('basic'), SubscriptionPlan.start);
        expect(SubscriptionPlan.fromSlug('BASE'), SubscriptionPlan.start);
      });

      test('should handle legacy pro/PRO fallback to breakthrough', () {
        expect(SubscriptionPlan.fromSlug('pro'), SubscriptionPlan.breakthrough);
        expect(SubscriptionPlan.fromSlug('PRO'), SubscriptionPlan.breakthrough);
      });

      test('should handle legacy studio/STUDIO fallback to empire', () {
        expect(SubscriptionPlan.fromSlug('studio'), SubscriptionPlan.empire);
        expect(SubscriptionPlan.fromSlug('STUDIO'), SubscriptionPlan.empire);
      });

      test('should default to start for unknown values', () {
        expect(SubscriptionPlan.fromSlug('unknown'), SubscriptionPlan.start);
        expect(SubscriptionPlan.fromSlug(null), SubscriptionPlan.start);
        expect(SubscriptionPlan.fromSlug(''), SubscriptionPlan.start);
      });
    });
  });

  group('ReleaseStatus', () {
    group('label', () {
      test('should return Russian labels for all statuses', () {
        expect(ReleaseStatus.draft.label, 'Черновик');
        expect(ReleaseStatus.inReview.label, 'На проверке');
        expect(ReleaseStatus.approved.label, 'Одобрен');
        expect(ReleaseStatus.rejected.label, 'Отклонён');
        expect(ReleaseStatus.scheduled.label, 'Запланирован');
        expect(ReleaseStatus.live.label, 'Выпущен');
      });
    });
  });

  group('releaseStatusFromString', () {
    test('should parse known status strings', () {
      expect(releaseStatusFromString('draft'), ReleaseStatus.draft);
      expect(releaseStatusFromString('submitted'), ReleaseStatus.inReview);
      expect(releaseStatusFromString('approved'), ReleaseStatus.approved);
      expect(releaseStatusFromString('rejected'), ReleaseStatus.rejected);
      expect(releaseStatusFromString('scheduled'), ReleaseStatus.scheduled);
      expect(releaseStatusFromString('live'), ReleaseStatus.live);
    });

    test('should default to draft for unknown strings', () {
      expect(releaseStatusFromString('garbage'), ReleaseStatus.draft);
      expect(releaseStatusFromString(''), ReleaseStatus.draft);
    });
  });
}
