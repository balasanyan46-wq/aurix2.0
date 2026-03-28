import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:aurix_flutter/core/api/api_client.dart';

class FileRepository {
  static const coversBucket = 'covers';
  static const tracksBucket = 'tracks';

  /// Sanitize filename: only [a-zA-Z0-9._-], spaces → '_'
  static String _sanitizeFileName(String name) {
    return name
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '')
        .replaceAll(RegExp(r'_+'), '_');
  }

  Future<({String coverPath, String publicUrl})> uploadCoverBytes(
    String userId,
    String releaseId,
    Uint8List bytes,
    String fileName,
  ) async {
    if (userId.trim().isEmpty || releaseId.trim().isEmpty) {
      throw ArgumentError('userId/releaseId must not be empty');
    }
    if (bytes.isEmpty) {
      throw ArgumentError('Cover bytes must not be empty');
    }
    final safeName = _sanitizeFileName(fileName);

    final res = await ApiClient.uploadFile(
      '/upload/cover',
      bytes,
      safeName,
      fieldName: 'file',
    );
    final body = _asMap(res.data);
    // Backend may return {url} or {path, url}
    final url = (body['url'] ?? body['publicUrl'] ?? '').toString();
    final path = (body['path'] ?? body['coverPath'] ?? url).toString();
    return (coverPath: path, publicUrl: url);
  }

  Future<({String path, String publicUrl})> uploadTrackBytes(
    String userId,
    String releaseId,
    String trackId,
    Uint8List bytes,
    String ext,
  ) async {
    if (userId.trim().isEmpty ||
        releaseId.trim().isEmpty ||
        trackId.trim().isEmpty) {
      throw ArgumentError('userId/releaseId/trackId must not be empty');
    }
    if (bytes.isEmpty) {
      throw ArgumentError('Track bytes must not be empty');
    }
    final safeExt = ext.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final fileName = '$trackId.$safeExt';

    final res = await ApiClient.uploadFile(
      '/upload/audio',
      bytes,
      fileName,
      fieldName: 'file',
    );
    final body = _asMap(res.data);
    final url = (body['url'] ?? body['publicUrl'] ?? '').toString();
    final path = (body['path'] ?? url).toString();
    return (path: path, publicUrl: url);
  }

  Future<void> removeFromStorage(String bucket, String path) async {
    if (bucket.trim().isEmpty || path.trim().isEmpty) return;
    try {
      await ApiClient.delete('/upload/$bucket/$path');
    } catch (e) {
      debugPrint('[FileRepository] removeFromStorage failed: $e');
    }
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }
}
