class ReleaseModel {
  final String id;
  final String ownerId;
  final String title;
  final String? artist;
  final String releaseType; // single, ep, album
  final DateTime? releaseDate;
  final String? genre;
  final String? language;
  final String status;
  final String? coverUrl;
  final String? coverPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReleaseModel({
    required this.id,
    required this.ownerId,
    required this.title,
    this.artist,
    required this.releaseType,
    this.releaseDate,
    this.genre,
    this.language,
    required this.status,
    this.coverUrl,
    this.coverPath,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReleaseModel.fromJson(Map<String, dynamic> json) {
    return ReleaseModel(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String?,
      releaseType: json['release_type'] as String,
      releaseDate: json['release_date'] != null ? DateTime.parse(json['release_date'] as String) : null,
      genre: json['genre'] as String?,
      language: json['language'] as String?,
      status: json['status'] as String? ?? 'draft',
      coverUrl: json['cover_url'] as String?,
      coverPath: json['cover_path'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner_id': ownerId,
        'title': title,
        'artist': artist,
        'release_type': releaseType,
        'release_date': releaseDate?.toIso8601String().split('T').first,
        'genre': genre,
        'language': language,
        'status': status,
        'cover_url': coverUrl,
        'cover_path': coverPath,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  ReleaseModel copyWith({
    String? title,
    String? artist,
    String? releaseType,
    DateTime? releaseDate,
    String? genre,
    String? language,
    String? status,
    String? coverUrl,
    String? coverPath,
  }) {
    return ReleaseModel(
      id: id,
      ownerId: ownerId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      releaseType: releaseType ?? this.releaseType,
      releaseDate: releaseDate ?? this.releaseDate,
      genre: genre ?? this.genre,
      language: language ?? this.language,
      status: status ?? this.status,
      coverUrl: coverUrl ?? this.coverUrl,
      coverPath: coverPath ?? this.coverPath,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  bool get isDraft => status == 'draft';
  bool get isSubmitted => status == 'submitted';
}
