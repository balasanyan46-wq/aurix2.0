class GrowthPlanModel {
  final String id;
  final String userId;
  final String releaseId;
  final bool isDemo;
  final Map<String, dynamic> input;
  final Map<String, dynamic> plan;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GrowthPlanModel({
    required this.id,
    required this.userId,
    required this.releaseId,
    required this.isDemo,
    required this.input,
    required this.plan,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GrowthPlanModel.fromJson(Map<String, dynamic> json) {
    return GrowthPlanModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      releaseId: json['release_id'] as String,
      isDemo: json['is_demo'] as bool? ?? false,
      input: json['input'] as Map<String, dynamic>? ?? {},
      plan: json['plan'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  String get summary => plan['summary'] as String? ?? '';

  List<Map<String, dynamic>> get weeklyFocus =>
      (plan['weekly_focus'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  List<Map<String, dynamic>> get days =>
      (plan['days'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  List<Map<String, dynamic>> get checkpoints =>
      (plan['checkpoints'] as List?)?.cast<Map<String, dynamic>>() ?? [];
}
