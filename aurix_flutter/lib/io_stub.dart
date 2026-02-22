// Stub for web builds where dart:io is not available.
// Only used when kIsWeb is true; real File from dart:io is used on mobile.

class File {
  File(String path);
}
