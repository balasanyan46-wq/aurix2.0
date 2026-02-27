import 'dart:typed_data';

import 'package:flutter/material.dart';

Future<void> downloadCoverPngImpl({
  required BuildContext context,
  required Uint8List bytes,
  required String fileName,
}) async {
  throw UnsupportedError('Cover download is not supported on this platform.');
}

