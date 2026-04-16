// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

String createAudioBlobUrl(Uint8List bytes, String? mime) {
  final blob = html.Blob([bytes], mime ?? 'audio/mpeg');
  return html.Url.createObjectUrlFromBlob(blob);
}

void revokeAudioBlobUrl(String url) {
  if (url.isEmpty) return;
  try { html.Url.revokeObjectUrl(url); } catch (_) {}
}
