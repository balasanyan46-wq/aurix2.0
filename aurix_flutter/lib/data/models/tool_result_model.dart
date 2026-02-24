class ToolResultModel {
  final String id;
  final String userId;
  final String releaseId;
  final String toolKey;
  final Map<String, dynamic> input;
  final Map<String, dynamic> output;
  final bool isDemo;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ToolResultModel({
    required this.id,
    required this.userId,
    required this.releaseId,
    required this.toolKey,
    required this.input,
    required this.output,
    required this.isDemo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ToolResultModel.fromJson(Map<String, dynamic> json) {
    return ToolResultModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      releaseId: json['release_id'] as String,
      toolKey: json['tool_key'] as String,
      input: json['input'] as Map<String, dynamic>? ?? {},
      output: json['output'] as Map<String, dynamic>? ?? {},
      isDemo: json['is_demo'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // Growth plan helpers
  String get summary => output['summary'] as String? ?? '';
  Map<String, dynamic> get positioning =>
      output['positioning'] as Map<String, dynamic>? ?? {};
  List<String> get risks =>
      (output['risks'] as List?)?.cast<String>() ?? [];
  List<String> get levers =>
      (output['levers'] as List?)?.cast<String>() ?? [];
  List<String> get contentAngles =>
      (output['content_angles'] as List?)?.cast<String>() ?? [];
  List<String> get quickWins48h =>
      (output['quick_wins_48h'] as List?)?.cast<String>() ?? [];
  List<Map<String, dynamic>> get weeklyFocus =>
      (output['weekly_focus'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  List<Map<String, dynamic>> get days =>
      (output['days'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  List<Map<String, dynamic>> get checkpoints =>
      (output['checkpoints'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  // Budget helpers
  List<Map<String, dynamic>> get allocation =>
      (output['allocation'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  List<String> get dontSpendOn =>
      (output['dont_spend_on'] as List?)?.cast<String>() ?? [];
  List<String> get mustSpendOn =>
      (output['must_spend_on'] as List?)?.cast<String>() ?? [];
  List<String> get mustDo =>
      (output['must_do'] as List?)?.cast<String>() ?? [];
  List<String> get antiWaste =>
      (output['anti_waste'] as List?)?.cast<String>() ?? [];
  String get cheapestStrategy =>
      output['cheapest_strategy'] as String? ?? '';
  List<String> get nextSteps =>
      (output['next_steps'] as List?)?.cast<String>() ?? [];

  // Packaging helpers
  List<String> get titleVariants =>
      (output['title_variants'] as List?)?.cast<String>() ?? [];
  Map<String, dynamic> get descriptionPlatforms =>
      output['description_platforms'] as Map<String, dynamic>? ?? {};
  String get storytelling =>
      output['storytelling'] as String? ?? '';
  List<String> get hooks =>
      (output['hooks'] as List?)?.cast<String>() ?? [];
  List<String> get ctaVariants =>
      (output['cta_variants'] as List?)?.cast<String>() ?? [];

  // Content plan helpers
  String get strategy =>
      output['strategy'] as String? ?? '';
  List<Map<String, dynamic>> get contentDays =>
      (output['days'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  // Pitch pack helpers
  String get shortPitch =>
      output['short_pitch'] as String? ?? '';
  String get longPitch =>
      output['long_pitch'] as String? ?? '';
  List<String> get emailSubjects =>
      (output['email_subjects'] as List?)?.cast<String>() ?? [];
  List<String> get pressLines =>
      (output['press_lines'] as List?)?.cast<String>() ?? [];
  String get artistBio =>
      output['artist_bio'] as String? ?? '';
}
