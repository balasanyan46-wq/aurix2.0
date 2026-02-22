class FileModel {
  final String id;
  final String ownerId;
  final String? releaseId;
  final String kind; // cover, track
  final String path;
  final String? mime;
  final int? size;
  final DateTime createdAt;

  const FileModel({
    required this.id,
    required this.ownerId,
    this.releaseId,
    required this.kind,
    required this.path,
    this.mime,
    this.size,
    required this.createdAt,
  });

  factory FileModel.fromJson(Map<String, dynamic> json) {
    return FileModel(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      releaseId: json['release_id'] as String?,
      kind: json['kind'] as String,
      path: json['path'] as String,
      mime: json['mime'] as String?,
      size: json['size'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner_id': ownerId,
        'release_id': releaseId,
        'kind': kind,
        'path': path,
        'mime': mime,
        'size': size,
        'created_at': createdAt.toIso8601String(),
      };
}
