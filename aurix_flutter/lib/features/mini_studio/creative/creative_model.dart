/// Type of creative generation.
enum CreativeType { hook, line, structure }

/// A single creative suggestion from AI.
class CreativeSuggestion {
  final String id;
  final String text;
  final CreativeType type;
  bool inserted;

  CreativeSuggestion({
    required this.id,
    required this.text,
    required this.type,
    this.inserted = false,
  });
}

/// Context passed to the AI for creative generation.
class CreativeContext {
  final double bpm;
  final String? mood;
  final String? currentLyrics;
  final CreativeType requestType;
  final int vocalTrackCount;
  final double totalDuration;

  const CreativeContext({
    required this.bpm,
    this.mood,
    this.currentLyrics,
    required this.requestType,
    this.vocalTrackCount = 0,
    this.totalDuration = 0,
  });
}
