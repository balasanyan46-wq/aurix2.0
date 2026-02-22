import 'dart:convert';

import 'package:aurix_flutter/data/repositories/release_repository.dart';
import 'package:aurix_flutter/data/repositories/track_repository.dart';

/// Сервис экспорта данных релиза для админа.
class ReleaseExportService {
  ReleaseExportService({
    required ReleaseRepository releaseRepository,
    required TrackRepository trackRepository,
  })  : _releaseRepo = releaseRepository,
        _trackRepo = trackRepository;

  final ReleaseRepository _releaseRepo;
  final TrackRepository _trackRepo;

  /// Строит metadata.json для релиза.
  Future<Map<String, dynamic>> buildMetadata(String releaseId) async {
    final release = await _releaseRepo.getRelease(releaseId);
    if (release == null) throw Exception('Релиз не найден');

    final tracks = await _trackRepo.getTracksByRelease(releaseId);

    return {
      'release': {
        'id': release.id,
        'owner_id': release.ownerId,
        'title': release.title,
        'artist': release.artist,
        'release_type': release.releaseType,
        'release_date': release.releaseDate?.toIso8601String(),
        'genre': release.genre,
        'language': release.language,
        'status': release.status,
        'cover_url': release.coverUrl,
        'cover_path': release.coverPath,
        'created_at': release.createdAt.toIso8601String(),
        'updated_at': release.updatedAt.toIso8601String(),
      },
      'tracks': tracks.map((t) => {
        'id': t.id,
        'release_id': t.releaseId,
        'title': t.title,
        'track_number': t.trackNumber,
        'version': t.version,
        'explicit': t.explicit,
        'audio_url': t.audioUrl,
        'audio_path': t.audioPath,
      }).toList(),
    };
  }

  /// Возвращает JSON-строку metadata для скачивания.
  Future<String> getMetadataJson(String releaseId) async {
    final meta = await buildMetadata(releaseId);
    return const JsonEncoder.withIndent('  ').convert(meta);
  }
}
