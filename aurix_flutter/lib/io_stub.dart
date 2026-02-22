// Stub for web builds where dart:io is not available.
// Only used when kIsWeb is true; real File from dart:io is used on mobile.

import 'dart:typed_data';

class File {
  final String path;
  File(this.path);
  Future<Uint8List> readAsBytes() async =>
      throw UnsupportedError('Cannot read files on web');
}
