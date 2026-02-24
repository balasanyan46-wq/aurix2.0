class BudgetPlanModel {
  final String id;
  final String userId;
  final String releaseId;
  final bool isDemo;
  final Map<String, dynamic> input;
  final Map<String, dynamic> budget;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BudgetPlanModel({
    required this.id,
    required this.userId,
    required this.releaseId,
    required this.isDemo,
    required this.input,
    required this.budget,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BudgetPlanModel.fromJson(Map<String, dynamic> json) {
    return BudgetPlanModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      releaseId: json['release_id'] as String,
      isDemo: json['is_demo'] as bool? ?? false,
      input: json['input'] as Map<String, dynamic>? ?? {},
      budget: json['budget'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  String get summary => budget['summary'] as String? ?? '';

  List<Map<String, dynamic>> get allocation =>
      (budget['allocation'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  List<String> get dontSpendOn =>
      (budget['dont_spend_on'] as List?)?.cast<String>() ?? [];

  List<String> get mustSpendOn =>
      (budget['must_spend_on'] as List?)?.cast<String>() ?? [];

  List<String> get nextSteps =>
      (budget['next_steps'] as List?)?.cast<String>() ?? [];
}
