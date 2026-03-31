import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/data/models/track_model.dart';

void main() {
  group('TrackModel', () {
    final now = DateTime(2025, 1, 15, 12, 0, 0);
    final fullJson = <String, dynamic>{
      'id': 't-1',
      'release_id': 'r-1',
      'audio_path': 'tracks/t-1.wav',
      'audio_url': 'https://cdn.example.com/t-1.wav',
      'title': 'Track One',
      'isrc': 'US1234567890',
      'track_number': 1,
      'version': 'remix',
      'explicit': true,
      'created_at': now.toIso8601String(),
    };

    group('fromJson', () {
      test('should parse all fields from complete JSON', () {
        final model = TrackModel.fromJson(fullJson);

        expect(model.id, 't-1');
        expect(model.releaseId, 'r-1');
        expect(model.audioPath, 'tracks/t-1.wav');
        expect(model.audioUrl, 'https://cdn.example.com/t-1.wav');
        expect(model.title, 'Track One');
        expect(model.isrc, 'US1234567890');
        expect(model.trackNumber, 1);
        expect(model.version, 'remix');
        expect(model.explicit, true);
        expect(model.createdAt, now);
      });

      test('should use path fallback for audio_path', () {
        final json = <String, dynamic>{
          'id': 't-2',
          'release_id': 'r-1',
          'path': 'alt/path.wav',
          'created_at': now.toIso8601String(),
          'explicit': false,
          'track_number': 2,
        };
        expect(TrackModel.fromJson(json).audioPath, 'alt/path.wav');
      });

      test('should use file_url and url fallbacks for audio_url', () {
        expect(
          TrackModel.fromJson({
            ...fullJson,
            'audio_url': null,
            'file_url': 'file-url',
          }).audioUrl,
          'file-url',
        );
        expect(
          TrackModel.fromJson({
            ...fullJson,
            'audio_url': null,
            'file_url': null,
            'url': 'plain-url',
          }).audioUrl,
          'plain-url',
        );
      });

      test('should parse track_number from string', () {
        final json = <String, dynamic>{
          ...fullJson,
          'track_number': '7',
        };
        expect(TrackModel.fromJson(json).trackNumber, 7);
      });

      test('should default track_number to 0 for invalid value', () {
        final json = <String, dynamic>{
          ...fullJson,
          'track_number': 'abc',
        };
        expect(TrackModel.fromJson(json).trackNumber, 0);
      });

      test('should default version to original', () {
        final json = <String, dynamic>{
          ...fullJson,
          'version': null,
        };
        expect(TrackModel.fromJson(json).version, 'original');
      });

      test('should default explicit to false when not true', () {
        final json = <String, dynamic>{
          ...fullJson,
          'explicit': null,
        };
        expect(TrackModel.fromJson(json).explicit, false);
      });

      test('should handle missing optional fields', () {
        final json = <String, dynamic>{
          'id': 't-3',
          'release_id': 'r-1',
          'track_number': 1,
          'explicit': false,
          'created_at': now.toIso8601String(),
        };
        final model = TrackModel.fromJson(json);
        expect(model.title, isNull);
        expect(model.isrc, isNull);
        expect(model.audioPath, '');
        expect(model.audioUrl, '');
      });
    });
  });
}
