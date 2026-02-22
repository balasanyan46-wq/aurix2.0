/// Award category for Aurix Awards.
class AwardCategory {
  final String id;
  final String title;
  final String description;
  final String type; // song, artist, producer, duo
  final bool isPublicVoting;
  final int seasonYear;

  const AwardCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.isPublicVoting,
    required this.seasonYear,
  });
}
