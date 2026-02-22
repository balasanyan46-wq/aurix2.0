/// Badge earned by rules (rank, growth, consistency, engagement, community).
class Badge {
  final String id;
  final String title;
  final String description;
  final String iconKey;
  final String rarity;
  final String ruleType;

  const Badge({
    required this.id,
    required this.title,
    required this.description,
    required this.iconKey,
    required this.rarity,
    required this.ruleType,
  });
}
