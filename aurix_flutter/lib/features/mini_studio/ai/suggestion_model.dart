/// Types of AI suggestions.
enum SuggestionType { timing, vocal, structure, mix }

/// Action the suggestion performs when accepted.
enum SuggestionAction {
  fixTiming,
  addDouble,
  enhance,
  addAdlib,
  boostVocal,
  addReverb,
}

/// A single AI Producer suggestion anchored to a timeline position.
class AiSuggestion {
  final String id;
  final String text;
  final SuggestionType type;
  final double position; // seconds on timeline
  final SuggestionAction action;
  final String? targetTrackId;
  final String? targetClipId;
  bool dismissed;

  AiSuggestion({
    required this.id,
    required this.text,
    required this.type,
    required this.position,
    required this.action,
    this.targetTrackId,
    this.targetClipId,
    this.dismissed = false,
  });
}
