class ReleaseModel {
  final String id;
  final String ownerId;
  final String title;
  final String? artist;
  final String releaseType;
  final DateTime? releaseDate;
  final String? genre;
  final String? language;
  final bool explicit;
  final String? upc;
  final String? label;
  final int? copyrightYear;
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
    this.explicit = false,
    this.upc,
    this.label,
    this.copyrightYear,
    required this.status,
    this.coverUrl,
    this.coverPath,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReleaseModel.fromJson(Map<String, dynamic> json) {
    DateTime? _parseDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return ReleaseModel(
      id: json['id'].toString(),
      ownerId: (json['owner_id'] ?? json['artist_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      artist: json['artist']?.toString(),
      releaseType: (json['release_type'] ?? 'single').toString(),
      releaseDate: _parseDate(json['release_date']),
      genre: json['genre']?.toString(),
      language: json['language']?.toString(),
      explicit: json['explicit'] == true || json['explicit'] == 'true',
      upc: json['upc']?.toString(),
      label: json['label']?.toString(),
      copyrightYear: json['copyright_year'] is num ? (json['copyright_year'] as num).toInt() : int.tryParse(json['copyright_year']?.toString() ?? ''),
      status: (json['status'] ?? 'draft').toString(),
      coverUrl: json['cover_url']?.toString(),
      coverPath: json['cover_path']?.toString(),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updated_at'] ?? json['created_at']) ?? DateTime.now(),
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
        'explicit': explicit,
        'upc': upc,
        'label': label,
        'copyright_year': copyrightYear,
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
    bool? explicit,
    String? upc,
    String? label,
    int? copyrightYear,
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
      explicit: explicit ?? this.explicit,
      upc: upc ?? this.upc,
      label: label ?? this.label,
      copyrightYear: copyrightYear ?? this.copyrightYear,
      status: status ?? this.status,
      coverUrl: coverUrl ?? this.coverUrl,
      coverPath: coverPath ?? this.coverPath,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  bool get isDraft => status == 'draft';
  bool get isSubmitted => status == 'submitted';
  bool get isLive => status == 'live';

  bool get isComplete =>
      title.isNotEmpty &&
      (artist?.isNotEmpty ?? false) &&
      releaseType.isNotEmpty;
}
