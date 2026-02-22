/// Badge that can be earned by artists.
class Badge {
  final String id;
  final String title;
  final String description;
  final String iconKey;
  final String rarity; // common, rare, epic
  final String ruleType; // rank, growth, consistency, viral

  const Badge({
    required this.id,
    required this.title,
    required this.description,
    required this.iconKey,
    required this.rarity,
    required this.ruleType,
  });
}
