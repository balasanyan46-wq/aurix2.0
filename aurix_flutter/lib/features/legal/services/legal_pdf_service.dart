import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Генерация PDF и share/download через Printing.
class LegalPdfService {
  static String _fileName(String title) {
    final safe = title.replaceAll(RegExp(r'[^\w\s\-а-яА-ЯёЁ]'), '').replaceAll(RegExp(r'\s+'), '_');
    final truncated = safe.length > 60 ? safe.substring(0, 60) : safe;
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return 'AURIX_${truncated}_$date.pdf';
  }

  /// Генерирует PDF bytes.
  static Future<Uint8List> generatePdfBytes({
    required String title,
    required String body,
  }) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('dd.MM.yyyy').format(DateTime.now());
    final lines = body.split('\n');
    final chunks = <String>[];
    var buf = StringBuffer();
    for (final line in lines) {
      if (buf.length + line.length > 500) {
        chunks.add(buf.toString());
        buf = StringBuffer(line);
      } else {
        if (buf.isNotEmpty) buf.writeln();
        buf.write(line);
      }
    }
    if (buf.isNotEmpty) chunks.add(buf.toString());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.Text('Дата генерации: $dateStr', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ],
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Стр. ${context.pageNumber} из ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.Header(level: 0, child: pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 8),
          pw.Text('Дата: $dateStr', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 16),
          ...chunks.map((c) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(c, style: pw.TextStyle(fontSize: 11)),
              )),
        ],
      ),
    );
    return pdf.save();
  }

  /// Генерирует PDF и вызывает Printing.sharePdf (скачивание на web, share на mobile).
  static Future<bool> sharePdf({
    required BuildContext context,
    required String title,
    required String body,
  }) async {
    final bytes = await generatePdfBytes(title: title, body: body);
    final name = _fileName(title);
    final bounds = Rect.fromLTWH(0, 0, 100, 100);
    return Printing.sharePdf(bytes: bytes, filename: name, bounds: bounds);
  }
}
