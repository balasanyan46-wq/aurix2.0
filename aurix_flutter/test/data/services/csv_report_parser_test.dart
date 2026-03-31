import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/data/services/csv_report_parser.dart';

List<int> _toBytes(String s) => utf8.encode(s);

void main() {
  group('CsvReportParser', () {
    group('parseWithDetails', () {
      test('should parse comma-delimited CSV with streams and revenue', () {
        final csv = 'track_title,streams,revenue\nSong A,1000,50.5\nSong B,2000,100.0\n';
        final result = CsvReportParser.parseWithDetails(_toBytes(csv));

        expect(result.hasData, isTrue);
        expect(result.error, isNull);
        expect(result.rows.length, 2);
        expect(result.rows[0]['track_title'], 'Song A');
        expect(result.rows[0]['streams'], 1000);
        expect(result.rows[0]['revenue'], 50.5);
        expect(result.rows[1]['track_title'], 'Song B');
        expect(result.rows[1]['streams'], 2000);
      });

      test('should parse semicolon-delimited CSV', () {
        final csv = 'track_title;streams;revenue\nSong A;500;25.0\n';
        final result = CsvReportParser.parseWithDetails(_toBytes(csv));

        expect(result.hasData, isTrue);
        expect(result.rows.length, 1);
        expect(result.rows[0]['streams'], 500);
      });

      test('should parse tab-delimited CSV', () {
        final csv = 'track_title\tstreams\trevenue\nSong A\t300\t15.5\n';
        final result = CsvReportParser.parseWithDetails(_toBytes(csv));

        expect(result.hasData, isTrue);
        expect(result.rows.length, 1);
        expect(result.rows[0]['streams'], 300);
      });

      test('should strip BOM from UTF-8 content', () {
        final csv = '\uFEFFtrack_title,streams,revenue\nSong A,100,5.0\n';
        final result = CsvReportParser.parseWithDetails(_toBytes(csv));

        expect(result.hasData, isTrue);
        expect(result.rows.length, 1);
      });

      test('should return error for empty file', () {
        final result = CsvReportParser.parseWithDetails(_toBytes(''));
        expect(result.hasData, isFalse);
        expect(result.error, contains('пуст'));
      });

      test('should return error for header-only file', () {
        final csv = 'track_title,streams,revenue\n';
        final result = CsvReportParser.parseWithDetails(_toBytes(csv));
        expect(result.hasData, isFalse);
        expect(result.error, isNotNull);
      });

      test('should return error when streams and revenue columns missing', () {
        final csv = 'name,country\nSong A,US\n';
        final result = CsvReportParser.parseWithDetails(_toBytes(csv));
        expect(result.hasData, isFalse);
        expect(result.error, contains('streams'));
        expect(result.error, contains('revenue'));
      });

      test('should skip rows where streams and revenue are both 0', () {
        final csv = 'track_title,streams,revenue\nSong A,0,0\nSong B,100,5.0\n';
        final result = CsvReportParser.parseWithDetails(_toBytes(csv));
        expect(result.rows.length, 1);
        expect(result.rows[0]['track_title'], 'Song B');
      });

      test('should return error when all rows are zero', () {
        final csv = 'track_title,streams,revenue\nSong A,0,0\nSong B,0,0\n';
        final result = CsvReportParser.parseWithDetails(_toBytes(csv));
        expect(result.hasData, isFalse);
        expect(result.error, contains('пустые'));
      });

      test('should recognize Russian column headers', () {
        final csv = 'Название трека,Количество прослушиваний,Вознаграждение\nПесня,500,100.0\n';
        final result = CsvReportParser.parseWithDetails(_toBytes(csv));
        expect(result.hasData, isTrue);
        expect(result.rows[0]['streams'], 500);
        expect(result.rows[0]['revenue'], 100.0);
      });

      test('should handle quoted fields with delimiter inside', () {
        final csv = 'track_title,streams,revenue\n"Song, With Comma",300,10.0\n';
        final result = CsvReportParser.parseWithDetails(_toBytes(csv));
        expect(result.hasData, isTrue);
        expect(result.rows[0]['track_title'], 'Song, With Comma');
      });

      test('should detect ISRC column', () {
        final csv = 'isrc,track_title,streams,revenue\nUSXXX1234,Song A,100,5.0\n';
        final result = CsvReportParser.parseWithDetails(_toBytes(csv));
        expect(result.rows[0]['isrc'], 'USXXX1234');
      });

      test('should detect platform column', () {
        final csv = 'track_title,platform,streams,revenue\nSong A,Spotify,100,5.0\n';
        final result = CsvReportParser.parseWithDetails(_toBytes(csv));
        expect(result.rows[0]['platform'], 'Spotify');
      });

      test('should parse revenue with comma decimal separator', () {
        final csv = 'track_title;streams;revenue\nSong A;100;5,50\n';
        final result = CsvReportParser.parseWithDetails(_toBytes(csv));
        expect(result.rows[0]['revenue'], 5.50);
      });

      test('should default currency to USD for non-Russian format', () {
        final csv = 'track_title,streams,revenue\nSong A,100,5.0\n';
        final result = CsvReportParser.parseWithDetails(_toBytes(csv));
        expect(result.rows[0]['currency'], 'USD');
      });

      test('should default currency to RUB for Russian format', () {
        final csv = 'Исполнитель,Название трека,Количество прослушиваний,Вознаграждение\nАртист,Песня,100,50.0\n';
        final result = CsvReportParser.parseWithDetails(_toBytes(csv));
        expect(result.rows[0]['currency'], 'RUB');
      });

      test('should normalize YYYY-MM date to YYYY-MM-01', () {
        final csv = 'track_title,date,streams,revenue\nSong A,2025-06,100,5.0\n';
        final result = CsvReportParser.parseWithDetails(_toBytes(csv));
        expect(result.rows[0]['report_date'], '2025-06-01');
      });

      test('should normalize MM.YYYY date to YYYY-MM-01', () {
        final csv = 'track_title,date,streams,revenue\nSong A,06.2025,100,5.0\n';
        final result = CsvReportParser.parseWithDetails(_toBytes(csv));
        expect(result.rows[0]['report_date'], '2025-06-01');
      });

      test('should normalize DD.MM.YYYY date to YYYY-MM-DD', () {
        final csv = 'track_title,date,streams,revenue\nSong A,15.06.2025,100,5.0\n';
        final result = CsvReportParser.parseWithDetails(_toBytes(csv));
        expect(result.rows[0]['report_date'], '2025-06-15');
      });

      test('should pass through full ISO date unchanged', () {
        final csv = 'track_title,date,streams,revenue\nSong A,2025-06-15,100,5.0\n';
        final result = CsvReportParser.parseWithDetails(_toBytes(csv));
        expect(result.rows[0]['report_date'], '2025-06-15');
      });
    });

    group('parse (legacy)', () {
      test('should return rows list directly', () {
        final csv = 'track_title,streams,revenue\nSong A,100,5.0\n';
        final rows = CsvReportParser.parse(_toBytes(csv));
        expect(rows.length, 1);
        expect(rows[0]['track_title'], 'Song A');
      });

      test('should return empty list for invalid CSV', () {
        final rows = CsvReportParser.parse(_toBytes(''));
        expect(rows, isEmpty);
      });
    });
  });

  group('CsvParseResult', () {
    test('hasData should be true when rows are not empty', () {
      final result = CsvParseResult(rows: [{'a': 1}]);
      expect(result.hasData, isTrue);
    });

    test('hasData should be false when rows are empty', () {
      final result = CsvParseResult(rows: []);
      expect(result.hasData, isFalse);
    });
  });
}
