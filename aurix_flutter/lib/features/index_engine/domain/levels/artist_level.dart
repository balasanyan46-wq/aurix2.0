/// Artist level by score range. Rookie → Rising → Pro → Top → Elite.
class ArtistLevel {
  final String id;
  final String title;
  final int minScore;
  final int maxScore;
  final List<String> perks;
  final String colorKey;
  final String iconKey;

  const ArtistLevel({
    required this.id,
    required this.title,
    required this.minScore,
    required this.maxScore,
    required this.perks,
    this.colorKey = 'orange',
    this.iconKey = 'star',
  });
}
