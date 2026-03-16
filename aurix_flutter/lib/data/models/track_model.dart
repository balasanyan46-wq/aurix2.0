class TrackModel {
  final String id;
  final String releaseId;
  final String audioPath;
  final String audioUrl;
  final String? title;
  final String? isrc;
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
    this.isrc,
    required this.trackNumber,
    this.version = 'original',
    required this.explicit,
    required this.createdAt,
  });

  factory TrackModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return TrackModel(
      id: (json['id'])?.toString() ?? '',
      releaseId: (json['release_id'])?.toString() ?? '',
      audioPath: (json['audio_path'] ?? json['path'] ?? '').toString(),
      audioUrl: (json['audio_url'] ?? json['file_url'] ?? json['url'] ?? '').toString(),
      title: json['title']?.toString(),
      isrc: json['isrc']?.toString(),
      trackNumber: json['track_number'] is int ? json['track_number'] : int.tryParse(json['track_number']?.toString() ?? '') ?? 0,
      version: json['version']?.toString() ?? 'original',
      explicit: json['explicit'] == true,
      createdAt: json['created_at'] != null ? (DateTime.tryParse(json['created_at'].toString()) ?? now) : now,
    );
  }
}
