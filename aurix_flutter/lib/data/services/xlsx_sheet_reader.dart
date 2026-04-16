import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Минимальный xlsx-reader: достаёт первый лист и возвращает список строк (List<List<String>>).
/// Даты/числа возвращаются как строки — дальше их разбирает тот же CsvReportParser.
class XlsxSheetReader {
  /// Возвращает null если файл не xlsx.
  static List<List<String>>? readFirstSheet(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      // 1. Shared strings (если есть)
      final sharedStrings = <String>[];
      final sstFile = archive.findFile('xl/sharedStrings.xml');
      if (sstFile != null) {
        final content = utf8.decode(sstFile.content as List<int>);
        final doc = XmlDocument.parse(content);
        for (final si in doc.findAllElements('si')) {
          final buf = StringBuffer();
          for (final t in si.findAllElements('t')) {
            buf.write(t.innerText);
          }
          sharedStrings.add(buf.toString());
        }
      }

      // 2. Найти первый лист (sheet1.xml обычно, но пройдём по workbook.xml)
      final wbFile = archive.findFile('xl/workbook.xml');
      String? sheetPath;
      if (wbFile != null) {
        final content = utf8.decode(wbFile.content as List<int>);
        final wbDoc = XmlDocument.parse(content);
        final sheets = wbDoc.findAllElements('sheet');
        if (sheets.isNotEmpty) {
          // берём первый (можно расширить до выбора)
          // r:id → rels → path
          final relId = sheets.first.getAttribute('r:id') ?? sheets.first.getAttribute('id');
          final relsFile = archive.findFile('xl/_rels/workbook.xml.rels');
          if (relId != null && relsFile != null) {
            final relsDoc = XmlDocument.parse(utf8.decode(relsFile.content as List<int>));
            for (final rel in relsDoc.findAllElements('Relationship')) {
              if (rel.getAttribute('Id') == relId) {
                final target = rel.getAttribute('Target');
                if (target != null) {
                  sheetPath = target.startsWith('/') ? target.substring(1) : 'xl/$target';
                }
                break;
              }
            }
          }
        }
      }
      sheetPath ??= 'xl/worksheets/sheet1.xml';

      // 3. Распарсить лист
      final sheetFile = archive.findFile(sheetPath);
      if (sheetFile == null) {
        // Fallback: ищем любой worksheet
        for (final f in archive.files) {
          if (f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml')) {
            return _parseSheetXml(utf8.decode(f.content as List<int>), sharedStrings);
          }
        }
        return null;
      }
      return _parseSheetXml(utf8.decode(sheetFile.content as List<int>), sharedStrings);
    } catch (_) {
      return null;
    }
  }

  static List<List<String>> _parseSheetXml(String xmlStr, List<String> sharedStrings) {
    final doc = XmlDocument.parse(xmlStr);
    final rows = <List<String>>[];

    for (final row in doc.findAllElements('row')) {
      final cellsByCol = <int, String>{};
      int maxCol = 0;

      for (final cell in row.findElements('c')) {
        final ref = cell.getAttribute('r'); // e.g. "A1"
        final colIdx = _columnIndexFromRef(ref) ?? cellsByCol.length;
        final type = cell.getAttribute('t'); // s=shared string, inlineStr, str, b, n (default)

        String value = '';
        if (type == 's') {
          final v = cell.findElements('v').firstOrNull;
          if (v != null) {
            final idx = int.tryParse(v.innerText.trim());
            if (idx != null && idx >= 0 && idx < sharedStrings.length) {
              value = sharedStrings[idx];
            }
          }
        } else if (type == 'inlineStr') {
          final is_ = cell.findElements('is').firstOrNull;
          if (is_ != null) {
            final buf = StringBuffer();
            for (final t in is_.findAllElements('t')) {
              buf.write(t.innerText);
            }
            value = buf.toString();
          }
        } else if (type == 'b') {
          final v = cell.findElements('v').firstOrNull;
          value = v?.innerText.trim() == '1' ? 'TRUE' : 'FALSE';
        } else {
          // number or str
          final v = cell.findElements('v').firstOrNull;
          value = v?.innerText ?? '';
        }

        cellsByCol[colIdx] = value;
        if (colIdx > maxCol) maxCol = colIdx;
      }

      final flat = <String>[];
      for (var i = 0; i <= maxCol; i++) {
        flat.add(cellsByCol[i] ?? '');
      }
      // Пропускаем полностью пустые строки
      if (flat.any((c) => c.trim().isNotEmpty)) rows.add(flat);
    }

    return rows;
  }

  /// "A1" → 0, "B1" → 1, "AA1" → 26
  static int? _columnIndexFromRef(String? ref) {
    if (ref == null || ref.isEmpty) return null;
    int col = 0;
    var hadLetter = false;
    for (final rune in ref.runes) {
      final c = String.fromCharCode(rune);
      if (RegExp(r'[A-Za-z]').hasMatch(c)) {
        col = col * 26 + (c.toUpperCase().codeUnitAt(0) - 64);
        hadLetter = true;
      } else {
        break;
      }
    }
    return hadLetter ? col - 1 : null;
  }

  /// Проверяет по magic bytes что это xlsx (ZIP + content types)
  static bool isXlsx(List<int> bytes) {
    if (bytes.length < 4) return false;
    // ZIP signature: PK\x03\x04 или PK\x05\x06 (empty)
    if (bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04) {
      // Проверим наличие xl/workbook.xml в архиве
      try {
        final archive = ZipDecoder().decodeBytes(bytes);
        return archive.findFile('xl/workbook.xml') != null
            || archive.files.any((f) => f.name.startsWith('xl/'));
      } catch (_) {
        return false;
      }
    }
    return false;
  }
}
