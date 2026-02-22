class TrackModel {
  final String id;
  final String releaseId;
  final String audioPath;
  final String audioUrl;
  final String? title;
  final int trackNumber;
  final String version;
  final bool explicit;
  final DateTime createdAt;

  const TrackModel({
    required this.id,
    required this.releaseId,
    required this.audioPath,
    required this.audioUrl,
    this.title,
    required this.trackNumber,
    this.version = 'original',
    required this.explicit,
    required this.createdAt,
  });

  factory TrackModel.fromJson(Map<String, dynamic> json) {
    return TrackModel(
      id: json['id'] as String,
      releaseId: json['release_id'] as String,
      audioPath: (json['audio_path'] ?? json['path']) as String,
      audioUrl: (json['audio_url'] ?? json['file_url'] ?? json['url']) as String,
      title: json['title'] as String?,
      trackNumber: json['track_number'] as int? ?? 0,
      version: json['version'] as String? ?? 'original',
      explicit: json['explicit'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
