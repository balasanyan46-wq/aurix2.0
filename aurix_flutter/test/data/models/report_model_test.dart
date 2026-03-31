import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/data/models/report_model.dart';
import 'package:aurix_flutter/data/models/report_row_model.dart';

void main() {
  group('ReportModel', () {
    final now = DateTime(2025, 1, 15, 12, 0, 0);
    final fullJson = <String, dynamic>{
      'id': 'rp-1',
      'period_start': '2025-01-01T00:00:00.000',
      'period_end': '2025-01-31T00:00:00.000',
      'distributor': 'distrokid',
      'file_name': 'report.csv',
      'file_url': 'https://example.com/report.csv',
      'status': 'processed',
      'created_by': 'admin-1',
      'user_id': 'u-1',
      'release_id': 'r-1',
      'created_at': now.toIso8601String(),
    };

    group('fromJson', () {
      test('should parse all fields from complete JSON', () {
        final model = ReportModel.fromJson(fullJson);

        expect(model.id, 'rp-1');
        expect(model.periodStart, DateTime(2025, 1, 1));
        expect(model.periodEnd, DateTime(2025, 1, 31));
        expect(model.distributor, 'distrokid');
        expect(model.fileName, 'report.csv');
        expect(model.fileUrl, 'https://example.com/report.csv');
        expect(model.status, 'processed');
        expect(model.createdBy, 'admin-1');
        expect(model.userId, 'u-1');
        expect(model.releaseId, 'r-1');
        expect(model.createdAt, now);
      });

      test('should apply defaults for missing fields', () {
        final model = ReportModel.fromJson({'id': 'rp-2'});

        expect(model.distributor, 'zvonko');
        expect(model.fileName, isNull);
        expect(model.fileUrl, isNull);
        expect(model.status, 'uploaded');
        expect(model.createdBy, isNull);
        expect(model.userId, isNull);
        expect(model.releaseId, isNull);
      });
    });
  });

  group('ReportRowModel', () {
    final now = DateTime(2025, 1, 15, 12, 0, 0);
    final fullJson = <String, dynamic>{
      'id': 'rr-1',
      'report_id': 'rp-1',
      'report_date': '2025-01-15',
      'track_title': 'My Track',
      'isrc': 'US1234567890',
      'platform': 'spotify',
      'country': 'RU',
      'streams': 1500,
      'revenue': 12.50,
      'currency': 'EUR',
      'track_id': 't-1',
      'user_id': 'u-1',
      'release_id': 'r-1',
      'raw_row_json': {'col1': 'val1'},
      'created_at': now.toIso8601String(),
    };

    group('fromJson', () {
      test('should parse all fields from complete JSON', () {
        final model = ReportRowModel.fromJson(fullJson);

        expect(model.id, 'rr-1');
        expect(model.reportId, 'rp-1');
        expect(model.reportDate, DateTime(2025, 1, 15));
        expect(model.trackTitle, 'My Track');
        expect(model.isrc, 'US1234567890');
        expect(model.platform, 'spotify');
        expect(model.country, 'RU');
        expect(model.streams, 1500);
        expect(model.revenue, 12.50);
        expect(model.currency, 'EUR');
        expect(model.trackId, 't-1');
        expect(model.userId, 'u-1');
        expect(model.releaseId, 'r-1');
        expect(model.rawRowJson, {'col1': 'val1'});
        expect(model.createdAt, now);
      });

      test('should apply defaults for missing numeric and optional fields', () {
        final model = ReportRowModel.fromJson({'id': 'rr-2', 'report_id': 'rp-1'});

        expect(model.reportDate, isNull);
        expect(model.trackTitle, isNull);
        expect(model.streams, 0);
        expect(model.revenue, 0);
        expect(model.currency, 'USD');
        expect(model.rawRowJson, isNull);
      });

      test('should handle num types for streams and revenue', () {
        final json = <String, dynamic>{
          ...fullJson,
          'streams': 100.0,   // double
          'revenue': 5,       // int
        };
        final model = ReportRowModel.fromJson(json);
        expect(model.streams, 100);
        expect(model.revenue, 5.0);
      });
    });
  });
}
