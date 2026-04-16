import 'dart:convert';
import 'xlsx_sheet_reader.dart';

class CsvParseResult {
  final List<Map<String, dynamic>> rows;
  final List<String> detectedHeaders;
  final Map<String, int> columnMap;
  final String? error;

  CsvParseResult({required this.rows, this.detectedHeaders = const [], this.columnMap = const {}, this.error});

  bool get hasData => rows.isNotEmpty;
}

/// Parses distributor CSV reports into normalized rows.
/// Auto-detects delimiter, UTF-8+BOM, and common column names.
class CsvReportParser {
  static const _bom = '\uFEFF';

  /// Parse CSV or XLSX bytes and return detailed result with error info.
  static CsvParseResult parseWithDetails(
    List<int> bytes, {
    DateTime? periodStart,
    DateTime? periodEnd,
  }) {
    // XLSX: декодируем в строки/ячейки и дальше работаем как с уже разобранным CSV
    if (XlsxSheetReader.isXlsx(bytes)) {
      final sheet = XlsxSheetReader.readFirstSheet(bytes);
      if (sheet == null || sheet.isEmpty) {
        return CsvParseResult(rows: [], error: 'Не удалось прочитать xlsx-файл');
      }
      return _parseMatrix(sheet);
    }

    String text;
    try {
      text = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return CsvParseResult(rows: [], error: 'Не удалось прочитать файл (кодировка)');
    }
    text = text.replaceFirst(_bom, '');
    if (text.trim().isEmpty) {
      return CsvParseResult(rows: [], error: 'Файл пуст');
    }

    final lines = text.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 2) {
      return CsvParseResult(rows: [], error: 'Нужен заголовок и хотя бы 1 строка данных. Найдено строк: ${lines.length}');
    }

    final delimiter = _detectDelimiter(lines.first);
    final headers = _parseLine(lines.first, delimiter);
    if (headers.isEmpty) {
      return CsvParseResult(rows: [], error: 'Не удалось разделить заголовок');
    }

    final colMap = _buildColumnMap(headers);

    if (!colMap.containsKey('streams') && !colMap.containsKey('revenue')) {
      return CsvParseResult(
        rows: [],
        detectedHeaders: headers,
        columnMap: colMap,
        error: 'Не найдены колонки streams или revenue.\n'
            'Найденные колонки: ${headers.join(", ")}\n\n'
            'CSV должен содержать хотя бы одну из колонок:\n'
            '• streams / plays / quantity / count\n'
            '• revenue / earnings / amount / royalty',
      );
    }

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

    if (rows.isEmpty) {
      return CsvParseResult(
        rows: [],
        detectedHeaders: headers,
        columnMap: colMap,
        error: 'Колонки найдены, но все строки пустые (streams=0, revenue=0).\n'
            'Проверьте формат чисел в файле.',
      );
    }

    return CsvParseResult(rows: rows, detectedHeaders: headers, columnMap: colMap);
  }

  /// Работает с уже разобранной 2D-матрицей (например, результат xlsx reader).
  static CsvParseResult _parseMatrix(List<List<String>> matrix) {
    if (matrix.length < 2) {
      return CsvParseResult(rows: [], error: 'Нужен заголовок и хотя бы 1 строка данных. Найдено строк: ${matrix.length}');
    }
    final headers = matrix.first.map((h) => h.trim()).toList();
    if (headers.isEmpty) {
      return CsvParseResult(rows: [], error: 'Не удалось разделить заголовок');
    }
    final colMap = _buildColumnMap(headers);
    if (!colMap.containsKey('streams') && !colMap.containsKey('revenue')) {
      return CsvParseResult(
        rows: [],
        detectedHeaders: headers,
        columnMap: colMap,
        error: 'Не найдены колонки streams или revenue.\n'
            'Найденные колонки: ${headers.join(", ")}\n\n'
            'Проверьте, что в файле есть колонка с количеством прослушиваний или вознаграждением.',
      );
    }
    final rows = <Map<String, dynamic>>[];
    for (var i = 1; i < matrix.length; i++) {
      final parts = matrix[i];
      if (parts.every((c) => c.trim().isEmpty)) continue;
      final raw = <String, dynamic>{};
      for (var j = 0; j < parts.length && j < headers.length; j++) {
        raw[headers[j]] = parts[j];
      }
      final row = _mapToRow(colMap, parts, headers, raw);
      if (row != null) rows.add(row);
    }
    if (rows.isEmpty) {
      return CsvParseResult(
        rows: [],
        detectedHeaders: headers,
        columnMap: colMap,
        error: 'Колонки найдены, но все строки пустые (streams=0, revenue=0).',
      );
    }
    return CsvParseResult(rows: rows, detectedHeaders: headers, columnMap: colMap);
  }

  /// Legacy method for backward compatibility.
  static List<Map<String, dynamic>> parse(
    List<int> bytes, {
    DateTime? periodStart,
    DateTime? periodEnd,
  }) {
    return parseWithDetails(bytes, periodStart: periodStart, periodEnd: periodEnd).rows;
  }

  /// Converts partial dates like "2025-06", "06.2025", "2025-4 кв." to ISO "YYYY-MM-DD".
  /// Quarter notation maps to the first day of the quarter:
  ///   Q1 → Jan, Q2 → Apr, Q3 → Jul, Q4 → Oct.
  static String? _normalizeDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final s = raw.trim();

    // Already full ISO date: 2025-06-01
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return s;

    // Quarter: "2025-4 кв.", "2025-IV кв.", "2025-4 квартал", "Q4 2025"
    final qCyr = RegExp(r'^(\d{4})[-\s]?(\d|[IV]{1,4})\s*кв\.?', caseSensitive: false).firstMatch(s);
    if (qCyr != null) {
      final year = qCyr.group(1)!;
      final q = _parseQuarter(qCyr.group(2)!);
      if (q != null) return '$year-${_quarterMonth(q).toString().padLeft(2, '0')}-01';
    }
    final qEn = RegExp(r'^Q(\d)\s*(\d{4})$', caseSensitive: false).firstMatch(s);
    if (qEn != null) {
      final q = int.tryParse(qEn.group(1)!);
      if (q != null && q >= 1 && q <= 4) return '${qEn.group(2)}-${_quarterMonth(q).toString().padLeft(2, '0')}-01';
    }

    // YYYY-MM → YYYY-MM-01 (supports "2026-01" and "2026-1")
    final ym = RegExp(r'^(\d{4})-(\d{1,2})$').firstMatch(s);
    if (ym != null) {
      final year = ym.group(1)!;
      final month = ym.group(2)!.padLeft(2, '0');
      return '$year-$month-01';
    }

    // MM.YYYY or MM/YYYY → YYYY-MM-01
    final dotMatch = RegExp(r'^(\d{1,2})[./](\d{4})$').firstMatch(s);
    if (dotMatch != null) {
      final month = dotMatch.group(1)!.padLeft(2, '0');
      final year = dotMatch.group(2)!;
      return '$year-$month-01';
    }

    // DD.MM.YYYY or DD/MM/YYYY → YYYY-MM-DD
    final fullDot = RegExp(r'^(\d{1,2})[./](\d{1,2})[./](\d{4})$').firstMatch(s);
    if (fullDot != null) {
      final day = fullDot.group(1)!.padLeft(2, '0');
      final month = fullDot.group(2)!.padLeft(2, '0');
      final year = fullDot.group(3)!;
      return '$year-$month-$day';
    }

    // Try parsing as-is; if fails, return null to avoid DB error
    try {
      DateTime.parse(s);
      return s;
    } catch (_) {
      return null;
    }
  }

  static int? _parseQuarter(String raw) {
    final s = raw.trim().toUpperCase();
    final num = int.tryParse(s);
    if (num != null && num >= 1 && num <= 4) return num;
    switch (s) {
      case 'I': return 1;
      case 'II': return 2;
      case 'III': return 3;
      case 'IV': return 4;
      default: return null;
    }
  }

  static int _quarterMonth(int q) => (q - 1) * 3 + 1;

  static String _detectDelimiter(String line) {
    final tab = '\t'.allMatches(line).length;
    final comma = ','.allMatches(line).length;
    final semicolon = ';'.allMatches(line).length;
    if (tab > comma && tab > semicolon) return '\t';
    return semicolon > comma ? ';' : ',';
  }

  static List<String> _parseLine(String line, String delimiter) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == delimiter && !inQuotes) {
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
    if (t.length >= 2 && ((t.startsWith('"') && t.endsWith('"')) || (t.startsWith("'") && t.endsWith("'")))) {
      t = t.substring(1, t.length - 1);
    }
    return t.trim();
  }

  static Map<String, int> _buildColumnMap(List<String> headers) {
    final map = <String, int>{};
    final lower = headers.map((h) => h.toLowerCase().trim()).toList();
    final patterns = {
      'isrc': ['isrc контента', 'isrc', 'isrc code', 'isrc_id'],
      'track_title': ['название трека', 'track title', 'track_title', 'track', 'title', 'song', 'name', 'трек', 'название'],
      'streams': ['количество загрузок/прослушиваний', 'количество загрузок', 'количество прослушиваний', 'streams', 'stream', 'quantity', 'count', 'plays', 'прослушивания', 'кол-во'],
      'revenue': ['итого вознаграждение лицензиара', 'вознаграждение лицензиара', 'итого вознаграждение с площадок', 'итого вознаграждение', 'вознаграждение', 'revenue', 'earnings', 'amount', 'royalty', 'payment', 'доход', 'выручка', 'сумма'],
      'platform': ['площадка', 'platform', 'service', 'store', 'source', 'платформа', 'сервис'],
      'country': ['территория', 'country', 'territory', 'region', 'страна', 'регион'],
      'date': ['период использования контента', 'период использования', 'period', 'date', 'report_date', 'report date', 'дата', 'период'],
      'currency': ['currency', 'curr', 'валюта'],
      'artist': ['исполнитель', 'artist', 'артист'],
      'album': ['название альбома', 'album', 'альбом'],
      'upc': ['upc альбома', 'upc'],
    };
    for (final e in patterns.entries) {
      for (final p in e.value) {
        final idx = lower.indexWhere((h) => h == p || h.startsWith(p) || p.startsWith(h));
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
      return int.tryParse(cleaned) ?? double.tryParse(cleaned)?.toInt() ?? 0;
    }
    double parseDouble(String? s) {
      if (s == null || s.isEmpty) return 0;
      final cleaned = s.replaceAll(',', '.').replaceAll(RegExp(r'\s'), '');
      return double.tryParse(cleaned) ?? 0;
    }

    final streams = parseInt(get(colMap['streams']));
    final revenue = parseDouble(get(colMap['revenue']));
    if (streams == 0 && revenue == 0) return null;

    final isRussianFormat = colMap.containsKey('artist') || headers.any((h) => h.toLowerCase().contains('лицензиар'));
    final currency = get(colMap['currency']) ?? (isRussianFormat ? 'RUB' : 'USD');

    return {
      'report_date': _normalizeDate(get(colMap['date'])),
      'track_title': get(colMap['track_title']),
      'isrc': get(colMap['isrc']),
      'platform': get(colMap['platform']),
      'country': get(colMap['country']),
      'streams': streams,
      'revenue': revenue,
      'currency': currency,
      'raw_row_json': raw,
    };
  }
}
