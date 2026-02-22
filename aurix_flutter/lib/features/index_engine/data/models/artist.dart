/// Artist model for Index Engine. Mirrors index feature for compatibility.
class Artist {
  final String id;
  final String name;
  final String? avatarUrl;
  final String genrePrimary;
  final String? region;
  final DateTime createdAt;

  const Artist({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.genrePrimary,
    this.region,
    required this.createdAt,
  });
}
