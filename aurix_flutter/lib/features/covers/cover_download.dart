import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'cover_download_stub.dart'
    if (dart.library.html) 'cover_download_web.dart'
    if (dart.library.io) 'cover_download_io.dart';

Future<void> downloadCoverPng({
  required BuildContext context,
  required Uint8List bytes,
  String fileName = 'cover.png',
}) async {
  await downloadCoverPngImpl(context: context, bytes: bytes, fileName: fileName);
}

