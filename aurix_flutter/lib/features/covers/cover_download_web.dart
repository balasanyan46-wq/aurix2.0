import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';

Future<void> downloadCoverPngImpl({
  required BuildContext context,
  required Uint8List bytes,
  required String fileName,
}) async {
  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final a = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.children.add(a);
  a.click();
  a.remove();
  html.Url.revokeObjectUrl(url);
}

