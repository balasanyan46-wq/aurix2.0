import 'dart:convert';

/// Parses distributor CSV reports into normalized rows.
/// Auto-detects delimiter, UTF-8+BOM, and common column names.
class CsvReportParser {
  static const _bom = '\uFEFF';

  /// Parse CSV bytes into list of row maps.
  /// Columns: report_date, track_title, isrc, platform, country, streams, revenue, currency, raw_row_json
  static List<Map<String, dynamic>> parse(
    List<int> bytes, {
    DateTime? periodStart,
    DateTime? periodEnd,
  }) {
    String text;
    try {
      text = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return [];
    }
    text = text.replaceFirst(_bom, '');
    if (text.trim().isEmpty) return [];

    final lines = text.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];

    final delimiter = _detectDelimiter(lines.first);
    final headerLine = lines.first;
    final headers = _parseLine(headerLine, delimiter);
    if (headers.isEmpty) return [];

    final colMap = _buildColumnMap(headers);
    final rows = <Map<String, dynamic>>[];

    for (var i = 1; i < lines.length; i++) {
      final parts = _parseLine(lines[i], delimiter);
      if (parts.isEmpty) continue;
      final raw = <String, dynamic>{};
      for (var j = 0; j < parts.length && j < headers.length; j++) {
        raw[headers[j]] = parts[j];
      }
      final row = _mapToRow(colMap, parts, headers, raw);
      if (row != null) rows.add(row);
    }
    return rows;
  }

  static String _detectDelimiter(String line) {
    final commaCount = ','.allMatches(line).length;
    final semicolonCount = ';'.allMatches(line).length;
    return semicolonCount > commaCount ? ';' : ',';
  }

  static List<String> _parseLine(String line, String delimiter) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if ((c == delimiter || c == ',') && !inQuotes) {
        result.add(_cleanCell(current.toString()));
        current = StringBuffer();
      } else {
        current.write(c);
      }
    }
    result.add(_cleanCell(current.toString()));
    return result;
  }

  static String _cleanCell(String s) {
    var t = s.trim();
    if (t.startsWith('"') || t.startsWith("'")) t = t.substring(1);
    if (t.endsWith('"') || t.endsWith("'")) t = t.substring(0, t.length - 1);
    return t;
  }

  static Map<String, int> _buildColumnMap(List<String> headers) {
    final map = <String, int>{};
    final lower = headers.map((h) => h.toLowerCase().trim()).toList();
    final patterns = {
      'isrc': ['isrc', 'isrc code', 'isrc_id'],
      'track_title': ['track', 'title', 'track title', 'track_title', 'song', 'name'],
      'streams': ['streams', 'stream', 'quantity', 'count', 'plays'],
      'revenue': ['revenue', 'earnings', 'amount', 'royalty', 'payment'],
      'platform': ['platform', 'service', 'store', 'source'],
      'country': ['country', 'territory', 'region'],
      'date': ['date', 'period', 'report_date'],
      'currency': ['currency', 'curr'],
    };
    for (final e in patterns.entries) {
      for (final p in e.value) {
        final idx = lower.indexWhere((h) => h.contains(p) || p.contains(h));
        if (idx >= 0 && !map.containsKey(e.key)) {
          map[e.key] = idx;
          break;
        }
      }
    }
    return map;
  }

  static Map<String, dynamic>? _mapToRow(
    Map<String, int> colMap,
    List<String> parts,
    List<String> headers,
    Map<String, dynamic> raw,
  ) {
    String? get(int? idx) => idx != null && idx < parts.length ? parts[idx].trim() : null;
    int parseInt(String? s) {
      if (s == null || s.isEmpty) return 0;
      final cleaned = s.replaceAll(RegExp(r'[\s,]'), '');
      return int.tryParse(cleaned) ?? 0;
    }
    double parseDouble(String? s) {
      if (s == null || s.isEmpty) return 0;
      final cleaned = s.replaceAll(',', '.').replaceAll(RegExp(r'\s'), '');
      return double.tryParse(cleaned) ?? 0;
    }

    final streams = parseInt(get(colMap['streams']));
    final revenue = parseDouble(get(colMap['revenue']));
    if (streams == 0 && revenue == 0) return null;

    return {
      'report_date': get(colMap['date']),
      'track_title': get(colMap['track_title']),
      'isrc': get(colMap['isrc']),
      'platform': get(colMap['platform']),
      'country': get(colMap['country']),
      'streams': streams,
      'revenue': revenue,
      'currency': get(colMap['currency']) ?? 'USD',
      'raw_row_json': raw,
    };
  }
}
