/// Artist model for Aurix Index.
class Artist {
  final String id;
  final String name;
  final String? avatarUrl;
  final String genrePrimary;
  final String? location;
  final int aurixReleaseCount;
  final DateTime createdAt;

  const Artist({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.genrePrimary,
    this.location,
    required this.aurixReleaseCount,
    required this.createdAt,
  });
}
