import 'dart:typed_data';

import 'package:aurix_flutter/core/supabase_diagnostics.dart';
import 'package:aurix_flutter/data/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

class FileRepository {
  static const coversBucket = 'covers';
  static const tracksBucket = 'tracks';

  /// Санитизация имени файла: только [a-zA-Z0-9._-], пробелы → '_'
  static String _sanitizeFileName(String name) {
    return name
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '')
        .replaceAll(RegExp(r'_+'), '_');
  }

  static String? _coverContentType(String ext) {
    final e = ext.toLowerCase();
    if (e == 'jpg' || e == 'jpeg') return 'image/jpeg';
    if (e == 'png') return 'image/png';
    return null;
  }

  static String? _audioContentType(String ext) {
    final e = ext.toLowerCase();
    if (e == 'mp3') return 'audio/mpeg';
    if (e == 'wav') return 'audio/wav';
    if (e == 'flac') return 'audio/flac';
    if (e == 'm4a') return 'audio/mp4';
    return null;
  }

  Future<({String coverPath, String publicUrl})> uploadCoverBytes(
    String userId,
    String releaseId,
    Uint8List bytes,
    String fileName,
  ) async {
    final safeName = _sanitizeFileName(fileName);
    final ext = safeName.split('.').lastOrNull ?? 'jpg';
    final path = '$userId/$releaseId/cover.$ext';
    final contentType = _coverContentType(ext);

    logSupabaseRequest(
      table: 'storage/$coversBucket',
      operation: 'upload',
      payload: {'path': path},
      userId: userId,
    );

    await supabase.storage.from(coversBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: contentType,
          ),
        );

    final publicUrl = supabase.storage.from(coversBucket).getPublicUrl(path);
    return (coverPath: path, publicUrl: publicUrl);
  }

  Future<({String path, String publicUrl})> uploadTrackBytes(
    String userId,
    String releaseId,
    String trackId,
    Uint8List bytes,
    String ext,
  ) async {
    final safeExt = ext.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final path = '$userId/$releaseId/$trackId.$safeExt';
    final contentType = _audioContentType(safeExt);

    logSupabaseRequest(
      table: 'storage/$tracksBucket',
      operation: 'upload',
      payload: {'path': path},
      userId: userId,
    );

    await supabase.storage.from(tracksBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: contentType,
          ),
        );

    final publicUrl = supabase.storage.from(tracksBucket).getPublicUrl(path);
    return (path: path, publicUrl: publicUrl);
  }

  Future<void> removeFromStorage(String bucket, String path) async {
    logSupabaseRequest(
      table: 'storage/$bucket',
      operation: 'remove',
      payload: {'path': path},
    );
    await supabase.storage.from(bucket).remove([path]);
  }
}
