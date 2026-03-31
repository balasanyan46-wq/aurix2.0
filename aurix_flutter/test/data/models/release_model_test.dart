import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/data/models/release_model.dart';

void main() {
  group('ReleaseModel', () {
    final now = DateTime(2025, 1, 15, 12, 0, 0);
    final fullJson = <String, dynamic>{
      'id': 'r-1',
      'owner_id': 'u-1',
      'title': 'My Album',
      'artist': 'Artist X',
      'release_type': 'album',
      'release_date': '2025-03-01',
      'genre': 'hip-hop',
      'language': 'en',
      'explicit': true,
      'upc': '123456789012',
      'label': 'Aurix',
      'copyright_year': 2025,
      'status': 'live',
      'cover_url': 'https://example.com/cover.jpg',
      'cover_path': 'covers/r-1.jpg',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };

    group('fromJson', () {
      test('should parse all fields from complete JSON', () {
        final model = ReleaseModel.fromJson(fullJson);

        expect(model.id, 'r-1');
        expect(model.ownerId, 'u-1');
        expect(model.title, 'My Album');
        expect(model.artist, 'Artist X');
        expect(model.releaseType, 'album');
        expect(model.releaseDate, DateTime(2025, 3, 1));
        expect(model.genre, 'hip-hop');
        expect(model.language, 'en');
        expect(model.explicit, true);
        expect(model.upc, '123456789012');
        expect(model.label, 'Aurix');
        expect(model.copyrightYear, 2025);
        expect(model.status, 'live');
        expect(model.coverUrl, 'https://example.com/cover.jpg');
        expect(model.coverPath, 'covers/r-1.jpg');
        expect(model.createdAt, now);
        expect(model.updatedAt, now);
      });

      test('should use artist_id fallback for owner_id', () {
        final json = <String, dynamic>{
          'id': 'r-2',
          'artist_id': 'a-99',
          'title': 'T',
          'release_type': 'single',
          'status': 'draft',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };
        final model = ReleaseModel.fromJson(json);
        expect(model.ownerId, 'a-99');
      });

      test('should apply defaults for missing optional fields', () {
        final json = <String, dynamic>{
          'id': 'r-3',
          'created_at': now.toIso8601String(),
        };
        final model = ReleaseModel.fromJson(json);

        expect(model.ownerId, '');
        expect(model.title, '');
        expect(model.artist, isNull);
        expect(model.releaseType, 'single');
        expect(model.releaseDate, isNull);
        expect(model.genre, isNull);
        expect(model.language, isNull);
        expect(model.explicit, false);
        expect(model.upc, isNull);
        expect(model.label, isNull);
        expect(model.copyrightYear, isNull);
        expect(model.status, 'draft');
        expect(model.coverUrl, isNull);
        expect(model.coverPath, isNull);
      });

      test('should fallback updated_at to created_at when missing', () {
        final json = <String, dynamic>{
          'id': 'r-4',
          'created_at': '2025-06-01T00:00:00.000',
        };
        final model = ReleaseModel.fromJson(json);
        expect(model.updatedAt, DateTime(2025, 6, 1));
      });
    });

    group('toJson', () {
      test('should produce valid JSON and support roundtrip', () {
        final model = ReleaseModel.fromJson(fullJson);
        final json = model.toJson();

        expect(json['id'], 'r-1');
        expect(json['owner_id'], 'u-1');
        expect(json['title'], 'My Album');
        expect(json['explicit'], true);
        expect(json['copyright_year'], 2025);
        expect(json['release_date'], '2025-03-01');
      });

      test('should output null release_date when not set', () {
        final model = ReleaseModel.fromJson({
          'id': 'r-5',
          'created_at': now.toIso8601String(),
        });
        expect(model.toJson()['release_date'], isNull);
      });
    });

    group('copyWith', () {
      test('should override specified fields only', () {
        final original = ReleaseModel.fromJson(fullJson);
        final copy = original.copyWith(title: 'New Title', status: 'submitted');

        expect(copy.title, 'New Title');
        expect(copy.status, 'submitted');
        expect(copy.id, original.id);
        expect(copy.artist, original.artist);
        expect(copy.createdAt, original.createdAt);
      });
    });

    group('computed properties', () {
      test('isDraft / isSubmitted / isLive', () {
        expect(ReleaseModel.fromJson({...fullJson, 'status': 'draft'}).isDraft, true);
        expect(ReleaseModel.fromJson({...fullJson, 'status': 'draft'}).isLive, false);
        expect(ReleaseModel.fromJson({...fullJson, 'status': 'submitted'}).isSubmitted, true);
        expect(ReleaseModel.fromJson({...fullJson, 'status': 'live'}).isLive, true);
      });

      test('isComplete returns true when required fields present', () {
        final model = ReleaseModel.fromJson(fullJson);
        expect(model.isComplete, true);
      });

      test('isComplete returns false when artist is null', () {
        final model = ReleaseModel.fromJson({...fullJson, 'artist': null});
        expect(model.isComplete, false);
      });

      test('isComplete returns false when title is empty', () {
        final model = ReleaseModel.fromJson({...fullJson, 'title': ''});
        expect(model.isComplete, false);
      });
    });
  });
}
