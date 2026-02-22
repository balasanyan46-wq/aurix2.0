import 'dart:io' if (dart.library.html) 'package:aurix_flutter/io_stub.dart' show File;
import 'dart:typed_data';

import 'package:aurix_flutter/core/supabase_diagnostics.dart';
import 'package:aurix_flutter/data/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:aurix_flutter/data/models/file_model.dart';

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

  Future<FileModel> saveFileRecord({
    required String ownerId,
    required String path,
    required String kind,
    String? releaseId,
    String? mime,
    int? size,
  }) async {
    final payload = <String, dynamic>{
      'owner_id': ownerId,
      'kind': kind,
      'path': path,
    };
    if (releaseId != null) payload['release_id'] = releaseId;
    if (mime != null) payload['mime'] = mime;
    if (size != null) payload['size'] = size;
    logSupabaseRequest(table: 'files', operation: 'insert', payload: payload, userId: ownerId);
    final res = await supabase.from('files').insert(payload).select().single();
    return FileModel.fromJson(res as Map<String, dynamic>);
  }

  /// Загружает обложку в covers/{userId}/{releaseId}/cover.<ext>
  /// Возвращает (coverPath для БД, publicUrl).
  Future<({String coverPath, String publicUrl})> uploadCover(String userId, String releaseId, File file, {String? customName}) async {
    final ext = file.path.split('.').last.toLowerCase();
    final name = customName ?? 'cover.$ext';
    final path = '$userId/$releaseId/$name';
    await supabase.storage.from(coversBucket).upload(path, file, fileOptions: FileOptions(upsert: true));
    final publicUrl = supabase.storage.from(coversBucket).getPublicUrl(path);
    return (coverPath: path, publicUrl: publicUrl);
  }

  /// Загружает обложку (bytes) в covers/{userId}/{releaseId}/<sanitized_name>
  Future<({String coverPath, String publicUrl})> uploadCoverBytes(String userId, String releaseId, Uint8List bytes, String originalName) async {
    final ext = originalName.contains('.')
        ? originalName.split('.').last.toLowerCase()
        : 'jpg';
    final safeExt = _sanitizeFileName(ext).isEmpty ? 'jpg' : ext;
    final name = 'cover.$safeExt';
    final path = '$userId/$releaseId/$name';
    final contentType = _coverContentType(safeExt);
    await supabase.storage.from(coversBucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        upsert: true,
        contentType: contentType ?? 'image/jpeg',
      ),
    );
    final publicUrl = supabase.storage.from(coversBucket).getPublicUrl(path);
    return (coverPath: path, publicUrl: publicUrl);
  }

  String getCoverPublicUrl(String storagePath) => supabase.storage.from(coversBucket).getPublicUrl(storagePath);
  String getTrackPublicUrl(String storagePath) => supabase.storage.from(tracksBucket).getPublicUrl(storagePath);

  /// Загружает трек в tracks/{userId}/{releaseId}/{trackId}.ext
  Future<String> uploadTrack(String userId, String releaseId, String trackId, File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    final path = '$userId/$releaseId/$trackId.$ext';
    await supabase.storage.from(tracksBucket).upload(path, file, fileOptions: FileOptions(upsert: true));
    return supabase.storage.from(tracksBucket).getPublicUrl(path);
  }

  /// Загружает трек (bytes) в tracks/{userId}/{releaseId}/{trackId}.ext
  Future<({String path, String publicUrl})> uploadTrackBytes(
    String userId,
    String releaseId,
    String trackId,
    Uint8List bytes,
    String extension,
  ) async {
    final ext = _sanitizeFileName(extension).isEmpty ? 'wav' : extension.toLowerCase();
    final path = '$userId/$releaseId/$trackId.$ext';
    final contentType = _audioContentType(ext);
    await supabase.storage.from(tracksBucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        upsert: true,
        contentType: contentType ?? 'audio/wav',
      ),
    );
    final publicUrl = supabase.storage.from(tracksBucket).getPublicUrl(path);
    return (path: path, publicUrl: publicUrl);
  }

  Future<List<FileModel>> getFilesByRelease(String releaseId) async {
    final res = await supabase.from('files').select().eq('release_id', releaseId);
    return (res as List).map((e) => FileModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> removeFromStorage(String bucket, String path) async {
    await supabase.storage.from(bucket).remove([path]);
  }

  Future<String?> getSignedUrl(String bucket, String path, {int expiresIn = 3600}) async {
    try {
      final url = await supabase.storage.from(bucket).createSignedUrl(path, expiresIn);
      return url;
    } catch (_) {
      return null;
    }
  }
}
